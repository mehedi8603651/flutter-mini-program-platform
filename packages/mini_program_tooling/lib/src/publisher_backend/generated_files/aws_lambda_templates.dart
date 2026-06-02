part of '../../publisher_backend_starter.dart';

String _awsLambdaTemplateYaml(
  String title, {
  required String appId,
  required String storageMode,
}) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final dataTableResource = usesDynamoDb
      ? '''
  PublisherBackendDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE

'''
      : '';
  final functionEnvironment =
      '''
      Environment:
        Variables:
          PUBLISHER_BACKEND_STORAGE: $storageMode
          MINI_PROGRAM_ID: $appId
${usesDynamoDb ? '          PUBLISHER_BACKEND_TABLE_NAME: !Ref PublisherBackendDataTable\n' : ''}''';
  final functionPolicies = usesDynamoDb
      ? '''
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref PublisherBackendDataTable
'''
      : '';
  final dataTableOutput = usesDynamoDb
      ? '''
  PublisherBackendDataTableName:
    Description: DynamoDB table used by the publisher backend.
    Value: !Ref PublisherBackendDataTable
'''
      : '';
  return '''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Publisher-owned business API backend for $title.

Parameters:
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.

Globals:
  Function:
    Runtime: nodejs24.x
    Timeout: 8
    MemorySize: 256
    Architectures:
      - arm64

Resources:
  PublisherBackendHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName
      CorsConfiguration:
        AllowOrigins:
          - '*'
        AllowMethods:
          - GET
          - POST
          - OPTIONS
        AllowHeaders:
          - content-type
          - x-mini-program-access-key
          - x-mini-program-app-id
          - x-mini-program-host-app
          - x-mini-program-host-version
          - x-mini-program-id
          - x-mini-program-sdk-version
          - x-mini-program-platform
          - x-mini-program-locale

$dataTableResource  PublisherBackendFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Description: Publisher-owned mini-program business API.
$functionEnvironment$functionPolicies      Events:
        ProxyApi:
          Type: HttpApi
          Properties:
            ApiId: !Ref PublisherBackendHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  PublisherBackendBaseUrl:
    Description: Base URL for MiniProgramBackendEndpoint.baseUri.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/'
  PublisherBackendHealthUrl:
    Description: Publisher backend health URL.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/health'
  PublisherBackendFunctionName:
    Description: Publisher backend Lambda function name.
    Value: !Ref PublisherBackendFunction
  PublisherBackendStackName:
    Description: Publisher backend CloudFormation stack name.
    Value: !Ref AWS::StackName
  PublisherBackendStorageMode:
    Description: Publisher backend storage mode.
    Value: $storageMode
$dataTableOutput''';
}

String _awsLambdaReadme(String appId, String title, String storageMode) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final storageSection = usesDynamoDb
      ? '''
Storage mode: DynamoDB.

After deploying the stack, seed the starter data into DynamoDB:

```powershell
miniprogram publisher-backend aws seed --env <env-name>
miniprogram publisher-backend aws data status --env <env-name>
miniprogram publisher-backend aws data export --env <env-name> --include-redemptions
miniprogram publisher-backend aws data import --env <env-name> --input <export-file> --dry-run --include-redemptions
miniprogram publisher-backend aws data redemptions --env <env-name> --coupon-id coupon-10
miniprogram publisher-backend aws smoke --env <env-name> --include-write
```

The DynamoDB table is owned by this SAM stack. `aws destroy --yes` checks for
stack-owned DynamoDB data and requires `--confirm-data-loss` when app records or
redemptions exist. Seed retries unprocessed DynamoDB batch writes; data status
counts paginated app and redemption records. Export production data before stack
cleanup or migration.
'''
      : '''
Storage mode: bundled JSON.

The sample Lambda returns bundled JSON from `src/data/`. To create a persistent
DynamoDB starter instead, re-run scaffold with:

```powershell
miniprogram publisher-backend scaffold --template aws-lambda --storage dynamodb
```
''';
  return '''
# $title AWS Lambda publisher backend

This backend is for publisher-owned business APIs. It is not the mini-program
delivery backend. Host apps only receive the resulting `backendBaseUrl`; AWS
secrets and future database credentials stay on the publisher server.

$storageSection

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /coupons/page?limit=20&cursor=<couponId>`
- `GET /auth/session`
- `POST /coupon/redeem`
- `OPTIONS *`

Deploy from the mini-program root:

```powershell
miniprogram publisher-backend aws deploy --env <env-name>
```

Deploy waits for the health endpoint with cold-start-aware retries. The default
smoke command is read-only; add `--include-write` only when you want to verify
`POST /coupon/redeem`.

After deploy, connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url <PublisherBackendBaseUrl>
```

Do not put publisher backend secrets in mini-program JSON, host source, APK,
IPA, or web JavaScript.
''';
}

String _awsLambdaPackageJson(String appId, String storageMode) {
  final dependencies = storageMode == _publisherBackendStorageDynamoDb
      ? ''',
  "dependencies": {
    "@aws-sdk/client-dynamodb": "$_awsSdkJavaScriptV3Version",
    "@aws-sdk/lib-dynamodb": "$_awsSdkJavaScriptV3Version"
  }'''
      : '';
  return '''
{
  "name": "${appId}_aws_publisher_backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda publisher backend starter for $appId"$dependencies
}
''';
}

String _awsLambdaHandlerSource() => r'''
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));
const dataRoot = join(currentDir, 'data');
const storageMode = process.env.PUBLISHER_BACKEND_STORAGE ?? 'bundled';
const miniProgramId = process.env.MINI_PROGRAM_ID ?? 'mini_program';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers':
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  'content-type': 'application/json; charset=utf-8',
};

let testStore = null;
let cachedStore = null;

export function setPublisherBackendStoreForTesting(store) {
  testStore = store;
  cachedStore = null;
}

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? event.httpMethod ?? 'GET';
  const path = normalizePath(
    event.rawPath ?? event.path ?? '/',
    event.requestContext?.stage,
  );

  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: corsHeaders,
      body: '',
    };
  }

  const store = await resolveStore();

  if (method === 'GET' && path === '/health') {
    return json(200, {
      status: 'ok',
      service: 'mini_program_aws_publisher_backend',
      storageMode,
      generatedAtUtc: new Date().toISOString(),
    });
  }

  if (method === 'GET' && path === '/home/bootstrap') {
    return jsonFromStore(await store.homeBootstrap(), 'home/bootstrap');
  }

  if (method === 'GET' && path === '/coupons/list') {
    return jsonFromStore(await store.couponsList(), 'coupons/list');
  }

  if (method === 'GET' && path === '/coupons/page') {
    const options = pagingOptions(event);
    if (typeof store.couponsPage === 'function') {
      return json(200, await store.couponsPage(options));
    }
    const body = await store.couponsList();
    return json(200, pageItems(body?.coupons, options));
  }

  if (method === 'GET' && path === '/auth/session') {
    return jsonFromStore(await store.authSession(), 'auth/session');
  }

  if (method === 'POST' && path === '/coupon/redeem') {
    const body = parseJsonBody(event.body, event.isBase64Encoded);
    const result = await store.redeemCoupon(body);
    return json(result.statusCode, result.body);
  }

  return json(404, {
    errorCode: 'not_found',
    message: `No publisher backend route matches ${path}.`,
  });
}

async function resolveStore() {
  if (testStore) {
    return testStore;
  }
  if (cachedStore) {
    return cachedStore;
  }
  cachedStore =
    storageMode === 'dynamodb'
      ? await createDynamoDbStore()
      : new BundledJsonStore(dataRoot);
  return cachedStore;
}

function jsonFromStore(body, label) {
  if (body == null) {
    return json(404, {
      errorCode: 'backend_data_missing',
      message: `Backend data was not found: ${label}`,
    });
  }
  return json(200, body);
}

function pagingOptions(event) {
  return {
    limit: boundedLimit(queryValue(event, 'limit'), 20, 100),
    cursor: queryValue(event, 'cursor'),
  };
}

function pageItems(items, { limit, cursor }) {
  const source = Array.isArray(items) ? items : [];
  const startIndex = cursor ? cursorStartIndex(source, cursor) : 0;
  const page = source.slice(startIndex, startIndex + limit);
  const nextIndex = startIndex + page.length;
  const hasMore = nextIndex < source.length;
  return {
    items: page,
    nextCursor: hasMore ? cursorFor(page[page.length - 1], nextIndex) : null,
    hasMore,
  };
}

function queryValue(event, name) {
  const parameters = event.queryStringParameters || {};
  if (parameters[name] !== undefined && parameters[name] !== null) {
    return String(parameters[name]);
  }
  const rawQuery = event.rawQueryString || '';
  return new URLSearchParams(rawQuery).get(name) || '';
}

function boundedLimit(value, defaultLimit, maxLimit) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return defaultLimit;
  }
  return Math.min(parsed, maxLimit);
}

function cursorStartIndex(items, cursor) {
  const index = items.findIndex((item) => String(item?.id || '') === cursor);
  if (index >= 0) {
    return index + 1;
  }
  const numeric = Number.parseInt(cursor, 10);
  return Number.isFinite(numeric) && numeric > 0 ? numeric : 0;
}

function cursorFor(item, fallbackIndex) {
  const id = item?.id == null ? '' : String(item.id);
  return id || String(fallbackIndex);
}

class BundledJsonStore {
  constructor(root) {
    this.root = root;
  }

  homeBootstrap() {
    return this.dataFile('home_bootstrap.json');
  }

  couponsList() {
    return this.dataFile('coupons_list.json');
  }

  async couponsPage(options) {
    const body = await this.couponsList();
    return pageItems(body?.coupons, options);
  }

  authSession() {
    return this.dataFile('session.json');
  }

  async redeemCoupon(body) {
    return {
      statusCode: body?.couponId ? 200 : 400,
      body: body?.couponId
        ? {
            status: 'redeemed',
            couponId: body.couponId,
            message:
              'AWS sample redeem succeeded. Use --storage dynamodb for persistent redemptions.',
          }
        : {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          },
    };
  }

  async dataFile(fileName) {
    try {
      const raw = await readFile(join(this.root, fileName), 'utf8');
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  }
}

async function createDynamoDbStore() {
  const tableName = process.env.PUBLISHER_BACKEND_TABLE_NAME;
  if (!tableName) {
    throw new Error('PUBLISHER_BACKEND_TABLE_NAME is required for DynamoDB storage.');
  }
  const [{ DynamoDBClient }, dynamodbLib] = await Promise.all([
    import('@aws-sdk/client-dynamodb'),
    import('@aws-sdk/lib-dynamodb'),
  ]);
  const docClient = dynamodbLib.DynamoDBDocumentClient.from(
    new DynamoDBClient({}),
  );
  return new DynamoDbStore({
    docClient,
    tableName,
    appId: miniProgramId,
    commands: dynamodbLib,
  });
}

class DynamoDbStore {
  constructor({ docClient, tableName, appId, commands }) {
    this.docClient = docClient;
    this.tableName = tableName;
    this.appPk = `APP#${appId}`;
    this.redemptionsPk = `APP#${appId}#REDEMPTIONS`;
    this.GetCommand = commands.GetCommand;
    this.PutCommand = commands.PutCommand;
    this.QueryCommand = commands.QueryCommand;
  }

  homeBootstrap() {
    return this.payloadFor('HOME#bootstrap');
  }

  async couponsList() {
    const items = [];
    let exclusiveStartKey;
    do {
      const response = await this.docClient.send(
        new this.QueryCommand({
          TableName: this.tableName,
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
          ExpressionAttributeValues: {
            ':pk': this.appPk,
            ':prefix': 'COUPON#',
          },
          ConsistentRead: true,
          ExclusiveStartKey: exclusiveStartKey,
        }),
      );
      items.push(...(response.Items ?? []));
      exclusiveStartKey = response.LastEvaluatedKey;
    } while (exclusiveStartKey);
    const coupons = items
      .sort((left, right) => (left.sortIndex ?? 0) - (right.sortIndex ?? 0))
      .map((item) => item.payload)
      .filter((item) => item != null);
    return { coupons };
  }

  async couponsPage({ limit = 20, cursor = '' } = {}) {
    const pageLimit = boundedLimit(limit, 20, 100);
    const response = await this.docClient.send(
      new this.QueryCommand({
        TableName: this.tableName,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
        ExpressionAttributeValues: {
          ':pk': this.appPk,
          ':prefix': 'COUPON#',
        },
        ConsistentRead: true,
        Limit: pageLimit + 1,
        ExclusiveStartKey: cursor
          ? {
              pk: this.appPk,
              sk: `COUPON#${cursor}`,
            }
          : undefined,
      }),
    );
    const records = response.Items ?? [];
    const pageRecords = records.slice(0, pageLimit);
    const items = pageRecords
      .map((item) => item.payload)
      .filter((item) => item != null);
    const hasMore = records.length > pageLimit || response.LastEvaluatedKey != null;
    return {
      items,
      nextCursor: hasMore && items.length > 0 ? cursorFor(items[items.length - 1], pageRecords.length) : null,
      hasMore,
    };
  }

  authSession() {
    return this.payloadFor('SESSION#demo');
  }

  async redeemCoupon(body) {
    const couponId = body?.couponId?.toString()?.trim();
    if (!couponId) {
      return {
        statusCode: 400,
        body: {
          errorCode: 'missing_coupon_id',
          message: 'couponId is required.',
        },
      };
    }

    const coupon = await this.payloadFor(`COUPON#${couponId}`);
    if (coupon == null) {
      return {
        statusCode: 404,
        body: {
          errorCode: 'coupon_not_found',
          couponId,
          message: `Coupon was not found: ${couponId}`,
        },
      };
    }

    const userId =
      body?.userId?.toString()?.trim() ||
      body?.user?.id?.toString()?.trim() ||
      'anonymous';
    const redeemedAtUtc = new Date().toISOString();
    const redemption = {
      status: 'redeemed',
      couponId,
      userId,
      redeemedAtUtc,
    };

    try {
      await this.docClient.send(
        new this.PutCommand({
          TableName: this.tableName,
          Item: {
            pk: this.redemptionsPk,
            sk: `USER#${userId}#COUPON#${couponId}`,
            recordType: 'redemption',
            couponId,
            userId,
            payload: redemption,
            createdAtUtc: redeemedAtUtc,
          },
          ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
        }),
      );
      return {
        statusCode: 200,
        body: {
          ...redemption,
          message: 'Coupon redeemed.',
        },
      };
    } catch (error) {
      if (error?.name === 'ConditionalCheckFailedException') {
        return {
          statusCode: 200,
          body: {
            status: 'already_redeemed',
            couponId,
            userId,
            message: 'Coupon was already redeemed for this user.',
          },
        };
      }
      throw error;
    }
  }

  async payloadFor(sk) {
    const response = await this.docClient.send(
      new this.GetCommand({
        TableName: this.tableName,
        Key: {
          pk: this.appPk,
          sk,
        },
        ConsistentRead: true,
      }),
    );
    return response.Item?.payload ?? null;
  }
}

function parseJsonBody(rawBody, isBase64Encoded) {
  if (!rawBody) {
    return {};
  }
  const decoded = isBase64Encoded
    ? Buffer.from(rawBody, 'base64').toString('utf8')
    : rawBody;
  try {
    return JSON.parse(decoded);
  } catch (_) {
    return {};
  }
}

function normalizePath(rawPath, stage) {
  let value = rawPath.replace(/\/+$/g, '');
  if (stage && stage !== '$default') {
    const stagePrefix = `/${stage}`;
    if (value === stagePrefix) {
      value = '/';
    } else if (value.startsWith(`${stagePrefix}/`)) {
      value = value.substring(stagePrefix.length);
    }
  }
  return value.length === 0 ? '/' : value;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body, null, 2),
  };
}
''';
