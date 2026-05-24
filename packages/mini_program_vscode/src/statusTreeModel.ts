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

export function buildStatusTreeSections(
  report: WorkflowStatusReport | undefined,
): StatusTreeSection[] {
  if (!report) {
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
    const partnerPackages = Array.isArray(miniProgram.partnerPackages)
      ? miniProgram.partnerPackages.length
      : 0;
    sections.push({
      label: 'Mini-program',
      icon: 'package',
      rows: compactRows([
        row('App ID', asString(miniProgram.appId, 'unknown')),
        row('Version', asString(miniProgram.version, 'unknown')),
        row(
          'Build',
          asBoolean(build.exists)
            ? `${asNumber(build.screenCount)} screen JSON file(s)`
            : 'missing',
        ),
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
