import * as vscode from 'vscode';

import {
  buildCapabilitiesArgs,
  formatRedactedCommandLine,
  runCli,
} from '../cli';

import {
  errorMessage,
  parseJsonObject,
  recordValue,
  stringArrayValue,
  stringValue,
} from './jsonValues';
import {
  configuredCliPath,
} from './workspace';

export interface PublisherBackendAwsCliCapability {
  readonly checked: boolean;
  readonly supportsFirebaseHostingPublish?: boolean;
  readonly supportsWriteSmoke: boolean;
  readonly supportsAwsPagedRoutes?: boolean;
  readonly supportsDataManagement: boolean;
  readonly supportsFirebaseScaffold?: boolean;
  readonly supportsFirebaseOperations?: boolean;
  readonly supportsFirebaseHostCommand?: boolean;
  readonly supportsFirebaseHandoff?: boolean;
  readonly supportsFirebaseStarterUi?: boolean;
  readonly supportsFirebasePagedRoutes?: boolean;
  readonly supportsFirebaseAccessKeys?: boolean;
  readonly supportsFirebaseAuthStatus?: boolean;
  readonly supportsFirebaseHostAuthDiagnostics?: boolean;
  readonly supportsFirebaseWriteSmoke?: boolean;
  readonly supportsFirebaseFirestoreData?: boolean;
  readonly supportsFirebaseDataManagement?: boolean;
  readonly supportsCapabilityDiscovery?: boolean;
  readonly toolingVersion?: string;
  readonly detail?: string;
}

export const publisherBackendAwsCliCapabilityCache = new Map<
  string,
  Promise<PublisherBackendAwsCliCapability>
>();

export async function detectPublisherBackendAwsCliCapabilities(
  workspacePath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  const cliPath = configuredCliPath();
  const cacheKey = `${cliPath}\n${workspacePath}`;
  const cached = publisherBackendAwsCliCapabilityCache.get(cacheKey);
  if (cached) {
    return cached;
  }
  const pending = detectPublisherBackendAwsCliCapabilitiesUncached(
    workspacePath,
    cliPath,
    output,
  );
  publisherBackendAwsCliCapabilityCache.set(cacheKey, pending);
  return pending;
}

export async function detectPublisherBackendAwsCliCapabilitiesUncached(
  workspacePath: string,
  cliPath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  const capabilitiesArgs = buildCapabilitiesArgs({ json: true });
  output?.appendLine(`> ${formatRedactedCommandLine(cliPath, capabilitiesArgs)}`);
  try {
    const capabilitiesResult = await runCli(cliPath, capabilitiesArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    if (capabilitiesResult.exitCode === 0) {
      const decoded = parseJsonObject(capabilitiesResult.stdout);
      const capability = capabilityFromCliCapabilitiesJson(decoded);
      if (
        capability.supportsFirebaseHostingPublish ||
        capability.supportsWriteSmoke ||
        capability.supportsAwsPagedRoutes ||
        capability.supportsDataManagement ||
        capability.supportsFirebaseOperations ||
        capability.supportsFirebaseHostCommand ||
        capability.supportsFirebaseHandoff ||
        capability.supportsFirebaseStarterUi ||
        capability.supportsFirebasePagedRoutes ||
        capability.supportsFirebaseAccessKeys ||
        capability.supportsFirebaseAuthStatus ||
        capability.supportsFirebaseHostAuthDiagnostics ||
        capability.supportsFirebaseWriteSmoke ||
        capability.supportsFirebaseFirestoreData ||
        capability.supportsFirebaseDataManagement
      ) {
        return capability;
      }
    }
  } catch {
    // Older CLIs do not have the capabilities command. Fall back to help probes.
  }
  return detectPublisherBackendAwsCliCapabilitiesFromHelp(
    workspacePath,
    cliPath,
    output,
  );
}

export async function detectPublisherBackendAwsCliCapabilitiesFromHelp(
  workspacePath: string,
  cliPath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  const smokeArgs = ['publisher-backend', 'aws', 'smoke', '--help'];
  const dataExportArgs = ['publisher-backend', 'aws', 'data', 'export', '--help'];
  const redemptionsArgs = [
    'publisher-backend',
    'aws',
    'data',
    'redemptions',
    '--help',
  ];
  output?.appendLine(`> ${formatRedactedCommandLine(cliPath, smokeArgs)}`);
  try {
    const smokeResult = await runCli(cliPath, smokeArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    const combined = `${smokeResult.stdout}\n${smokeResult.stderr}`;
    const supportsWriteSmoke =
      smokeResult.exitCode === 0 && combined.includes('--include-write');
    output?.appendLine(`> ${formatRedactedCommandLine(cliPath, dataExportArgs)}`);
    const dataExportResult = await runCli(cliPath, dataExportArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    output?.appendLine(`> ${formatRedactedCommandLine(cliPath, redemptionsArgs)}`);
    const redemptionsResult = await runCli(cliPath, redemptionsArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    const dataCombined = `${dataExportResult.stdout}\n${dataExportResult.stderr}\n${redemptionsResult.stdout}\n${redemptionsResult.stderr}`;
    const supportsDataManagement =
      dataExportResult.exitCode === 0 &&
      redemptionsResult.exitCode === 0 &&
      dataCombined.includes('--include-redemptions') &&
      dataCombined.includes('--coupon-id');
    const details = [
      supportsWriteSmoke
        ? undefined
        : 'Configured CLI does not list --include-write in publisher-backend aws smoke --help.',
      supportsDataManagement
        ? undefined
        : 'Configured CLI does not expose AWS DynamoDB data export/redemptions help.',
    ].filter((value): value is string => Boolean(value));
    return {
      checked: true,
      supportsWriteSmoke,
      supportsDataManagement,
      supportsCapabilityDiscovery: false,
      detail: details.join(' '),
    };
  } catch (error) {
    return {
      checked: true,
      supportsWriteSmoke: false,
      supportsDataManagement: false,
      supportsCapabilityDiscovery: false,
      detail: errorMessage(error),
    };
  }
}

export function capabilityFromCliCapabilitiesJson(
  decoded: Record<string, unknown>,
): PublisherBackendAwsCliCapability {
  const features = recordValue(decoded.features) ?? {};
  const capabilityIds = stringArrayValue(decoded.capabilityIds);
  const hasCapability = (id: string): boolean => capabilityIds.includes(id);
  const hasFeature = (key: string): boolean => features[key] === true;
  const supportsWriteSmoke =
    hasFeature('publisherBackendAwsWriteSmoke') ||
    hasCapability('publisher_backend.aws.smoke.write');
  const supportsAwsPagedRoutes =
    hasFeature('publisherBackendAwsPagedRoutes') ||
    hasCapability('publisher_backend.aws.paged_routes');
  const supportsDataManagement =
    (hasFeature('publisherBackendAwsDynamoDbDataExport') &&
      hasFeature('publisherBackendAwsDynamoDbDataImport') &&
      hasFeature('publisherBackendAwsDynamoDbDataRedemptions') &&
      hasFeature('publisherBackendAwsDestroyDataLossGuard')) ||
    (hasCapability('publisher_backend.aws.dynamodb.data.export') &&
      hasCapability('publisher_backend.aws.dynamodb.data.import') &&
      hasCapability('publisher_backend.aws.dynamodb.data.redemptions') &&
      hasCapability('publisher_backend.aws.destroy.data_loss_guard'));
  const supportsFirebaseHostingPublish =
    hasFeature('firebaseHostingPublish') ||
    hasCapability('publish.firebase_hosting');
  const supportsFirebaseScaffold =
    hasFeature('publisherBackendFirebaseFunctionsScaffold') ||
    hasCapability('publisher_backend.firebase_functions.scaffold');
  const supportsFirebaseOperations =
    (hasFeature('publisherBackendFirebaseDeploy') &&
      hasFeature('publisherBackendFirebaseStatus') &&
      hasFeature('publisherBackendFirebaseOutputs') &&
      hasFeature('publisherBackendFirebaseSmoke')) ||
    (hasCapability('publisher_backend.firebase.deploy') &&
      hasCapability('publisher_backend.firebase.status') &&
      hasCapability('publisher_backend.firebase.outputs') &&
      hasCapability('publisher_backend.firebase.smoke'));
  const supportsFirebaseWriteSmoke =
    hasFeature('publisherBackendFirebaseWriteSmoke') ||
    hasCapability('publisher_backend.firebase.smoke.write');
  const supportsFirebaseHostCommand =
    hasFeature('publisherBackendFirebaseHostCommand') ||
    hasCapability('publisher_backend.firebase.host_command');
  const supportsFirebaseHandoff =
    hasFeature('publisherBackendFirebaseHandoff') ||
    hasCapability('publisher_backend.firebase.handoff');
  const supportsFirebaseStarterUi =
    hasFeature('publisherBackendFirebaseStarterUi') ||
    hasCapability('publisher_backend.firebase.starter_ui');
  const supportsFirebasePagedRoutes =
    hasFeature('publisherBackendFirebasePagedRoutes') ||
    hasCapability('publisher_backend.firebase.paged_routes');
  const supportsFirebaseAccessKeys =
    hasFeature('publisherBackendFirebaseAccessKeys') ||
    hasCapability('publisher_backend.firebase.access_keys');
  const supportsFirebaseAuthStatus =
    hasFeature('publisherBackendFirebaseAuthStatus') ||
    hasCapability('publisher_backend.firebase.auth.status');
  const supportsFirebaseHostAuthDiagnostics =
    hasFeature('publisherBackendFirebaseHostAuthDiagnostics') ||
    hasCapability('publisher_backend.firebase.host.auth_diagnostics');
  const supportsFirebaseFirestoreData =
    (hasFeature('publisherBackendFirebaseFirestoreSeed') &&
      hasFeature('publisherBackendFirebaseFirestoreDataStatus')) ||
    (hasCapability('publisher_backend.firebase.firestore.seed') &&
      hasCapability('publisher_backend.firebase.firestore.data.status'));
  const supportsFirebaseDataManagement =
    (hasFeature('publisherBackendFirebaseFirestoreDataExport') &&
      hasFeature('publisherBackendFirebaseFirestoreDataImport') &&
      hasFeature('publisherBackendFirebaseFirestoreDataRedemptions') &&
      hasFeature('publisherBackendFirebaseDestroyDataLossGuard')) ||
    (hasCapability('publisher_backend.firebase.firestore.data.export') &&
      hasCapability('publisher_backend.firebase.firestore.data.import') &&
      hasCapability('publisher_backend.firebase.firestore.data.redemptions') &&
      hasCapability('publisher_backend.firebase.destroy.data_loss_guard'));
  const details = [
    supportsFirebaseHostingPublish
      ? undefined
      : 'Configured CLI capabilities do not include Firebase Hosting publish.',
    supportsWriteSmoke
      ? undefined
      : 'Configured CLI capabilities do not include publisher_backend.aws.smoke.write.',
    supportsDataManagement
      ? undefined
      : 'Configured CLI capabilities do not include AWS DynamoDB export/import/redemptions and guarded destroy.',
    supportsAwsPagedRoutes
      ? undefined
      : 'Configured CLI capabilities do not include AWS paged backend routes.',
    supportsFirebaseScaffold
      ? undefined
      : 'Configured CLI capabilities do not include Firebase Functions scaffold.',
    supportsFirebaseOperations
      ? undefined
      : 'Configured CLI capabilities do not include Firebase deploy/status/outputs/smoke.',
    supportsFirebaseHostCommand
      ? undefined
      : 'Configured CLI capabilities do not include Firebase host-command.',
    supportsFirebaseHandoff
      ? undefined
      : 'Configured CLI capabilities do not include Firebase handoff.',
    supportsFirebaseStarterUi
      ? undefined
      : 'Configured CLI capabilities do not include Firebase starter UI.',
    supportsFirebasePagedRoutes
      ? undefined
      : 'Configured CLI capabilities do not include Firebase paged backend routes.',
    supportsFirebaseAccessKeys
      ? undefined
      : 'Configured CLI capabilities do not include Firebase access-key management.',
    supportsFirebaseAuthStatus
      ? undefined
      : 'Configured CLI capabilities do not include Firebase auth status.',
    supportsFirebaseHostAuthDiagnostics
      ? undefined
      : 'Configured CLI capabilities do not include Firebase host auth diagnostics.',
    supportsFirebaseWriteSmoke
      ? undefined
      : 'Configured CLI capabilities do not include Firebase write smoke.',
    supportsFirebaseFirestoreData
      ? undefined
      : 'Configured CLI capabilities do not include Firebase Firestore seed/data status.',
    supportsFirebaseDataManagement
      ? undefined
      : 'Configured CLI capabilities do not include Firebase Firestore export/import/redemptions and guarded destroy.',
  ].filter((value): value is string => Boolean(value));
  return {
    checked: true,
    supportsFirebaseHostingPublish,
    supportsWriteSmoke,
    supportsAwsPagedRoutes,
    supportsDataManagement,
    supportsFirebaseScaffold,
    supportsFirebaseOperations,
    supportsFirebaseHostCommand,
    supportsFirebaseHandoff,
    supportsFirebaseStarterUi,
    supportsFirebasePagedRoutes,
    supportsFirebaseAccessKeys,
    supportsFirebaseAuthStatus,
    supportsFirebaseHostAuthDiagnostics,
    supportsFirebaseWriteSmoke,
    supportsFirebaseFirestoreData,
    supportsFirebaseDataManagement,
    supportsCapabilityDiscovery: true,
    toolingVersion: stringValue(decoded.toolingVersion),
    detail: details.join(' '),
  };
}

export async function detectPublisherBackendAwsCli027(
  workspacePath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  return detectPublisherBackendAwsCliCapabilities(workspacePath, output);
}

export async function ensurePublisherBackendAwsCli027(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (capability.supportsWriteSmoke) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.29 or newer is required for AWS DynamoDB sidebar actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.29`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendAwsCli028(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (capability.supportsDataManagement) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.29 or newer is required for AWS DynamoDB data management actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.29`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseCli032(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (capability.supportsFirebaseOperations) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.32 or newer is required for Firebase publisher backend actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.32`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseFirestoreCli032(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseFirestoreData
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.32 or newer is required for Firebase Firestore seed/status actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.32`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseDataManagementCli034(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseFirestoreData &&
    capability.supportsFirebaseDataManagement
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.34 or newer is required for Firebase Firestore export/import/redemptions and guarded destroy actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.34`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseWriteSmokeCli035(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseWriteSmoke
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.35 or newer is required for Firebase write smoke. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.35`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseHostCommandCli036(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseHostCommand
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.38 or newer is required for Firebase host integration. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.38`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseHandoffCli039(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseHandoff
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.39 or newer is required for Firebase host handoff packages. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.39`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseStarterUiCli049(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseScaffold &&
    capability.supportsFirebaseStarterUi &&
    capability.supportsFirebasePagedRoutes &&
    toolingVersionAtLeast(capability.toolingVersion, '0.3.49')
  ) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.3.49 or newer is required for Firebase paged starter UI generation. ' +
    `${versionDetail}Run \`dart pub global activate mini_program_tooling 0.3.49\`.`;
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseAccessKeysCli045(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseAccessKeys &&
    toolingVersionAtLeast(capability.toolingVersion, '0.3.45')
  ) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.3.45 or newer is required for Firebase protected handoff access keys. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.45`.';
  output.appendLine(message);
  if (versionDetail) {
    output.appendLine(versionDetail.trim());
  }
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensurePublisherBackendFirebaseAuthStatusCli044(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsFirebaseOperations &&
    capability.supportsFirebaseAuthStatus
  ) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.44 or newer is required for Firebase auth status diagnostics. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.44`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensureFirebaseHostingPublishCli042(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (firebaseHostingPublishCliAccepted(capability)) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.3.42 or newer is required for Firebase Hosting publish. ' +
    '0.3.42 adds Firebase Hosting CORS headers with reliable CLI version metadata. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.42`.';
  output.appendLine(message);
  if (versionDetail) {
    output.appendLine(versionDetail.trim());
  }
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export function firebaseHostingPublishCliAccepted(
  capability: PublisherBackendAwsCliCapability,
): boolean {
  if (!capability.supportsFirebaseHostingPublish) {
    return false;
  }
  return toolingVersionAtLeast(capability.toolingVersion, '0.3.42');
}

export function toolingVersionAtLeast(
  version: string | undefined,
  minimum: string,
): boolean {
  if (!version) {
    return false;
  }
  const currentParts = version
    .split(/[^0-9]+/)
    .filter(Boolean)
    .slice(0, 3)
    .map((part) => Number.parseInt(part, 10));
  const minimumParts = minimum
    .split('.')
    .slice(0, 3)
    .map((part) => Number.parseInt(part, 10));
  for (let index = 0; index < 3; index += 1) {
    const current = Number.isFinite(currentParts[index])
      ? currentParts[index]
      : 0;
    const required = Number.isFinite(minimumParts[index])
      ? minimumParts[index]
      : 0;
    if (current > required) {
      return true;
    }
    if (current < required) {
      return false;
    }
  }
  return true;
}
