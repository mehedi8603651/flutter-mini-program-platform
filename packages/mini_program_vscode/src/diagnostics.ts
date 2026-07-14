import * as fs from 'fs/promises';
import * as http from 'http';
import * as https from 'https';
import * as path from 'path';

import {
  WorkflowStatusReport,
  asBoolean,
  asNumber,
  asRecord,
  asString,
  asStringList,
} from './workflowStatus';
import {
  endpointLaunchUsageMissing,
  parseEndpointAppIds,
  parseRegistryEntries,
} from './hostIntegration';

export type DiagnosticSeverity = 'ok' | 'warning' | 'error';
export type DiagnosticScope =
  | 'workspace'
  | 'miniProgram'
  | 'hostApp';

export interface DiagnosticCheck {
  readonly id: string;
  readonly label: string;
  readonly severity: DiagnosticSeverity;
  readonly summary: string;
  readonly detail?: string;
  readonly fix?: string;
}

export interface DiagnosticSummary {
  readonly ok: number;
  readonly warning: number;
  readonly error: number;
}

export interface DiagnosticReport {
  readonly title: string;
  readonly generatedAtUtc: string;
  readonly workspacePath: string;
  readonly checks: DiagnosticCheck[];
  readonly summary: DiagnosticSummary;
}

export interface BuildDiagnosticsOptions {
  readonly workspacePath: string;
  readonly scope: DiagnosticScope;
  readonly workflowReport?: WorkflowStatusReport;
  readonly remoteWorkflowReport?: WorkflowStatusReport;
  readonly doctorReport?: Record<string, unknown>;
  readonly cliCapabilities?: {
    readonly checked: boolean;
    readonly supportsStaticPublish?: boolean;
    readonly supportsPublisherApiMock?: boolean;
    readonly supportsPublisherBackendContract?: boolean;
    readonly supportsCapabilityDiscovery?: boolean;
    readonly toolingVersion?: string;
    readonly detail?: string;
  };
}

interface ManifestInfo {
  readonly exists: boolean;
  readonly path: string;
  readonly id?: string;
  readonly version?: string;
  readonly entry?: string;
  readonly error?: string;
}

export async function buildDiagnosticsReport(
  options: BuildDiagnosticsOptions,
): Promise<DiagnosticReport> {
  const workflowReport = options.workflowReport;
  const workspace = asRecord(workflowReport?.workspace);
  const detectedType = asString(workspace.type, await detectWorkspaceType(options.workspacePath));
  const checks: DiagnosticCheck[] = [
    check(
      'workspace.type',
      'Workspace type',
      detectedType === 'unknown' ? 'warning' : 'ok',
      detectedType === 'unknown'
        ? 'Workspace is not recognized as a mini-program or host app.'
        : `Detected ${detectedType}.`,
      options.workspacePath,
      detectedType === 'unknown'
        ? 'Open a mini-program root with manifest.json or a Flutter host app root with pubspec.yaml.'
        : undefined,
    ),
  ];

  if (options.scope === 'workspace' || options.scope === 'miniProgram') {
    checks.push(
      ...(await buildMiniProgramChecks(
        options.workspacePath,
        workflowReport,
        options.scope === 'miniProgram',
      )),
    );
  }
  if (options.scope === 'workspace' || options.scope === 'hostApp') {
    checks.push(
      ...(await buildHostAppChecks(
        options.workspacePath,
        workflowReport,
        options.scope === 'hostApp',
      )),
    );
  }
  if (options.doctorReport) {
    checks.push(buildDoctorCheck(options.doctorReport));
  }
  if (options.cliCapabilities?.checked) {
    checks.push(buildCliCapabilityCheck(options.cliCapabilities));
  }

  return {
    title: titleForScope(options.scope),
    generatedAtUtc: new Date().toISOString(),
    workspacePath: options.workspacePath,
    checks,
    summary: summarizeChecks(checks),
  };
}

export function formatDiagnosticsReport(report: DiagnosticReport): string {
  const lines = [
    report.title,
    `Generated at UTC: ${report.generatedAtUtc}`,
    `Workspace: ${report.workspacePath}`,
    `Summary: ${report.summary.ok} ok, ${report.summary.warning} warning, ${report.summary.error} error`,
    '',
  ];
  for (const item of report.checks) {
    lines.push(`[${item.severity.toUpperCase()}] ${item.label}: ${item.summary}`);
    if (item.detail) {
      lines.push(`  Detail: ${item.detail}`);
    }
    if (item.fix) {
      lines.push(`  Fix: ${item.fix}`);
    }
  }
  return redactSecrets(lines.join('\n'));
}

export function redactSecrets(value: string): string {
  return value.replace(/mpk_live_[A-Za-z0-9._-]+/g, 'mpk_live_<redacted>');
}

async function buildMiniProgramChecks(
  workspacePath: string,
  workflowReport: WorkflowStatusReport | undefined,
  strictScope: boolean,
): Promise<DiagnosticCheck[]> {
  const miniProgram = asRecord(workflowReport?.miniProgram);
  const detected = asBoolean(miniProgram.detected) || (await exists(path.join(workspacePath, 'manifest.json')));
  if (!detected) {
    return [
      check(
        'mini_program.detected',
        'Mini-program workspace',
        strictScope ? 'error' : 'warning',
        'No mini-program manifest was found.',
        path.join(workspacePath, 'manifest.json'),
        'Open the mini-program root folder or run MiniProgram: Create MiniProgram.',
      ),
    ];
  }

  const manifest = await readManifest(workspacePath);
  const build = asRecord(miniProgram.build);
  const validation = asRecord(miniProgram.validation);
  const backendUsage = asRecord(miniProgram.backendUsage);
  const publisherBackendStarter = asRecord(miniProgram.publisherBackendStarter);
  const partnerPackages = Array.isArray(miniProgram.partnerPackages)
    ? miniProgram.partnerPackages.length
    : 0;
  const defaultScreensDirectory = path.join(workspacePath, 'mp', '.build', 'screens');
  const screensDirectory = asString(build.screensDirectory, defaultScreensDirectory);
  const buildExists = asBoolean(build.exists) || (await countJsonFiles(defaultScreensDirectory)) > 0;
  const entry = manifest.entry || asString(miniProgram.entry);
  const entryPath = entry
    ? path.join(screensDirectory, `${entry}.json`)
    : '';
  const entryExists = entryPath ? await exists(entryPath) : false;
  const validationStatus = asString(validation.status, 'not_run');
  const usesPublisherBackend = asBoolean(backendUsage.usesPublisherBackend);
  const usesBackendState =
    asBoolean(backendUsage.usesBackendBuilder) ||
    asBoolean(backendUsage.usesBackendQueryAction) ||
    asBoolean(backendUsage.usesBackendState);
  const backendRequestIds = asStringList(backendUsage.requestIds);
  const hasPublisherBackendStarter = asBoolean(publisherBackendStarter.detected);
  const publisherBackendTemplate = asString(publisherBackendStarter.template, 'mock');

  return [
    check(
      'mini_program.manifest',
      'Manifest',
      manifest.exists && !manifest.error ? 'ok' : 'error',
      manifest.exists && !manifest.error ? 'manifest.json was found.' : 'manifest.json is missing or invalid.',
      manifest.error || manifest.path,
      'Open the mini-program root folder or recreate the scaffold.',
    ),
    check(
      'mini_program.manifest_id',
      'Manifest appId',
      manifest.id ? 'ok' : 'error',
      manifest.id ? `App ID: ${manifest.id}` : 'Manifest is missing id.',
      undefined,
      'Add an id field to manifest.json.',
    ),
    check(
      'mini_program.manifest_version',
      'Manifest version',
      manifest.version ? 'ok' : 'error',
      manifest.version ? `Version: ${manifest.version}` : 'Manifest is missing version.',
      undefined,
      'Add a version field to manifest.json.',
    ),
    check(
      'mini_program.manifest_entry',
      'Manifest entry',
      entry ? 'ok' : 'error',
      entry ? `Entry: ${entry}` : 'Manifest is missing entry.',
      undefined,
      'Add an entry field to manifest.json.',
    ),
    check(
      'mini_program.build',
      'Build output',
      buildExists ? 'ok' : 'warning',
      buildExists ? 'Build output exists.' : 'Build output is missing.',
      screensDirectory,
      buildExists ? undefined : 'Run MiniProgram: Build.',
    ),
    check(
      'mini_program.entry_screen',
      'Entry screen JSON',
      entryExists ? 'ok' : 'warning',
      entryExists ? 'Entry screen JSON exists.' : 'Entry screen JSON is missing.',
      entryPath || 'No entry screen path could be resolved.',
      entryExists ? undefined : 'Run MiniProgram: Build and confirm manifest entry matches a screen.',
    ),
    check(
      'mini_program.validation',
      'Validation',
      validationStatus === 'ok'
        ? 'ok'
        : validationStatus === 'error'
          ? 'error'
          : 'warning',
      `Validation status: ${validationStatus}.`,
      asString(validation.reason),
      validationStatus === 'ok' ? undefined : 'Run MiniProgram: Validate.',
    ),
    check(
      'mini_program.partner_packages',
      'Partner packages',
      partnerPackages > 0 ? 'ok' : 'warning',
      `${partnerPackages} partner package file(s) found.`,
      undefined,
      partnerPackages > 0 ? undefined : 'Run MiniProgram: Create Partner Package after publishing static artifacts.',
    ),
    check(
      'mini_program.publisher_backend_usage',
      'Publisher API usage',
      usesPublisherBackend ? 'warning' : 'ok',
      usesPublisherBackend
        ? usesBackendState
          ? 'Mini-program source uses backend query/state helpers.'
          : 'Mini-program source uses Publisher API actions.'
        : 'No Publisher API action or builder usage was detected.',
      backendRequestIds.length > 0
        ? `Request IDs: ${backendRequestIds.join(', ')}`
        : undefined,
      usesPublisherBackend
        ? 'Configure an optional runtime middleServerApiUrl/Publisher API URL when importing or adding the host endpoint.'
        : undefined,
    ),
    check(
      'mini_program.publisher_backend_starter',
      'Mock Publisher API starter',
      hasPublisherBackendStarter || !usesBackendState ? 'ok' : 'warning',
      hasPublisherBackendStarter
        ? `Mock Publisher API starter found: ${publisherBackendTemplate}.`
        : usesBackendState
          ? 'Backend query/state helpers are used, but no local mock Publisher API starter was found.'
          : 'No local mock Publisher API starter was detected.',
      [
        asString(publisherBackendStarter.backendRootPath),
      ].filter(Boolean).join('\n') || undefined,
      hasPublisherBackendStarter
        ? 'Run MiniProgram: Run Mock Publisher API for local testing, or point the host endpoint at your Publisher API.'
        : usesBackendState
          ? 'Run MiniProgram: Setup Mock Publisher API for a local mock, or connect a real Publisher API as the optional runtime API.'
          : undefined,
    ),
  ];
}

async function buildHostAppChecks(
  workspacePath: string,
  workflowReport: WorkflowStatusReport | undefined,
  strictScope: boolean,
): Promise<DiagnosticCheck[]> {
  const hostApp = asRecord(workflowReport?.hostApp);
  const pubspecPath = path.join(workspacePath, 'pubspec.yaml');
  const pubspecExists = await exists(pubspecPath);
  const runtimeSetupPath = path.join(workspacePath, 'lib', 'mini_program', 'mini_program_runtime_setup.dart');
  const launcherPath = path.join(workspacePath, 'lib', 'mini_program', 'mini_program_launcher.dart');
  const endpointPath = path.join(workspacePath, 'lib', 'mini_program', 'mini_program_endpoints.dart');
  const registryPath = path.join(workspacePath, 'lib', 'mini_program', 'mini_program_registry.dart');
  const detected = asBoolean(hostApp.detected) || pubspecExists;
  if (!detected) {
    return [
      check(
        'host_app.detected',
        'Host app workspace',
        strictScope ? 'error' : 'warning',
        'No Flutter host app pubspec was found.',
        pubspecPath,
        'Open the Flutter host app root folder.',
      ),
    ];
  }

  const pubspec = pubspecExists ? await readText(pubspecPath) : '';
  const runtimeSetupExists = asBoolean(hostApp.runtimeSetupExists) || await exists(runtimeSetupPath);
  const launcherExists = asBoolean(hostApp.launcherExists) || await exists(launcherPath);
  const endpointMapExists = asBoolean(hostApp.endpointMapExists) || await exists(endpointPath);
  const endpoints = Array.isArray(hostApp.endpoints) ? hostApp.endpoints : [];
  const endpointCount = asNumber(hostApp.endpointCount, endpoints.length);
  const endpointIssues = endpoints
    .map((entry) => asRecord(entry))
    .filter((entry) => !asString(entry.apiBaseUri))
    .map((entry) => asString(entry.appId, 'unknown'));
  const endpointArtifactSummaries = endpoints
    .map((entry) => {
      const endpoint = asRecord(entry);
      const appId = asString(endpoint.appId);
      const artifactBaseUrl = asString(endpoint.apiBaseUri);
      return appId ? `${appId}:${artifactBaseUrl ? 'static' : 'missing'}` : '';
    })
    .filter(Boolean)
    .join(', ');
  const endpointAppIdsFromReport = endpoints
    .map((entry) => asString(asRecord(entry).appId))
    .filter((appId): appId is string => Boolean(appId));
  const endpointAppIds = endpointAppIdsFromReport.length > 0
    ? endpointAppIdsFromReport
    : endpointMapExists
      ? parseEndpointAppIds(await readText(endpointPath))
      : [];
  const registryExists = await exists(registryPath);
  const registryEntries = registryExists
    ? parseRegistryEntries(await readText(registryPath))
    : [];
  const registryAppIds = registryEntries.map((entry) => entry.appId);
  const endpointAppIdSet = new Set(endpointAppIds);
  const registryAppIdSet = new Set(registryAppIds);
  const endpointsMissingRegistry = endpointAppIds.filter((appId) => !registryAppIdSet.has(appId));
  const registryMissingEndpoint = registryAppIds.filter((appId) => !endpointAppIdSet.has(appId));
  const unopenedEndpointAppIds = endpointAppIds.length > 0
    ? endpointLaunchUsageMissing(await readDartSources(workspacePath), endpointAppIds)
    : [];
  const hasScope = await dartFilesContain(workspacePath, 'MiniProgramScope');
  const internetPermission = await fileContains(
    path.join(workspacePath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    'android.permission.INTERNET',
  );

  return [
    check(
      'host_app.pubspec',
      'Flutter pubspec',
      pubspecExists ? 'ok' : 'error',
      pubspecExists ? 'pubspec.yaml was found.' : 'pubspec.yaml is missing.',
      pubspecPath,
      pubspecExists ? undefined : 'Open the Flutter host app root folder.',
    ),
    check(
      'host_app.sdk_dependency',
      'mini_program_sdk dependency',
      pubspec.includes('mini_program_sdk') ? 'ok' : 'warning',
      pubspec.includes('mini_program_sdk')
        ? 'mini_program_sdk dependency is present.'
        : 'mini_program_sdk dependency was not found in pubspec.yaml.',
      undefined,
      pubspec.includes('mini_program_sdk') ? undefined : 'Run MiniProgram: Embed Init.',
    ),
    check(
      'host_app.runtime_setup',
      'Runtime setup',
      runtimeSetupExists ? 'ok' : 'warning',
      runtimeSetupExists ? 'Generated runtime setup exists.' : 'Generated runtime setup is missing.',
      runtimeSetupPath,
      runtimeSetupExists ? undefined : 'Run MiniProgram: Embed Init.',
    ),
    check(
      'host_app.launcher',
      'Launcher helper',
      launcherExists ? 'ok' : 'warning',
      launcherExists ? 'Generated launcher helper exists.' : 'Generated launcher helper is missing.',
      launcherPath,
      launcherExists ? undefined : 'Run MiniProgram: Embed Init.',
    ),
    check(
      'host_app.endpoint_map',
      'Endpoint map',
      endpointMapExists && endpointCount > 0 ? 'ok' : 'warning',
      endpointMapExists
        ? `${endpointCount} endpoint(s) configured.`
        : 'Endpoint map is missing.',
      endpointPath,
      endpointMapExists && endpointCount > 0
        ? undefined
        : 'Run MiniProgram: Import Host Endpoint or MiniProgram: Add Host Endpoint.',
    ),
    check(
      'host_app.endpoint_entries',
      'Endpoint entries',
      endpointIssues.length === 0 ? 'ok' : 'error',
      endpointIssues.length === 0
        ? 'Endpoint entries include static artifact base URLs.'
        : `Incomplete endpoint entries: ${endpointIssues.join(', ')}.`,
      endpointArtifactSummaries || undefined,
      endpointIssues.length === 0 ? undefined : 'Re-import the partner package or run MiniProgram: Add Host Endpoint.',
    ),
    check(
      'host_app.endpoint_routing',
      'Endpoint routing',
      endpointMapExists && endpointCount > 0 ? 'ok' : 'warning',
      endpointMapExists && endpointCount > 0
        ? 'Endpoint routing is active; configured appIds use their endpoint map entries.'
        : 'Endpoint routing is not active, so launches use the default backend fallback.',
      endpointMapExists && endpointCount > 0
        ? 'The default backend URL is only a fallback when no endpoint map is configured.'
        : undefined,
      endpointMapExists && endpointCount > 0
        ? undefined
        : 'Run MiniProgram: Import Host Endpoint or MiniProgram: Add Host Endpoint.',
    ),
    check(
      'host_app.endpoint_launch_usage',
      'Endpoint launch usage',
      unopenedEndpointAppIds.length === 0 ? 'ok' : 'warning',
      unopenedEndpointAppIds.length === 0
        ? 'Every configured endpoint has a likely launcher usage.'
        : `Endpoint(s) are configured but not opened from host UI: ${unopenedEndpointAppIds.join(', ')}.`,
      undefined,
      unopenedEndpointAppIds.length === 0
        ? undefined
        : 'Run MiniProgram: Copy Demo Host Button or add an openAppMiniProgram button/menu item.',
    ),
    check(
      'host_app.registry_sync',
      'MiniProgram registry sync',
      endpointsMissingRegistry.length === 0 && registryMissingEndpoint.length === 0 ? 'ok' : 'warning',
      endpointsMissingRegistry.length === 0 && registryMissingEndpoint.length === 0
        ? 'Endpoint map and MiniProgram registry appIds match.'
        : `Endpoint/registry mismatch. Missing registry: ${endpointsMissingRegistry.join(', ') || 'none'}; missing endpoint: ${registryMissingEndpoint.join(', ') || 'none'}.`,
      registryExists ? registryPath : undefined,
      endpointsMissingRegistry.length === 0 && registryMissingEndpoint.length === 0
        ? undefined
        : 'Re-add the endpoint with MiniProgram: Add Host Endpoint or re-import the partner package.',
    ),
    check(
      'host_app.runtime_api_security_model',
      'Runtime API security model',
      'ok',
      'Auth, payments, database access, provider SDKs, and secrets belong behind the optional middle-server API.',
    ),
    check(
      'host_app.scope',
      'MiniProgramScope',
      hasScope ? 'ok' : 'warning',
      hasScope ? 'MiniProgramScope is referenced in Dart code.' : 'MiniProgramScope was not found in lib/**/*.dart.',
      undefined,
      hasScope ? undefined : 'Wrap the host app with MiniProgramScope(config: buildMiniProgramConfig(...), child: MyApp()).',
    ),
    check(
      'host_app.android_internet',
      'Android internet permission',
      internetPermission ? 'ok' : 'warning',
      internetPermission
        ? 'Release Android manifest has INTERNET permission.'
        : 'Release Android manifest is missing INTERNET permission.',
      path.join(workspacePath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      internetPermission ? undefined : 'Run MiniProgram: Embed Init or add android.permission.INTERNET.',
    ),
    ...(await buildPublicEndpointChecks(endpoints)),
  ];
}

async function buildPublicEndpointChecks(
  endpoints: readonly unknown[],
): Promise<DiagnosticCheck[]> {
  const checks: DiagnosticCheck[] = [];
  for (const rawEndpoint of endpoints) {
    const endpoint = asRecord(rawEndpoint);
    const appId = asString(endpoint.appId);
    const apiBaseUri = asString(endpoint.apiBaseUri);
    if (!appId || !apiBaseUri) {
      continue;
    }

    checks.push(
      check(
        `host_app.static_artifact_endpoint.${appId}`,
        `Static artifact endpoint: ${appId}`,
        'ok',
        'Static artifact endpoint uses public static files.',
        apiBaseUri,
      ),
    );

    const manifestUrl = resolveEndpointUrl(
      apiBaseUri,
      `manifests/${appId}/latest.json`,
    );
    const manifestResponse = await getJsonObject(manifestUrl);
    checks.push(
      check(
        `host_app.public_manifest.${appId}`,
        `Public manifest URL: ${appId}`,
        manifestResponse.ok ? 'ok' : 'warning',
        manifestResponse.ok
          ? 'Public latest manifest is reachable.'
          : 'Public latest manifest could not be loaded.',
        manifestResponse.ok ? manifestUrl : `${manifestUrl} (${manifestResponse.error})`,
        manifestResponse.ok
          ? undefined
          : 'Confirm the static artifact host is deployed and the host endpoint base URL points at the static output folder.',
      ),
    );

    const version = asString(manifestResponse.json?.version);
    const entry = asString(manifestResponse.json?.entry);
    if (!manifestResponse.ok || !version || !entry) {
      checks.push(
        check(
          `host_app.public_entry_screen.${appId}`,
          `Public entry screen URL: ${appId}`,
          'warning',
          'Public entry screen could not be checked because manifest version or entry is missing.',
          manifestUrl,
          'Confirm latest.json has version and entry fields.',
        ),
      );
      continue;
    }

    const screenUrl = resolveEndpointUrl(
      apiBaseUri,
      `screens/${appId}/${version}/${entry}.json`,
    );
    const screenResponse = await getJsonObject(screenUrl);
    checks.push(
      check(
        `host_app.public_entry_screen.${appId}`,
        `Public entry screen URL: ${appId}`,
        screenResponse.ok ? 'ok' : 'warning',
        screenResponse.ok
          ? 'Public entry screen JSON is reachable.'
          : 'Public entry screen JSON could not be loaded.',
        screenResponse.ok ? screenUrl : `${screenUrl} (${screenResponse.error})`,
        screenResponse.ok
          ? undefined
          : 'Run miniprogram publish --target static again and push the generated screens folder.',
      ),
    );
  }
  return checks;
}

function buildDoctorCheck(doctorReport: Record<string, unknown>): DiagnosticCheck {
  const summary = asRecord(doctorReport.summary);
  const errors = asNumber(summary.error);
  const warnings = asNumber(summary.warning);
  const ok = asNumber(summary.ok);
  const skipped = asNumber(summary.skipped);
  return check(
    'cli.doctor',
    'CLI doctor',
    errors > 0 ? 'error' : warnings > 0 ? 'warning' : 'ok',
    `${ok} ok, ${warnings} warning, ${errors} error, ${skipped} skipped.`,
    undefined,
    errors > 0 || warnings > 0 ? 'Run miniprogram doctor --json and inspect the reported checks.' : undefined,
  );
}

function buildCliCapabilityCheck(capability: {
  readonly supportsStaticPublish?: boolean;
  readonly supportsPublisherApiMock?: boolean;
  readonly supportsPublisherBackendContract?: boolean;
  readonly supportsCapabilityDiscovery?: boolean;
  readonly toolingVersion?: string;
  readonly detail?: string;
}): DiagnosticCheck {
  const supportsPublisherApiMock = capability.supportsPublisherApiMock ?? false;
  const supportsStaticPublish = capability.supportsStaticPublish ?? false;
  const supportsPublisherBackendContract =
    capability.supportsPublisherBackendContract ?? false;
  const supportsCapabilityDiscovery = capability.supportsCapabilityDiscovery ?? false;
  const supportsExpectedCli =
    supportsPublisherApiMock &&
    supportsStaticPublish &&
    supportsPublisherBackendContract &&
    supportsCapabilityDiscovery;
  const versionSuffix = capability.toolingVersion
    ? ` Version: ${capability.toolingVersion}.`
    : '';
  return check(
    'cli.publisher_api',
    'CLI Publisher API commands',
    supportsExpectedCli ? 'ok' : 'warning',
    supportsExpectedCli
      ? `Configured CLI supports static artifact publishing, Publisher API mock, runtime contract checks, and quiet capability discovery.${versionSuffix}`
      : supportsStaticPublish &&
          supportsPublisherApiMock &&
          supportsPublisherBackendContract
        ? 'Configured CLI supports Publisher API commands but lacks quiet capability discovery.'
        : 'Configured CLI is missing static artifact publish or provider-neutral Publisher API commands.',
    capability.detail,
    supportsExpectedCli
      ? undefined
      : 'Activate the local mini_program_tooling package or update miniProgram.cliPath.',
  );
}

function check(
  id: string,
  label: string,
  severity: DiagnosticSeverity,
  summary: string,
  detail?: string,
  fix?: string,
): DiagnosticCheck {
  return { id, label, severity, summary, detail, fix };
}

function summarizeChecks(checks: readonly DiagnosticCheck[]): DiagnosticSummary {
  return {
    ok: checks.filter((item) => item.severity === 'ok').length,
    warning: checks.filter((item) => item.severity === 'warning').length,
    error: checks.filter((item) => item.severity === 'error').length,
  };
}

function titleForScope(scope: DiagnosticScope): string {
  switch (scope) {
    case 'miniProgram':
      return 'MiniProgram mini-program diagnostics';
    case 'hostApp':
      return 'MiniProgram host app diagnostics';
    default:
      return 'MiniProgram workspace diagnostics';
  }
}

async function detectWorkspaceType(workspacePath: string): Promise<string> {
  if (await exists(path.join(workspacePath, 'manifest.json'))) {
    return 'mini_program';
  }
  if (await exists(path.join(workspacePath, 'pubspec.yaml'))) {
    return 'host_app';
  }
  return 'unknown';
}

async function readManifest(workspacePath: string): Promise<ManifestInfo> {
  const manifestPath = path.join(workspacePath, 'manifest.json');
  try {
    const raw = await fs.readFile(manifestPath, 'utf8');
    const decoded = JSON.parse(raw) as Record<string, unknown>;
    return {
      exists: true,
      path: manifestPath,
      id: asString(decoded.id),
      version: asString(decoded.version),
      entry: asString(decoded.entry),
    };
  } catch (error) {
    return {
      exists: false,
      path: manifestPath,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

async function exists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readText(filePath: string): Promise<string> {
  try {
    return await fs.readFile(filePath, 'utf8');
  } catch {
    return '';
  }
}

async function fileContains(filePath: string, pattern: string): Promise<boolean> {
  return (await readText(filePath)).includes(pattern);
}

function sdkSupportsLocalMockFallback(pubspec: string): boolean {
  if (/mini_program_sdk\s*:\s*\^?0\.3\.(?:[5-9]|\d{2,})\b/.test(pubspec)) {
    return true;
  }
  if (/mini_program_sdk\s*:\s*\^?0\.(?:[4-9]|\d{2,})\./.test(pubspec)) {
    return true;
  }
  if (/mini_program_sdk\s*:\s*\n\s*(path|git)\s*:/.test(pubspec)) {
    return true;
  }
  return !/mini_program_sdk\s*:/.test(pubspec);
}

async function countJsonFiles(directoryPath: string): Promise<number> {
  try {
    const entries = await fs.readdir(directoryPath, { withFileTypes: true });
    return entries.filter((entry) => entry.isFile() && entry.name.endsWith('.json')).length;
  } catch {
    return 0;
  }
}

async function dartFilesContain(workspacePath: string, pattern: string): Promise<boolean> {
  return (await readDartSources(workspacePath)).some(({ source }) =>
    source.includes(pattern),
  );
}

async function readDartSources(
  workspacePath: string,
): Promise<Array<{ readonly path: string; readonly source: string }>> {
  const libPath = path.join(workspacePath, 'lib');
  const sources: Array<{ readonly path: string; readonly source: string }> = [];
  async function visit(directoryPath: string, depth: number): Promise<void> {
    if (depth > 8) {
      return;
    }
    let entries;
    try {
      entries = await fs.readdir(directoryPath, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const entryPath = path.join(directoryPath, entry.name);
      if (entry.isDirectory()) {
        await visit(entryPath, depth + 1);
      } else if (entry.isFile() && entry.name.endsWith('.dart')) {
        sources.push({ path: entryPath, source: await readText(entryPath) });
      }
    }
  }
  await visit(libPath, 0);
  return sources;
}

function resolveEndpointUrl(apiBaseUri: string, relativePath: string): string {
  const normalizedBase = apiBaseUri.endsWith('/') ? apiBaseUri : `${apiBaseUri}/`;
  return new URL(relativePath, normalizedBase).toString();
}

function isAbsoluteUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return Boolean(parsed.protocol && parsed.host);
  } catch {
    return false;
  }
}

async function getJsonObject(
  url: string,
  redirectCount = 0,
): Promise<{
  readonly ok: boolean;
  readonly json?: Record<string, unknown>;
  readonly headers?: http.IncomingHttpHeaders;
  readonly error?: string;
}> {
  try {
    const response = await getText(url);
    if (
      response.statusCode >= 300 &&
      response.statusCode < 400 &&
      response.location &&
      redirectCount < 3
    ) {
      return getJsonObject(new URL(response.location, url).toString(), redirectCount + 1);
    }
    if (response.statusCode !== 200) {
      return {
        ok: false,
        headers: response.headers,
        error: `HTTP ${response.statusCode}`,
      };
    }
    const decoded = JSON.parse(response.body) as unknown;
    if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) {
      return {
        ok: false,
        headers: response.headers,
        error: 'Response was not a JSON object',
      };
    }
    return {
      ok: true,
      json: decoded as Record<string, unknown>,
      headers: response.headers,
    };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

async function getText(
  url: string,
): Promise<{
  readonly statusCode: number;
  readonly body: string;
  readonly headers: http.IncomingHttpHeaders;
  readonly location?: string;
}> {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https:') ? https : http;
    const request = client.get(url, { timeout: 5000 }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk: string) => {
        body += chunk;
      });
      response.on('end', () => {
        const locationHeader = response.headers.location;
        resolve({
          statusCode: response.statusCode ?? 0,
          body,
          headers: response.headers,
          location: Array.isArray(locationHeader)
            ? locationHeader[0]
            : locationHeader,
        });
      });
    });
    request.on('timeout', () => {
      request.destroy(new Error(`Request timed out: ${url}`));
    });
    request.on('error', reject);
  });
}

