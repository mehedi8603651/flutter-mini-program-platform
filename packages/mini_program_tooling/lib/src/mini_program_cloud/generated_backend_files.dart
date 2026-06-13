part of '../mini_program_cloud_controller.dart';

const String _bundledAwsTemplateYaml = r'''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  Serverless mini-program artifact endpoint for AWS.
  It exposes artifact /api routes through API Gateway and Lambda while
  reading published mini-program artifacts from S3.

Parameters:
  ArtifactBucketName:
    Type: String
    Description: S3 bucket that stores artifacts/ and metadata/ from cloud publish.
  ArtifactsPrefix:
    Type: String
    Default: artifacts
    Description: S3 object prefix for immutable mini-program artifacts.
  MetadataPrefix:
    Type: String
    Default: metadata
    Description: S3 object prefix for catalog and release metadata files.
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.
  FunctionTimeoutSeconds:
    Type: Number
    Default: 15
    MinValue: 3
    MaxValue: 30
    Description: Lambda timeout in seconds.
  FunctionMemorySize:
    Type: Number
    Default: 256
    AllowedValues:
      - 128
      - 256
      - 512
      - 1024
    Description: Lambda memory size in MB.
  LogLevel:
    Type: String
    Default: INFO
    AllowedValues:
      - DEBUG
      - INFO
      - WARN
      - ERROR
    Description: Log verbosity for the delivery Lambda.
  RequireMiniProgramAccessKeys:
    Type: String
    Default: 'false'
    AllowedValues:
      - 'true'
      - 'false'
    Description: Require metadata/access_keys/<miniProgramId>.json for every protected mini-program route.

Resources:
  MiniProgramDeliveryHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName

  MiniProgramDeliveryFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Runtime: nodejs24.x
      MemorySize: !Ref FunctionMemorySize
      Timeout: !Ref FunctionTimeoutSeconds
      Architectures:
        - arm64
      Environment:
        Variables:
          ARTIFACT_BUCKET_NAME: !Ref ArtifactBucketName
          ARTIFACTS_PREFIX: !Ref ArtifactsPrefix
          METADATA_PREFIX: !Ref MetadataPrefix
          LOG_LEVEL: !Ref LogLevel
          REQUIRE_MINI_PROGRAM_ACCESS_KEYS: !Ref RequireMiniProgramAccessKeys
      Policies:
        - Statement:
            - Sid: ReadPublishedMiniProgramBucket
              Effect: Allow
              Action:
                - s3:GetObject
              Resource: !Sub arn:${AWS::Partition}:s3:::${ArtifactBucketName}/*
            - Sid: ListPublishedMiniProgramBucket
              Effect: Allow
              Action:
                - s3:ListBucket
              Resource: !Sub arn:${AWS::Partition}:s3:::${ArtifactBucketName}
      Events:
        ApiProxy:
          Type: HttpApi
          Properties:
            ApiId: !Ref MiniProgramDeliveryHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  HttpApiId:
    Description: API Gateway HTTP API id.
    Value: !Ref MiniProgramDeliveryHttpApi

  HttpApiStageUrl:
    Description: Root invoke URL for the deployed API stage.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/

  BackendApiBaseUrl:
    Description: Base URL to use as MINI_PROGRAM_BACKEND_BASE_URL in Flutter hosts.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/api/

  HealthUrl:
    Description: Health endpoint for the deployed API.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/health

  ArtifactBucketName:
    Description: S3 bucket used by the API.
    Value: !Ref ArtifactBucketName
''';

const String _bundledAwsPackageJson = '''
{
  "name": "mini-program-cloud-api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda mini-program artifact endpoint backed by S3-published artifacts.",
  "dependencies": {
    "@aws-sdk/client-s3": "^3.922.0"
  }
}
''';

const String _bundledAwsHandlerSource = r'''
import { GetObjectCommand, HeadObjectCommand, ListObjectsV2Command, S3Client } from '@aws-sdk/client-s3';
import { createHash, timingSafeEqual } from 'node:crypto';

const backendJsonContentType = 'application/json; charset=utf-8';
const accessKeyHeaderName = 'x-mini-program-access-key';
const logLevel = (process.env.LOG_LEVEL || 'INFO').trim().toUpperCase();
const artifactBucketName = requiredEnv('ARTIFACT_BUCKET_NAME');
const artifactsPrefix = normalizePrefix(process.env.ARTIFACTS_PREFIX || 'artifacts');
const metadataPrefix = normalizePrefix(process.env.METADATA_PREFIX || 'metadata');
const requireMiniProgramAccessKeys = parseBoolean(process.env.REQUIRE_MINI_PROGRAM_ACCESS_KEYS || 'false');

const s3 = new S3Client({});

export const handler = async (event) => {
  const method = resolveMethod(event);
  const path = resolvePath(event);
  const pathSegments = splitPath(path);
  const query = event?.queryStringParameters ?? {};
  const traceId = resolveTraceId(event);

  logInfo('Received artifact endpoint request.', { traceId, method, path, query });

  try {
    if (method === 'OPTIONS') {
      return jsonResponse({ statusCode: 204, body: '', traceId });
    }

    if (method === 'GET' && matches(pathSegments, ['health'])) {
      return jsonResponse({
        statusCode: 200,
        bodyObject: withTraceId({
          responseType: 'health',
          statusCode: 200,
          status: 'ok',
          service: 'mini_program_cloud_api',
        }, traceId),
        traceId,
      });
    }

    if (method === 'GET' && pathSegments.length === 3 && pathSegments[0] === 'api' && pathSegments[1] === 'discovery' && isCatalogSegment(pathSegments[2])) {
      return await handleDiscovery({ traceId, query });
    }

    if (method === 'GET' && pathSegments.length === 4 && pathSegments[0] === 'api' && pathSegments[1] === 'manifests' && isLatestSegment(pathSegments[3])) {
      return await handleLatestManifest({ traceId, miniProgramId: pathSegments[2], query, event });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'debug' && pathSegments[2] === 'manifests' && isDecisionSegment(pathSegments[4])) {
      return await handleDebugDecision({ traceId, miniProgramId: pathSegments[3], query, event });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'manifests' && pathSegments[3] === 'versions') {
      const version = stripJsonSuffix(pathSegments[4]);
      if (version == null) {
        return badRequest('Manifest version path is invalid.', traceId);
      }
      return await handleVersionedManifest({ traceId, miniProgramId: pathSegments[2], version, event });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'screens') {
      const screenId = stripJsonSuffix(pathSegments[4]);
      if (screenId == null) {
        return badRequest('Screen path is invalid.', traceId);
      }
      return await handleScreen({ traceId, miniProgramId: pathSegments[2], version: pathSegments[3], screenId, event });
    }

    if (method === 'POST' && pathSegments.length >= 3 && pathSegments[0] === 'api' && pathSegments[1] === 'secure') {
      return notImplemented('Secure API routes are not implemented in the AWS artifact endpoint. Use a separate Publisher API for business logic.', traceId);
    }

    if (method !== 'GET') {
      return errorResponse({
        statusCode: 405,
        responseType: 'backend_route_error',
        errorCode: 'method_not_allowed',
        message: 'Only GET requests and documented secure POST routes are supported.',
        traceId,
      });
    }

    return errorResponse({
      statusCode: 404,
      responseType: 'backend_route_error',
      errorCode: 'not_found',
      message: `No backend route matches "${path}".`,
      traceId,
    });
  } catch (error) {
    if (error instanceof DeliveryApiError) {
      return errorResponse({
        statusCode: error.statusCode,
        responseType: error.responseType,
        errorCode: error.errorCode,
        message: error.message,
        details: error.details,
        traceId,
      });
    }

    console.error('[mini_program_cloud_api][ERROR] Unhandled request failure.', {
      traceId,
      method,
      path,
      error: `${error}`,
      stack: error?.stack,
    });
    return errorResponse({
      statusCode: 500,
      responseType: 'backend_route_error',
      errorCode: 'internal_error',
      message: 'The cloud mini-program backend failed unexpectedly.',
      details: { reason: `${error}` },
      traceId,
    });
  }
};

async function handleDiscovery({ traceId, query }) {
  validateDeliveryContext(query, traceId);
  const catalogKeys = await listCatalogKeys();
  const entries = [];

  for (const catalogKey of catalogKeys) {
    const miniProgramId = catalogKeyToMiniProgramId(catalogKey);
    if (!miniProgramId) {
      continue;
    }
    try {
      const decision = await resolveManifestDecision({ miniProgramId, query });
      const manifest = await readJsonObject(decision.manifestKey);
      entries.push(buildCatalogEntry({ manifest, decision }));
    } catch (error) {
      if (shouldSkipCatalogEntry(error)) {
        console.warn('[mini_program_cloud_api][WARN] Skipped catalog entry.', {
          traceId,
          catalogKey,
          miniProgramId,
          error: `${error}`,
        });
        continue;
      }
      console.warn('[mini_program_cloud_api][WARN] Skipped catalog entry.', {
        traceId,
        catalogKey,
        miniProgramId,
        error: `${error}`,
      });
      throw error;
    }
  }

  entries.sort((left, right) => left.title.localeCompare(right.title));

  return jsonResponse({
    statusCode: 200,
    bodyObject: withTraceId({
      responseType: 'mini_program_catalog',
      statusCode: 200,
      entryCount: entries.length,
      entries,
    }, traceId),
    traceId,
    extraHeaders: {
      'x-mini-program-catalog-count': String(entries.length),
    },
  });
}

async function handleLatestManifest({ traceId, miniProgramId, query, event }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateDeliveryContext(query, traceId);
  await requireMiniProgramAccess({ miniProgramId, event, traceId });

  const decision = await resolveManifestDecision({ miniProgramId, query });
  const manifest = await readJsonObject(decision.manifestKey);
  const responseBody = {
    ...manifest,
    deliveryMetadata: {
      responseType: 'manifest_delivery_metadata',
      statusCode: 200,
      selectionMode: decision.selectionMode,
      decisionReason: decision.decisionReason,
      resolvedVersion: decision.version,
      ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
      traceId,
    },
  };

  const extraHeaders = {
    'x-mini-program-id': miniProgramId,
    'x-mini-program-version': decision.version,
    'x-mini-program-selection-mode': decision.selectionMode,
    'x-mini-program-decision-reason': decision.decisionReason,
    ...(decision.matchedRuleId ? { 'x-mini-program-matched-rule-id': decision.matchedRuleId } : {}),
  };

  return jsonResponse({
    statusCode: 200,
    bodyObject: responseBody,
    traceId,
    extraHeaders,
  });
}

async function handleDebugDecision({ traceId, miniProgramId, query, event }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateDeliveryContext(query, traceId);
  await requireMiniProgramAccess({ miniProgramId, event, traceId });

  const decision = await resolveManifestDecision({ miniProgramId, query });
  const body = withTraceId({
    responseType: 'manifest_decision_inspection',
    statusCode: 200,
    miniProgramId,
    outcome: 'resolved',
    simulatedStatusCode: 200,
    deliveryContext: sanitizeDeliveryContext(query),
    rollout: {
      type: 'catalog_metadata',
      latestVersion: decision.version,
    },
    decision: {
      selectionMode: decision.selectionMode,
      decisionReason: decision.decisionReason,
      resolvedVersion: decision.version,
      ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
    },
    manifestSummary: {
      manifestKey: decision.manifestKey,
      releaseKey: decision.releaseKey,
    },
  }, traceId);

  return jsonResponse({
    statusCode: 200,
    bodyObject: body,
    traceId,
    extraHeaders: {
      'x-debug-route': 'manifest_decision_inspect',
      'x-debug-outcome': 'resolved',
    },
  });
}

async function handleVersionedManifest({ traceId, miniProgramId, version, event }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateSafeSegment(version, 'version', traceId);
  await requireMiniProgramAccess({ miniProgramId, event, traceId });
  const key = objectJoin(artifactsPrefix, miniProgramId, version, 'manifest.json');
  return jsonFromS3Object({
    traceId,
    key,
    notFoundMessage: `Manifest version "${version}" for mini-program "${miniProgramId}" was not found.`,
    extraHeaders: { 'x-mini-program-id': miniProgramId },
  });
}

async function handleScreen({ traceId, miniProgramId, version, screenId, event }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateSafeSegment(version, 'version', traceId);
  validateSafeSegment(screenId, 'screenId', traceId);
  await requireMiniProgramAccess({ miniProgramId, event, traceId });
  const key = objectJoin(artifactsPrefix, miniProgramId, version, 'screens', `${screenId}.json`);
  return jsonFromS3Object({
    traceId,
    key,
    notFoundMessage: `Screen "${screenId}" for mini-program "${miniProgramId}" version "${version}" was not found.`,
    extraHeaders: { 'x-mini-program-id': miniProgramId },
  });
}

async function requireMiniProgramAccess({ miniProgramId, event, traceId }) {
  const accessPolicy = await readMiniProgramAccessPolicy(miniProgramId);
  if (accessPolicy == null) {
    if (!requireMiniProgramAccessKeys) {
      return;
    }
    throw new DeliveryApiError({
      statusCode: 403,
      responseType: 'access_key_error',
      errorCode: 'access_key_not_configured',
      message: `MiniProgram access keys are required, but no access key policy exists for "${miniProgramId}".`,
      details: { miniProgramId, traceId },
    });
  }

  const requestAccessKey = nullIfBlank(resolveHeader(event, accessKeyHeaderName));
  if (!requestAccessKey) {
    throw new DeliveryApiError({
      statusCode: 401,
      responseType: 'access_key_error',
      errorCode: 'access_key_missing',
      message: 'MiniProgram access key is required for this mini-program.',
      details: { miniProgramId, traceId },
    });
  }

  if (!accessPolicyAllowsKey(accessPolicy, requestAccessKey)) {
    throw new DeliveryApiError({
      statusCode: 403,
      responseType: 'access_key_error',
      errorCode: 'access_key_invalid',
      message: 'MiniProgram access key is not authorized for this mini-program.',
      details: { miniProgramId, traceId },
    });
  }
}

async function readMiniProgramAccessPolicy(miniProgramId) {
  const key = objectJoin(metadataPrefix, 'access_keys', `${miniProgramId}.json`);
  try {
    return await readJsonObject(key);
  } catch (error) {
    if (error instanceof DeliveryApiError && error.errorCode === 'artifact_not_found') {
      return null;
    }
    throw error;
  }
}

function accessPolicyAllowsKey(policy, requestAccessKey) {
  const candidates = [
    ...(Array.isArray(policy.keys) ? policy.keys : []),
    ...(Array.isArray(policy.accessKeys) ? policy.accessKeys : []),
  ];
  if (candidates.length === 0) {
    return false;
  }

  const requestAccessKeySha256 = sha256Hex(requestAccessKey);
  return candidates.some((candidate) => accessKeyCandidateMatches(candidate, requestAccessKey, requestAccessKeySha256));
}

function accessKeyCandidateMatches(candidate, requestAccessKey, requestAccessKeySha256) {
  if (typeof candidate === 'string') {
    return safeStringEquals(candidate, requestAccessKey);
  }
  if (!candidate || typeof candidate !== 'object') {
    return false;
  }
  if (candidate.enabled === false || candidate.revoked === true) {
    return false;
  }

  const plainKey = nullIfBlank(candidate.key) || nullIfBlank(candidate.value) || nullIfBlank(candidate.accessKey);
  if (plainKey && safeStringEquals(plainKey, requestAccessKey)) {
    return true;
  }

  const sha256 = nullIfBlank(candidate.sha256) || nullIfBlank(candidate.sha256Hash) || nullIfBlank(candidate.hash);
  return sha256 ? safeStringEquals(sha256.toLowerCase(), requestAccessKeySha256) : false;
}

async function jsonFromS3Object({ traceId, key, notFoundMessage, extraHeaders = {} }) {
  let rawJson;
  try {
    rawJson = await readRawJsonObject(key);
  } catch (error) {
    if (error instanceof DeliveryApiError && error.errorCode === 'artifact_not_found') {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage,
      });
    }
    throw error;
  }

  return jsonResponse({
    statusCode: 200,
    bodyObject: parseJsonValue(rawJson, key),
    traceId,
    extraHeaders,
  });
}

async function listCatalogKeys() {
  const keys = [];
  let continuationToken;
  do {
    const response = await s3.send(new ListObjectsV2Command({
      Bucket: artifactBucketName,
      Prefix: objectJoin(metadataPrefix, 'catalog') + '/',
      ContinuationToken: continuationToken,
    }));

    for (const object of response.Contents ?? []) {
      const key = object.Key;
      if (!key || !key.endsWith('.json')) {
        continue;
      }
      keys.push(key);
    }
    continuationToken = response.IsTruncated ? response.NextContinuationToken : undefined;
  } while (continuationToken);

  keys.sort();
  return keys;
}

async function resolveReleaseMetadataFromCatalog(catalog) {
  const releaseKey = normalizeKey(catalog.releaseKey);
  if (!releaseKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Catalog metadata is missing releaseKey.',
    });
  }
  const release = await readJsonObject(releaseKey);
  if (!release?.artifacts?.manifestKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Release metadata is missing artifacts.manifestKey.',
    });
  }
  return release;
}

async function resolveManifestDecision({ miniProgramId, query }) {
  const pinnedVersion = nullIfBlank(query.pinnedVersion);
  if (pinnedVersion) {
    validateSafeSegment(pinnedVersion, 'pinnedVersion');
    const manifestKey = objectJoin(artifactsPrefix, miniProgramId, pinnedVersion, 'manifest.json');
    await assertObjectExists(manifestKey, `Pinned version "${pinnedVersion}" for mini-program "${miniProgramId}" was not found.`);
    return {
      selectionMode: 'pinned_version',
      decisionReason: 'requested_pinned_version',
      version: pinnedVersion,
      releaseKey: objectJoin(metadataPrefix, 'releases', miniProgramId, `${pinnedVersion}.json`),
      manifestKey,
      matchedRuleId: null,
    };
  }

  const catalogKey = objectJoin(metadataPrefix, 'catalog', `${miniProgramId}.json`);
  const catalog = await readJsonObject(catalogKey, {
    notFoundMessage: `Catalog metadata for mini-program "${miniProgramId}" was not found.`,
  });
  const release = await resolveReleaseMetadataFromCatalog(catalog);
  const manifestKey = normalizeKey(release?.artifacts?.manifestKey);
  if (!manifestKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Release metadata is missing artifacts.manifestKey.',
    });
  }
  const resolvedVersion = nullIfBlank(catalog.latestVersion) || nullIfBlank(release.version);
  if (!resolvedVersion) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Catalog or release metadata is missing a usable version.',
      details: {
        catalogKey,
        releaseKey: String(catalog.releaseKey),
      },
    });
  }

  return {
    selectionMode: 'catalog_latest',
    decisionReason: 'catalog_metadata_latest',
    version: resolvedVersion,
    releaseKey: String(catalog.releaseKey),
    manifestKey,
    matchedRuleId: null,
  };
}

function buildCatalogEntry({ manifest, decision }) {
  const miniProgramId = String(manifest.id || '');
  const requiredCapabilities = Array.isArray(manifest.requiredCapabilities)
    ? manifest.requiredCapabilities.map((value) => String(value))
    : [];
  const title = humanizeMiniProgramId(miniProgramId);

  return {
    id: miniProgramId,
    title,
    description: `${title} is a backend-discovered portable mini-program delivered through the shared SDK.`,
    entry: String(manifest.entry || ''),
    resolvedVersion: decision.version,
    requiredCapabilities,
    selectionMode: decision.selectionMode,
    decisionReason: decision.decisionReason,
    ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
  };
}

async function readJsonObject(key, { notFoundMessage } = {}) {
  const rawJson = await readRawJsonObject(key, { notFoundMessage });
  try {
    const decoded = JSON.parse(rawJson);
    if (decoded == null || typeof decoded !== 'object' || Array.isArray(decoded)) {
      throw new Error('JSON object required.');
    }
    return decoded;
  } catch (error) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Stored backend JSON is malformed.',
      details: { key, reason: `${error}` },
    });
  }
}

async function readRawJsonObject(key, { notFoundMessage } = {}) {
  try {
    const response = await s3.send(new GetObjectCommand({
      Bucket: artifactBucketName,
      Key: key,
    }));
    return await streamToString(response.Body);
  } catch (error) {
    if (isMissingObjectError(error)) {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage || `Artifact "${key}" was not found.`,
      });
    }
    throw error;
  }
}

async function assertObjectExists(key, notFoundMessage) {
  try {
    await s3.send(new HeadObjectCommand({
      Bucket: artifactBucketName,
      Key: key,
    }));
  } catch (error) {
    if (isMissingObjectError(error)) {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage,
      });
    }
    throw error;
  }
}

function resolveMethod(event) {
  return String(event?.requestContext?.http?.method || event?.httpMethod || 'GET').toUpperCase();
}

function resolvePath(event) {
  const rawPath = String(event?.rawPath || event?.requestContext?.http?.path || event?.path || '/');
  const stage = nullIfBlank(event?.requestContext?.stage);
  if (stage && stage !== '$default' && rawPath.startsWith(`/${stage}/`)) {
    return rawPath.slice(stage.length + 1);
  }
  return rawPath;
}

function splitPath(path) {
  return path.split('/').map((segment) => segment.trim()).filter((segment) => segment.length > 0).map((segment) => decodeURIComponent(segment));
}

function matches(actual, expected) {
  if (actual.length !== expected.length) {
    return false;
  }
  return actual.every((value, index) => value === expected[index]);
}

function isLatestSegment(value) {
  return value === 'latest' || value === 'latest.json';
}

function isCatalogSegment(value) {
  return value === 'mini-programs' || value === 'mini-programs.json';
}

function isDecisionSegment(value) {
  return value === 'decision' || value === 'decision.json';
}

function stripJsonSuffix(value) {
  const normalized = value.trim();
  if (!normalized) {
    return null;
  }
  if (!normalized.endsWith('.json')) {
    return normalized;
  }
  const stripped = normalized.slice(0, -5);
  return stripped || null;
}

function validateSafeSegment(value, label = 'segment', traceId) {
  if (!/^[A-Za-z0-9._-]+$/.test(value || '') || value === '.' || value === '..') {
    throw new DeliveryApiError({
      statusCode: 400,
      responseType: 'request_error',
      errorCode: 'invalid_request',
      message: `Path segment "${label}" is invalid.`,
      details: traceId ? { traceId } : undefined,
    });
  }
}

function resolveTraceId(event) {
  const requestedTraceId = nullIfBlank(event?.headers?.['x-request-id'] || event?.headers?.['X-Request-Id']);
  if (requestedTraceId && /^[A-Za-z0-9._-]{1,80}$/.test(requestedTraceId)) {
    return requestedTraceId;
  }
  return `aws_lb_${Date.now().toString(16)}`;
}

function resolveHeader(event, name) {
  const targetName = name.toLowerCase();
  for (const [headerName, headerValue] of Object.entries(event?.headers ?? {})) {
    if (headerName.toLowerCase() === targetName) {
      return headerValue;
    }
  }
  return null;
}

function parseBoolean(value) {
  return ['1', 'true', 'yes', 'y', 'on'].includes(String(value || '').trim().toLowerCase());
}

function sha256Hex(value) {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

function safeStringEquals(left, right) {
  const leftBuffer = Buffer.from(String(left), 'utf8');
  const rightBuffer = Buffer.from(String(right), 'utf8');
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return timingSafeEqual(leftBuffer, rightBuffer);
}

function withTraceId(body, traceId) {
  const responseBody = { ...body, traceId };
  const details = responseBody.details;
  if (details && typeof details === 'object' && !Array.isArray(details)) {
    responseBody.details = { ...details, traceId };
  }
  return responseBody;
}

function jsonResponse({ statusCode, bodyObject, body, traceId, extraHeaders = {} }) {
  const headers = {
    'content-type': backendJsonContentType,
    'x-backend-trace-id': traceId,
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'Content-Type, Authorization, X-Mini-Program-Access-Key, X-Host-App, X-Host-Version, X-Host-User-Id, X-Host-Tenant-Id, X-Request-Id',
    'access-control-expose-headers': 'x-backend-trace-id, x-mini-program-id, x-mini-program-version, x-mini-program-selection-mode, x-mini-program-decision-reason, x-mini-program-matched-rule-id, x-mini-program-catalog-count, x-debug-route, x-debug-outcome',
    'access-control-max-age': '600',
    ...extraHeaders,
  };
  return {
    statusCode,
    headers,
    body: body ?? JSON.stringify(bodyObject),
  };
}

function errorResponse({ statusCode, responseType, errorCode, message, details, traceId }) {
  return jsonResponse({
    statusCode,
    traceId,
    bodyObject: withTraceId({
      responseType,
      statusCode,
      errorCode,
      message,
      ...(details ? { details } : {}),
      error: {
        code: errorCode,
        message,
        ...(details ? { details } : {}),
      },
    }, traceId),
  });
}

function badRequest(message, traceId) {
  return errorResponse({
    statusCode: 400,
    responseType: 'request_error',
    errorCode: 'invalid_request',
    message,
    traceId,
  });
}

function notImplemented(message, traceId) {
  return errorResponse({
    statusCode: 501,
    responseType: 'backend_route_error',
    errorCode: 'not_implemented',
    message,
    traceId,
  });
}

function objectJoin(...parts) {
  return parts.filter((value) => value != null && String(value).trim().length > 0).map((value) => String(value).replaceAll('\\', '/').replace(/^\/+|\/+$/g, '')).filter((value) => value.length > 0).join('/');
}

function catalogKeyToMiniProgramId(catalogKey) {
  const expectedPrefix = `${objectJoin(metadataPrefix, 'catalog')}/`;
  if (!catalogKey.startsWith(expectedPrefix) || !catalogKey.endsWith('.json')) {
    return null;
  }
  const relativePath = catalogKey.slice(expectedPrefix.length, -5);
  return relativePath && !relativePath.includes('/') ? relativePath : null;
}

function normalizePrefix(value) {
  const trimmed = String(value || '').trim().replaceAll('\\', '/').replace(/^\/+|\/+$/g, '');
  if (!trimmed) {
    throw new Error('S3 prefixes must not be blank.');
  }
  return trimmed;
}

function normalizeKey(value) {
  const trimmed = nullIfBlank(value);
  return trimmed ? objectJoin(trimmed) : null;
}

function nullIfBlank(value) {
  if (value == null) {
    return null;
  }
  const trimmed = String(value).trim();
  return trimmed.length === 0 ? null : trimmed;
}

function requiredEnv(name) {
  const value = nullIfBlank(process.env[name]);
  if (!value) {
    throw new Error(`Missing required environment variable ${name}.`);
  }
  return value;
}

function humanizeMiniProgramId(miniProgramId) {
  return miniProgramId.split(/[_-]+/).filter((segment) => segment.length > 0).map((segment) => segment[0].toUpperCase() + segment.slice(1).toLowerCase()).join(' ');
}

function sanitizeDeliveryContext(query) {
  const rawCapabilities = nullIfBlank(query.capabilities);
  return {
    hostApp: nullIfBlank(query.hostApp),
    sdkVersion: nullIfBlank(query.sdkVersion),
    hostVersion: nullIfBlank(query.hostVersion),
    platform: nullIfBlank(query.platform),
    locale: nullIfBlank(query.locale),
    tenantId: nullIfBlank(query.tenantId),
    pinnedVersion: nullIfBlank(query.pinnedVersion),
    capabilities: rawCapabilities ? rawCapabilities.split(',').map((value) => value.trim()).filter((value) => value.length > 0).sort() : [],
  };
}

function validateDeliveryContext(query, traceId) {
  const context = sanitizeDeliveryContext(query);
  const scalarSegments = [
    ['hostApp', context.hostApp],
    ['sdkVersion', context.sdkVersion],
    ['hostVersion', context.hostVersion],
    ['platform', context.platform],
    ['locale', context.locale],
    ['tenantId', context.tenantId],
    ['pinnedVersion', context.pinnedVersion],
  ];

  for (const [label, value] of scalarSegments) {
    if (value) {
      validateSafeSegment(value, label, traceId);
    }
  }
  for (const capability of context.capabilities) {
    validateSafeSegment(capability, 'capabilities', traceId);
  }
}

function shouldSkipCatalogEntry(error) {
  return error instanceof DeliveryApiError && error.statusCode === 404;
}

function isMissingObjectError(error) {
  return error?.name === 'NoSuchKey' || error?.name === 'NotFound' || error?.$metadata?.httpStatusCode === 404;
}

function parseJsonValue(rawJson, key) {
  try {
    return JSON.parse(rawJson);
  } catch (error) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Stored backend JSON is malformed.',
      details: { key, reason: `${error}` },
    });
  }
}

async function streamToString(stream) {
  if (stream == null) {
    return '';
  }
  if (typeof stream.transformToString === 'function') {
    return stream.transformToString();
  }
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

function logInfo(message, context) {
  const levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
  if (levels.indexOf(logLevel) <= levels.indexOf('INFO')) {
    console.log('[mini_program_cloud_api][INFO]', message, context);
  }
}

class DeliveryApiError extends Error {
  constructor({ statusCode, responseType, errorCode, message, details }) {
    super(message);
    this.statusCode = statusCode;
    this.responseType = responseType;
    this.errorCode = errorCode;
    this.details = details;
  }
}
''';
