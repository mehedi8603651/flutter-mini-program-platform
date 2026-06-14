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
        row('Screen format', asString(miniProgram.screenFormat, 'mp')),
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
          'Publisher API usage',
          asBoolean(backendUsage.usesPublisherBackend)
            ? asBoolean(backendUsage.usesBackendState)
              ? 'query/state'
              : 'action'
            : 'none',
        ),
        row(
          'Publisher API mock',
          asBoolean(publisherBackendStarter.detected)
            ? asString(publisherBackendStarter.template, 'mock')
            : 'none',
        ),
        row('Publisher routes', expectedPublisherRoutes.join(', ')),
      ]),
    });
  }

  if (asBoolean(hostApp.detected)) {
    const endpointCount = asNumber(hostApp.endpointCount);
    const endpoints = Array.isArray(hostApp.endpoints) ? hostApp.endpoints : [];
    const artifactEndpoints = endpoints
      .map((entry) => {
        const endpoint = asRecord(entry);
        const appId = asString(endpoint.appId);
        const apiBaseUri = asString(endpoint.apiBaseUri);
        return appId ? `${appId}:${apiBaseUri ? 'static' : 'missing'}` : '';
      })
      .filter(Boolean)
      .join(', ');
    const runtimeApis = endpoints
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
        row('Static artifacts', artifactEndpoints),
        row('Runtime Publisher APIs', runtimeApis),
        row(
          'Routing',
          endpointCount > 0
            ? 'endpoint map active'
            : 'default static artifact fallback',
        ),
      ]),
    });
  }

  sections.push({
    label: 'Local environment',
    icon: 'server',
    rows: compactRows([
      row('Configured', yesNo(asBoolean(environment.configured))),
      row('Environment', asString(environment.selectedEnvironment)),
      row('Artifact base URL', asString(environment.apiBaseUrl)),
    ]),
  });

  sections.push({
    label:
      asBoolean(hostApp.detected) && asNumber(hostApp.endpointCount) > 0
        ? 'Artifact host fallback'
        : 'Artifact host',
    icon: 'server',
    rows: compactRows([
      row('Configured', yesNo(asBoolean(backend.configured))),
      row('Status checked', yesNo(asBoolean(backend.statusChecked))),
      row('Process alive', yesNo(asBoolean(backend.processAlive))),
      row('Healthy', yesNo(asBoolean(backend.healthy))),
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
