import {
  WorkflowStatusReport,
  asBoolean,
  asNumber,
  asRecord,
  asString,
  asStringList,
} from './workflowStatus';

export interface StatusTreeRow {
  readonly label: string;
  readonly value?: string;
  readonly icon?: string;
}

export interface StatusTreeSection {
  readonly label: string;
  readonly icon: string;
  readonly rows: StatusTreeRow[];
}

export interface FirebaseHostEndpointStatus {
  readonly ready?: boolean;
  readonly miniProgramId?: string;
  readonly hostProjectRootPath?: string;
  readonly hostEndpointMapPath?: string;
  readonly deliveryApiBaseUrl?: string;
  readonly backendBaseUrl?: string;
  readonly accessMode?: string;
  readonly hostEndpointBackendMode?: string;
  readonly hostEndpointIssues?: readonly string[];
  readonly hostingManifestReachable?: boolean;
  readonly hostingCorsReady?: boolean;
  readonly hostingManifestUrl?: string;
  readonly hostingCorsAllowOrigin?: string;
  readonly hostingDeliveryIssue?: string;
  readonly hostAuthControllerReady?: boolean;
  readonly hostRuntimeSetupPath?: string;
  readonly hostAuthControllerConfigured?: boolean;
  readonly hostSecureAuthControllerConfigured?: boolean;
  readonly hostDisposeAuthControllerConfigured?: boolean;
  readonly hostAuthIssues?: readonly string[];
}

export interface FirebaseAuthStatus {
  readonly ready?: boolean;
  readonly deployEnvReady?: boolean;
  readonly environmentName?: string;
  readonly projectId?: string;
  readonly region?: string;
  readonly functionName?: string;
  readonly miniProgramId?: string;
  readonly authWebApiKeyConfigured?: boolean;
  readonly scaffoldExists?: boolean;
  readonly authServiceFileExists?: boolean;
  readonly routerAuthRoutesReady?: boolean;
  readonly routerAllowsAuthorizationHeader?: boolean;
  readonly packageJsonHasFirebaseAdmin?: boolean;
  readonly envAuthKeyConfigured?: boolean;
  readonly envUsesReservedAuthKey?: boolean;
  readonly envFilePath?: string;
  readonly hostAuthChecked?: boolean;
  readonly hostProjectRootPath?: string;
  readonly hostAuthControllerReady?: boolean;
  readonly hostRuntimeSetupPath?: string;
  readonly hostAuthControllerConfigured?: boolean;
  readonly hostSecureAuthControllerConfigured?: boolean;
  readonly hostDisposeAuthControllerConfigured?: boolean;
  readonly issues?: readonly string[];
  readonly warnings?: readonly string[];
  readonly hostAuthIssues?: readonly string[];
}

export interface FirebaseAccessKeyStatus {
  readonly environmentName?: string;
  readonly projectId?: string;
  readonly region?: string;
  readonly functionName?: string;
  readonly miniProgramId?: string;
  readonly backendBaseUrl?: string;
  readonly activeKeyCount?: number;
  readonly keyCount?: number;
  readonly activeKeyIds?: readonly string[];
  readonly inactiveKeyIds?: readonly string[];
}

export function buildStatusTreeSections(
  report: WorkflowStatusReport | undefined,
  options: {
    readonly firebaseHostEndpoint?: FirebaseHostEndpointStatus;
    readonly firebaseAuthStatus?: FirebaseAuthStatus;
    readonly firebaseAccessKeys?: FirebaseAccessKeyStatus;
  } = {},
): StatusTreeSection[] {
  const firebaseHostEndpoint = options.firebaseHostEndpoint;
  const firebaseAuthStatus = options.firebaseAuthStatus;
  const firebaseAccessKeys = options.firebaseAccessKeys;
  if (!report) {
    if (firebaseHostEndpoint || firebaseAuthStatus || firebaseAccessKeys) {
      return compactSections([
        firebaseHostEndpoint ? firebaseHostEndpointSection(firebaseHostEndpoint) : undefined,
        firebaseAuthStatus ? firebaseAuthStatusSection(firebaseAuthStatus) : undefined,
        firebaseAccessKeys ? firebaseAccessKeySection(firebaseAccessKeys) : undefined,
      ]);
    }
    return [
      {
        label: 'Workspace',
        icon: 'folder',
        rows: [{ label: 'No status yet', value: 'Run Refresh Status' }],
      },
    ];
  }

  const workspace = asRecord(report.workspace);
  const miniProgram = asRecord(report.miniProgram);
  const hostApp = asRecord(report.hostApp);
  const environment = asRecord(report.environment);
  const backend = asRecord(report.backend);
  const remote = asRecord(report.remote);
  const nextActions = asStringList(report.nextActions);
  const sections: StatusTreeSection[] = [
    {
      label: 'Workspace',
      icon: iconForSeverity(asString(report.severity, 'warning')),
      rows: compactRows([
        row('Type', asString(workspace.type, 'unknown')),
        row('Ready', yesNo(asBoolean(report.ready))),
        row('Severity', asString(report.severity, 'warning')),
        row('Path', asString(workspace.path)),
      ]),
    },
  ];

  if (asBoolean(miniProgram.detected)) {
    const build = asRecord(miniProgram.build);
    const validation = asRecord(miniProgram.validation);
    const backendUsage = asRecord(miniProgram.backendUsage);
    const publisherBackendStarter = asRecord(miniProgram.publisherBackendStarter);
    const awsPublisherBackend = asRecord(publisherBackendStarter.aws);
    const firebasePublisherBackend = asRecord(publisherBackendStarter.firebase);
    const expectedPublisherRoutes = asStringList(publisherBackendStarter.expectedRoutes);
    const screenSchemaVersion = asNumber(miniProgram.screenSchemaVersion);
    const partnerPackages = Array.isArray(miniProgram.partnerPackages)
      ? miniProgram.partnerPackages.length
      : 0;
    sections.push({
      label: 'Mini-program',
      icon: 'package',
      rows: compactRows([
        row('App ID', asString(miniProgram.appId, 'unknown')),
        row('Version', asString(miniProgram.version, 'unknown')),
        row('Screen format', asString(miniProgram.screenFormat, 'stac')),
        row(
          'Schema version',
          screenSchemaVersion > 0 ? String(screenSchemaVersion) : '',
        ),
        row('Source root', asString(miniProgram.sourceRootPath)),
        row('Output root', asString(miniProgram.outputRootPath)),
        row(
          'Build',
          asBoolean(build.exists)
            ? `${asNumber(build.screenCount)} screen JSON file(s)`
            : 'missing',
        ),
        row('Entry screen', asString(build.entryScreenPath)),
        row('Entry ready', optionalYesNo(build.entryScreenExists)),
        row('Validation', asString(validation.status, 'not_run')),
        row('Partner packages', String(partnerPackages)),
        row(
          'Backend usage',
          asBoolean(backendUsage.usesPublisherBackend)
            ? asBoolean(backendUsage.usesBackendState)
              ? 'query/state'
              : 'action'
            : 'none',
        ),
        row(
          'Backend starter',
          asBoolean(publisherBackendStarter.detected)
            ? asString(publisherBackendStarter.template, 'mock')
            : 'none',
        ),
        row('Publisher routes', expectedPublisherRoutes.join(', ')),
        row(
          'Paged route',
          expectedPublisherRoutes.some((route) => route.includes('/coupons/page'))
            ? 'yes'
            : '',
        ),
        row(
          'AWS backend',
          asBoolean(awsPublisherBackend.detected)
            ? asString(awsPublisherBackend.backendBaseUrl, 'scaffolded')
            : 'none',
        ),
        row('AWS env', asString(awsPublisherBackend.environmentName)),
        row('AWS stack', asString(awsPublisherBackend.stackName)),
        row('AWS region', asString(awsPublisherBackend.region)),
        row('AWS health', asString(awsPublisherBackend.healthUrl)),
        row('AWS function', asString(awsPublisherBackend.functionName)),
        row(
          'Firebase backend',
          asBoolean(firebasePublisherBackend.detected)
            ? asString(firebasePublisherBackend.backendBaseUrl, 'scaffolded')
            : 'none',
        ),
        row('Firebase env', asString(firebasePublisherBackend.environmentName)),
        row('Firebase project', asString(firebasePublisherBackend.projectId)),
        row('Firebase region', asString(firebasePublisherBackend.region)),
        row('Firebase health', asString(firebasePublisherBackend.healthUrl)),
        row('Firebase function', asString(firebasePublisherBackend.functionName)),
        row('Firebase storage', asString(firebasePublisherBackend.storageMode)),
      ]),
    });
  }

  if (asBoolean(hostApp.detected)) {
    const endpointCount = asNumber(hostApp.endpointCount);
    const endpoints = Array.isArray(hostApp.endpoints) ? hostApp.endpoints : [];
    const endpointModes = endpoints
      .map((entry) => {
        const endpoint = asRecord(entry);
        const appId = asString(endpoint.appId);
        const mode = asString(endpoint.accessMode, asBoolean(endpoint.hasAccessKey) ? 'protected' : 'public');
        return appId ? `${appId}:${mode}` : '';
      })
      .filter(Boolean)
      .join(', ');
    const endpointBackends = endpoints
      .map((entry) => {
        const endpoint = asRecord(entry);
        const appId = asString(endpoint.appId);
        const mode = asString(
          endpoint.backendMode,
          asBoolean(endpoint.backendConfigured) ? 'remote' : 'none',
        );
        return appId ? `${appId}:${mode}` : '';
      })
      .filter(Boolean)
      .join(', ');
    sections.push({
      label: 'Host app',
      icon: 'device-mobile',
      rows: compactRows([
        row('Runtime setup', yesNo(asBoolean(hostApp.runtimeSetupExists))),
        row('Endpoint map', yesNo(asBoolean(hostApp.endpointMapExists))),
        row('Endpoint count', String(endpointCount)),
        row('Endpoint app IDs', asStringList(hostApp.endpointAppIds).join(', ')),
        row('Endpoint modes', endpointModes),
        row('Publisher backends', endpointBackends),
        row(
          'Routing',
          endpointCount > 0
            ? 'endpoint map active'
            : 'default backend fallback',
        ),
      ]),
    });
  }

  sections.push({
    label: 'Environment',
    icon: 'server',
    rows: compactRows([
      row('Configured', yesNo(asBoolean(environment.configured))),
      row('Environment', asString(environment.selectedEnvironment)),
      row('Provider', asString(environment.provider)),
      row('API base URL', asString(environment.apiBaseUrl)),
      row('Access keys required', yesNo(asBoolean(environment.requireAccessKeys))),
    ]),
  });

  sections.push({
    label:
      asBoolean(hostApp.detected) && asNumber(hostApp.endpointCount) > 0
        ? 'Backend fallback'
        : 'Backend',
    icon: 'server',
    rows: compactRows([
      row('Configured', yesNo(asBoolean(backend.configured))),
      row('Status checked', yesNo(asBoolean(backend.statusChecked))),
      row('Process alive', yesNo(asBoolean(backend.processAlive))),
      row('Healthy', yesNo(asBoolean(backend.healthy))),
    ]),
  });

  const cloudStatus = asRecord(remote.cloudStatus);
  const app = asRecord(remote.app);
  const accessKeys = asRecord(remote.accessKeys);
  const firebaseRemote = asRecord(remote.firebase);
  const firebaseStatus = asRecord(firebaseRemote.status);
  const firebaseDataStatus = asRecord(firebaseRemote.dataStatus);
  sections.push({
    label: 'Remote',
    icon: 'cloud',
    rows: compactRows([
      row('Checked', yesNo(asBoolean(remote.checked))),
      row('Provider', asString(remote.provider)),
      row('Cloud healthy', optionalYesNo(cloudStatus.healthy)),
      row('Stack status', asString(cloudStatus.stackStatus)),
      row('Latest version', asString(app.latestVersion)),
      row('Active access keys', optionalNumber(accessKeys.activeCount)),
      row('Firebase healthy', optionalYesNo(firebaseStatus.healthy)),
      row('Firestore available', optionalYesNo(firebaseDataStatus.available)),
      row('Firestore app records', optionalNumber(firebaseDataStatus.appRecordCount)),
      row('Firestore redemptions', optionalNumber(firebaseDataStatus.redemptionCount)),
      row('Errors', asStringList(remote.errors).join('; ')),
    ]),
  });

  if (firebaseHostEndpoint) {
    sections.push(firebaseHostEndpointSection(firebaseHostEndpoint));
  }
  if (firebaseAuthStatus) {
    sections.push(firebaseAuthStatusSection(firebaseAuthStatus));
  }
  if (firebaseAccessKeys) {
    sections.push(firebaseAccessKeySection(firebaseAccessKeys));
  }

  sections.push({
    label: 'Next actions',
    icon: 'list-ordered',
    rows:
      nextActions.length === 0
        ? [{ label: 'No immediate action' }]
        : nextActions.map((action, index) => ({
            label: `${index + 1}. ${action}`,
            icon: 'arrow-right',
          })),
  });

  return sections;
}

export function flattenStatusSections(sections: readonly StatusTreeSection[]): string {
  return sections
    .flatMap((section) => [
      section.label,
      ...section.rows.map((row) =>
        row.value && row.value.length > 0 ? `${row.label}: ${row.value}` : row.label,
      ),
    ])
    .join('\n');
}

function row(label: string, value: string): StatusTreeRow {
  return { label, value };
}

function compactRows(rows: readonly StatusTreeRow[]): StatusTreeRow[] {
  return rows.filter((row) => row.value !== undefined && row.value !== '');
}

function yesNo(value: boolean): string {
  return value ? 'yes' : 'no';
}

function optionalYesNo(value: unknown): string {
  return typeof value === 'boolean' ? yesNo(value) : '';
}

function optionalNumber(value: unknown): string {
  return typeof value === 'number' ? String(value) : '';
}

function firebaseHostEndpointSection(
  status: FirebaseHostEndpointStatus,
): StatusTreeSection {
  return {
    label: 'Firebase host endpoint',
    icon: status.ready ? 'pass' : 'warning',
    rows: compactRows([
      row('Ready', optionalYesNo(status.ready)),
      row('App ID', status.miniProgramId ?? ''),
      row('Host app', status.hostProjectRootPath ?? ''),
      row('Endpoint map', status.hostEndpointMapPath ?? ''),
      row('Delivery URL', status.deliveryApiBaseUrl ?? ''),
      row('Backend URL', status.backendBaseUrl ?? ''),
      row('Access mode', status.accessMode ?? ''),
      row('Backend mode', status.hostEndpointBackendMode ?? ''),
      row('Hosting manifest', optionalYesNo(status.hostingManifestReachable)),
      row('Hosting CORS', optionalYesNo(status.hostingCorsReady)),
      row('Hosting manifest URL', status.hostingManifestUrl ?? ''),
      row('CORS allow origin', status.hostingCorsAllowOrigin ?? ''),
      row('Hosting issue', status.hostingDeliveryIssue ?? ''),
      row('Host auth ready', optionalYesNo(status.hostAuthControllerReady)),
      row('Host runtime setup', status.hostRuntimeSetupPath ?? ''),
      row('Host auth configured', optionalYesNo(status.hostAuthControllerConfigured)),
      row('Host secure auth store', optionalYesNo(status.hostSecureAuthControllerConfigured)),
      row('Host disposes auth', optionalYesNo(status.hostDisposeAuthControllerConfigured)),
      row('Host auth issues', (status.hostAuthIssues ?? []).join('; ')),
      row('Issues', (status.hostEndpointIssues ?? []).join('; ')),
    ]),
  };
}

function firebaseAuthStatusSection(status: FirebaseAuthStatus): StatusTreeSection {
  return {
    label: 'Firebase auth',
    icon: status.ready === false || status.hostAuthControllerReady === false ? 'warning' : 'shield',
    rows: compactRows([
      row('Ready', optionalYesNo(status.ready)),
      row('Deploy env ready', optionalYesNo(status.deployEnvReady)),
      row('Environment', status.environmentName ?? ''),
      row('Project', status.projectId ?? ''),
      row('Region', status.region ?? ''),
      row('Function', status.functionName ?? ''),
      row('Mini-program ID', status.miniProgramId ?? ''),
      row('Auth Web API key', optionalYesNo(status.authWebApiKeyConfigured)),
      row('Scaffold', optionalYesNo(status.scaffoldExists)),
      row('Auth service file', optionalYesNo(status.authServiceFileExists)),
      row('Auth routes', optionalYesNo(status.routerAuthRoutesReady)),
      row('Authorization CORS', optionalYesNo(status.routerAllowsAuthorizationHeader)),
      row('Firebase Admin dependency', optionalYesNo(status.packageJsonHasFirebaseAdmin)),
      row('Functions .env auth key', optionalYesNo(status.envAuthKeyConfigured)),
      row('Reserved .env key present', optionalYesNo(status.envUsesReservedAuthKey)),
      row('Functions .env', status.envFilePath ?? ''),
      row('Host auth checked', optionalYesNo(status.hostAuthChecked)),
      row('Host app', status.hostProjectRootPath ?? ''),
      row('Host auth ready', optionalYesNo(status.hostAuthControllerReady)),
      row('Host runtime setup', status.hostRuntimeSetupPath ?? ''),
      row('Host auth configured', optionalYesNo(status.hostAuthControllerConfigured)),
      row('Host secure auth store', optionalYesNo(status.hostSecureAuthControllerConfigured)),
      row('Host disposes auth', optionalYesNo(status.hostDisposeAuthControllerConfigured)),
      row('Issues', (status.issues ?? []).join('; ')),
      row('Warnings', (status.warnings ?? []).join('; ')),
      row('Host auth issues', (status.hostAuthIssues ?? []).join('; ')),
    ]),
  };
}

function firebaseAccessKeySection(
  status: FirebaseAccessKeyStatus,
): StatusTreeSection {
  const activeKeyIds = (status.activeKeyIds ?? []).join(', ');
  const inactiveKeyIds = (status.inactiveKeyIds ?? []).join(', ');
  return {
    label: 'Firebase access keys',
    icon: (status.activeKeyCount ?? 0) > 0 ? 'key' : 'info',
    rows: compactRows([
      row('Environment', status.environmentName ?? ''),
      row('Project', status.projectId ?? ''),
      row('Region', status.region ?? ''),
      row('Function', status.functionName ?? ''),
      row('Mini-program ID', status.miniProgramId ?? ''),
      row('Backend URL', status.backendBaseUrl ?? ''),
      row('Active keys', optionalNumber(status.activeKeyCount)),
      row('Total keys', optionalNumber(status.keyCount)),
      row('Active key IDs', activeKeyIds),
      row('Inactive key IDs', inactiveKeyIds),
    ]),
  };
}

function compactSections(
  sections: readonly (StatusTreeSection | undefined)[],
): StatusTreeSection[] {
  return sections.filter((section): section is StatusTreeSection => Boolean(section));
}

function iconForSeverity(severity: string): string {
  switch (severity) {
    case 'ok':
      return 'pass';
    case 'error':
      return 'error';
    default:
      return 'warning';
  }
}
