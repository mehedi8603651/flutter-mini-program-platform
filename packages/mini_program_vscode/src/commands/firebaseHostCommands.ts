import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildHostEndpointAddArgs,
  buildPublisherBackendFirebaseAccessKeyCreateArgs,
  buildPublisherBackendFirebaseAccessKeyListArgs,
  buildPublisherBackendFirebaseAccessKeyRevokeArgs,
  buildPublisherBackendFirebaseAccessKeyRotateArgs,
  buildPublisherBackendFirebaseAuthStatusArgs,
  buildPublisherBackendFirebaseHandoffArgs,
  buildPublisherBackendFirebaseHostCommandArgs,
  formatCommandLine,
  formatRedactedCommandLine,
} from '../cli';
import {
  titleFromAppId as hostTitleFromAppId,
} from '../hostIntegration';
import { MiniProgramStatusTreeProvider } from '../statusTree';
import {
  FirebaseAccessKeyStatus,
} from '../statusTreeModel';

import {
  appendFirebaseHostingDeliveryDiagnostics,
  chooseEndpointAccessMode,
  chooseFirebaseHandoffOutputPath,
  chooseHostProjectRootForFirebase,
  configuredCliPath,
  ensurePublisherBackendFirebaseAccessKeysCli045,
  ensurePublisherBackendFirebaseAuthStatusCli044,
  ensurePublisherBackendFirebaseHandoffCli039,
  ensurePublisherBackendFirebaseHostCommandCli036,
  firebaseAuthStatusFromCli,
  firebaseHostEndpointStatusFromHostCommand,
  numberValue,
  parseJsonObject,
  promptKeyId,
  promptOptionalFirebaseAccessKeyExpiry,
  promptPublisherBackendFirebaseEnvName,
  readMiniProgramManifestInfo,
  recordValue,
  requireMiniProgramRoot,
  runCliCapture,
  runCliCommand,
  runFirebaseHostCommandJson,
  stringArrayValue,
  stringValue,
  validateAbsoluteUrl,
  withFirebaseHostingDeliveryDiagnostics,
} from '../extensionSupport';

export async function publisherBackendFirebaseHostCommand(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseHostCommandCli036(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const hostProjectRoot = await chooseHostProjectRootForFirebase();
  if (!hostProjectRoot) {
    return;
  }
  const manifest = await readMiniProgramManifestInfo(workspacePath);
  const appId = manifest?.id ?? path.basename(workspacePath);
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title for the host registry',
    value: manifest?.title ?? hostTitleFromAppId(appId),
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://cdn.jsdelivr.net/gh/owner/miniprogram-public@main/coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
  }
  let accessKey: string | undefined;
  if (accessMode === 'protected') {
    const resolvedAccessKey = await resolveFirebaseProtectedAccessKey(
      workspacePath,
      envName,
      output,
      statusProvider,
    );
    if (!resolvedAccessKey) {
      return;
    }
    accessKey = resolvedAccessKey.accessKey;
  }

  const hostCommandArgs = buildPublisherBackendFirebaseHostCommandArgs({
    envName,
    miniProgramRoot: workspacePath,
    apiBaseUrl: apiBaseUrl.trim(),
    title: title.trim(),
    accessKey,
    public: accessMode === 'public',
    hostProjectRoot,
    json: true,
  });
  const hostCommandResult = await runFirebaseHostCommandJson(
    'Publisher Backend Firebase Host Command',
    hostCommandArgs,
    workspacePath,
    output,
  );
  if (!hostCommandResult) {
    return;
  }
  const hostEndpointStatus = await withFirebaseHostingDeliveryDiagnostics(
    firebaseHostEndpointStatusFromHostCommand(hostCommandResult),
  );
  statusProvider.setFirebaseHostEndpointStatus(hostEndpointStatus);

  const hostEndpointArgs = buildHostEndpointAddArgs({
    appId: stringValue(hostCommandResult.miniProgramId) ?? appId,
    title: stringValue(hostCommandResult.title) ?? title.trim(),
    apiBaseUrl: stringValue(hostCommandResult.deliveryApiBaseUrl) ?? apiBaseUrl.trim(),
    backendBaseUrl: stringValue(hostCommandResult.backendBaseUrl),
    accessKey,
    public: accessMode === 'public',
    projectRoot: hostProjectRoot,
  });
  const redactedEndpointCommand = formatRedactedCommandLine(
    configuredCliPath(),
    hostEndpointArgs,
  );
  output.appendLine('');
  output.appendLine('Generated Firebase host endpoint command:');
  output.appendLine(redactedEndpointCommand);
  output.appendLine(
    `Host endpoint ready: ${hostCommandResult.hostEndpointReady === true ? 'yes' : 'no'}`,
  );
  if (typeof hostCommandResult.hostAuthControllerReady === 'boolean') {
    output.appendLine(
      `Host auth controller ready: ${hostCommandResult.hostAuthControllerReady === true ? 'yes' : 'no'}`,
    );
  }
  appendFirebaseHostingDeliveryDiagnostics(output, hostEndpointStatus);
  const issues = stringArrayValue(hostCommandResult.hostEndpointIssues);
  if (issues.length > 0) {
    output.appendLine(`Host endpoint issues: ${issues.join('; ')}`);
  }
  const authIssues = stringArrayValue(hostCommandResult.hostAuthIssues);
  if (authIssues.length > 0) {
    output.appendLine(`Host auth issues: ${authIssues.join('; ')}`);
  }

  const action = await vscode.window.showQuickPick(
    [
      {
        label: 'Run generated command',
        description: 'Update the selected host app endpoint map now.',
        value: 'run' as const,
      },
      {
        label: 'Copy command',
        description: 'Copy the exact host endpoint command to the clipboard.',
        value: 'copy' as const,
      },
      {
        label: 'Preview only',
        description: 'Leave files unchanged.',
        value: 'preview' as const,
      },
    ],
    {
      title: 'Firebase host endpoint wiring',
      ignoreFocusOut: true,
    },
  );
  if (!action) {
    return;
  }
  if (action.value === 'copy') {
    await vscode.env.clipboard.writeText(formatCommandLine(configuredCliPath(), hostEndpointArgs));
    vscode.window.showInformationMessage('Firebase host endpoint command copied.');
    return;
  }
  if (action.value === 'preview') {
    return;
  }

  const ok = await runCliCommand(
    'Wire Firebase Publisher Backend Into Host App',
    hostEndpointArgs,
    workspacePath,
    output,
  );
  if (!ok) {
    return;
  }

  const verificationResult = await runFirebaseHostCommandJson(
    'Verify Firebase Host Endpoint',
    hostCommandArgs,
    workspacePath,
    output,
  );
  if (!verificationResult) {
    return;
  }
  const verificationStatus = await withFirebaseHostingDeliveryDiagnostics(
    firebaseHostEndpointStatusFromHostCommand(verificationResult),
  );
  statusProvider.setFirebaseHostEndpointStatus(verificationStatus);
  if (verificationResult.hostEndpointReady === true) {
    vscode.window.showInformationMessage('Firebase host endpoint is ready.');
  } else {
    vscode.window.showWarningMessage(
      'Firebase host endpoint was updated, but verification still reports issues. Check the MiniProgram sidebar.',
    );
  }
}

export async function publisherBackendFirebaseHandoff(
  output: vscode.OutputChannel,
  refreshStatus: () => Promise<void>,
  defaults: {
    readonly envName?: string;
    readonly deliveryUrl?: string;
    readonly public?: boolean;
  } = {},
  statusProvider?: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseHandoffCli039(workspacePath, output))) {
    return;
  }
  const envName =
    defaults.envName?.trim() ||
    (await promptPublisherBackendFirebaseEnvName(workspacePath));
  if (!envName) {
    return;
  }
  const manifest = await readMiniProgramManifestInfo(workspacePath);
  const appId = manifest?.id ?? path.basename(workspacePath);
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title for the host package',
    value: manifest?.title ?? hostTitleFromAppId(appId),
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const deliveryUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://cdn.jsdelivr.net/gh/owner/miniprogram-public@main/coupon_demo',
    value: defaults.deliveryUrl,
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!deliveryUrl) {
    return;
  }
  const accessMode = defaults.public ? 'public' : await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
  }
  let accessKey: string | undefined;
  let accessKeyId: string | undefined;
  if (accessMode === 'protected') {
    const resolvedAccessKey = await resolveFirebaseProtectedAccessKey(
      workspacePath,
      envName,
      output,
      statusProvider,
    );
    if (!resolvedAccessKey) {
      return;
    }
    accessKey = resolvedAccessKey.accessKey;
    accessKeyId = resolvedAccessKey.keyId;
  }
  const outputPath = await chooseFirebaseHandoffOutputPath(
    workspacePath,
    appId,
    envName,
    accessKeyId,
  );
  if (!outputPath) {
    return;
  }

  const handoffArgs = buildPublisherBackendFirebaseHandoffArgs({
    envName,
    miniProgramRoot: workspacePath,
    deliveryUrl: deliveryUrl.trim(),
    title: title.trim(),
    accessKey,
    public: accessMode === 'public',
    outputPath,
    json: true,
  });
  const result = await runCliCapture(
    'Publisher Backend Firebase Handoff',
    handoffArgs,
    workspacePath,
    output,
  );
  if (!result) {
    return;
  }
  const decoded = parseJsonObject(result.stdout);
  const packagePath = stringValue(decoded.packagePath) ?? outputPath;
  const hostImportCommand = stringValue(decoded.hostImportCommandText);
  output.appendLine('');
  output.appendLine('Firebase host handoff package created.');
  output.appendLine(`Package file: ${packagePath}`);
  if (hostImportCommand) {
    output.appendLine('Host developer next step:');
    output.appendLine(hostImportCommand);
  } else {
    output.appendLine('Host developer next step:');
    output.appendLine(`miniprogram host endpoint import "${packagePath}"`);
  }
  output.appendLine(
    'Host apps import this package; Firebase credentials stay with the publisher.',
  );
  await refreshStatus();
  vscode.window.showInformationMessage('Firebase host handoff package created.');
}

export async function publisherBackendFirebaseAccessKeyCreate(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseAccessKeysCli045(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const keyId = await promptKeyId('Firebase access key id', 'host-a');
  if (!keyId) {
    return;
  }
  const expiresAtUtc = await promptOptionalFirebaseAccessKeyExpiry();
  if (expiresAtUtc === undefined) {
    return;
  }
  const decoded = await createFirebaseAccessKey(
    workspacePath,
    envName,
    keyId,
    expiresAtUtc,
    output,
  );
  if (!decoded) {
    return;
  }
  const accessKey = stringValue(decoded.accessKey);
  if (accessKey) {
    await vscode.env.clipboard.writeText(accessKey);
  }
  await refreshFirebaseAccessKeyStatus(workspacePath, envName, output, statusProvider);
  vscode.window.showInformationMessage(
    accessKey
      ? 'Firebase access key created and copied to clipboard. Store it now; it cannot be listed again.'
      : 'Firebase access key created.',
  );
}

export async function publisherBackendFirebaseAccessKeyList(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseAccessKeysCli045(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await refreshFirebaseAccessKeyStatus(workspacePath, envName, output, statusProvider, {
    showSuccessNotification: true,
  });
}

export async function publisherBackendFirebaseAccessKeyRevoke(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseAccessKeysCli045(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const keyId = await promptKeyId('Firebase access key id to revoke', 'host-a');
  if (!keyId) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Revoke Firebase access key "${keyId}"? Protected host packages using this key will stop reaching protected publisher backend routes.`,
    { modal: true },
    'Revoke',
  );
  if (confirmed !== 'Revoke') {
    return;
  }
  const result = await runCliCapture(
    'Publisher Backend Firebase Access Key Revoke',
    buildPublisherBackendFirebaseAccessKeyRevokeArgs({
      envName,
      miniProgramRoot: workspacePath,
      keyId,
      json: true,
    }),
    workspacePath,
    output,
  );
  if (!result) {
    return;
  }
  await refreshFirebaseAccessKeyStatus(workspacePath, envName, output, statusProvider);
  vscode.window.showInformationMessage('Firebase access key revoked.');
}

export async function publisherBackendFirebaseAccessKeyRotate(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseAccessKeysCli045(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const keyId = await promptKeyId('Firebase access key id to rotate', 'host-a');
  if (!keyId) {
    return;
  }
  const newKeyId = await vscode.window.showInputBox({
    prompt: 'Optional replacement Firebase access key id',
    placeHolder: `${keyId}-next`,
    ignoreFocusOut: true,
  });
  if (newKeyId === undefined) {
    return;
  }
  const expiresAtUtc = await promptOptionalFirebaseAccessKeyExpiry();
  if (expiresAtUtc === undefined) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Rotate Firebase access key "${keyId}"? The old key will be revoked and a new key will be shown once.`,
    { modal: true },
    'Rotate',
  );
  if (confirmed !== 'Rotate') {
    return;
  }
  const result = await runCliCapture(
    'Publisher Backend Firebase Access Key Rotate',
    buildPublisherBackendFirebaseAccessKeyRotateArgs({
      envName,
      miniProgramRoot: workspacePath,
      keyId,
      newKeyId: newKeyId.trim() || undefined,
      expiresAtUtc,
      json: true,
    }),
    workspacePath,
    output,
  );
  if (!result) {
    return;
  }
  const decoded = parseJsonObject(result.stdout);
  const accessKey = stringValue(decoded.accessKey);
  if (accessKey) {
    await vscode.env.clipboard.writeText(accessKey);
  }
  await refreshFirebaseAccessKeyStatus(workspacePath, envName, output, statusProvider);
  vscode.window.showInformationMessage(
    accessKey
      ? 'Firebase access key rotated and copied to clipboard. Store it now; it cannot be listed again.'
      : 'Firebase access key rotated.',
  );
}

export async function resolveFirebaseProtectedAccessKey(
  workspacePath: string,
  envName: string,
  output: vscode.OutputChannel,
  statusProvider?: MiniProgramStatusTreeProvider,
): Promise<{ readonly accessKey: string; readonly keyId?: string } | undefined> {
  if (!(await ensurePublisherBackendFirebaseAccessKeysCli045(workspacePath, output))) {
    return undefined;
  }
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Create new Firebase access key',
        description: 'Recommended for a new host/partner handoff',
        value: 'create' as const,
      },
      {
        label: 'Paste existing Firebase access key',
        description: 'Use a key created earlier for this mini-program',
        value: 'paste' as const,
      },
    ],
    { title: 'Protected Firebase handoff access key', ignoreFocusOut: true },
  );
  if (!choice) {
    return undefined;
  }
  if (choice.value === 'paste') {
    const value = await vscode.window.showInputBox({
      prompt: 'Firebase MiniProgram access key for protected handoff',
      password: true,
      placeHolder: 'mpk_live_...',
      ignoreFocusOut: true,
      validateInput: (input) =>
        input.trim() ? undefined : 'Access key is required.',
    });
    const accessKey = value?.trim();
    return accessKey ? { accessKey } : undefined;
  }
  const keyId = await promptKeyId('Firebase access key id for this host/partner', 'host-a');
  if (!keyId) {
    return undefined;
  }
  const expiresAtUtc = await promptOptionalFirebaseAccessKeyExpiry();
  if (expiresAtUtc === undefined) {
    return undefined;
  }
  const decoded = await createFirebaseAccessKey(
    workspacePath,
    envName,
    keyId,
    expiresAtUtc,
    output,
  );
  if (!decoded) {
    return undefined;
  }
  const accessKey = stringValue(decoded.accessKey);
  if (!accessKey) {
    vscode.window.showErrorMessage(
      'Firebase access key was created, but the CLI did not return the one-time key.',
    );
    return undefined;
  }
  await vscode.env.clipboard.writeText(accessKey);
  if (statusProvider) {
    await refreshFirebaseAccessKeyStatus(workspacePath, envName, output, statusProvider);
  }
  vscode.window.showInformationMessage(
    'Firebase access key created and copied to clipboard. It will also be embedded in the protected handoff package.',
  );
  return { accessKey, keyId };
}

export async function createFirebaseAccessKey(
  workspacePath: string,
  envName: string,
  keyId: string,
  expiresAtUtc: string | undefined,
  output: vscode.OutputChannel,
): Promise<Record<string, unknown> | undefined> {
  const result = await runCliCapture(
    'Publisher Backend Firebase Access Key Create',
    buildPublisherBackendFirebaseAccessKeyCreateArgs({
      envName,
      miniProgramRoot: workspacePath,
      keyId,
      expiresAtUtc,
      json: true,
    }),
    workspacePath,
    output,
  );
  return result ? parseJsonObject(result.stdout) : undefined;
}

export async function refreshFirebaseAccessKeyStatus(
  workspacePath: string,
  envName: string,
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
  options: { readonly showSuccessNotification?: boolean } = {},
): Promise<void> {
  const result = await runCliCapture(
    'Publisher Backend Firebase Access Key List',
    buildPublisherBackendFirebaseAccessKeyListArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
  if (!result) {
    return;
  }
  const decoded = parseJsonObject(result.stdout);
  statusProvider.setFirebaseAccessKeyStatus(firebaseAccessKeyStatusFromCli(decoded));
  if (options.showSuccessNotification) {
    vscode.window.showInformationMessage('Firebase access keys refreshed.');
  }
}

export function firebaseAccessKeyStatusFromCli(
  decoded: Record<string, unknown>,
): FirebaseAccessKeyStatus {
  const keyEntries = Array.isArray(decoded.keys) ? decoded.keys : [];
  const activeKeyIds: string[] = [];
  const inactiveKeyIds: string[] = [];
  for (const entry of keyEntries) {
    const key = recordValue(entry);
    if (!key) {
      continue;
    }
    const keyId = stringValue(key.keyId);
    if (!keyId) {
      continue;
    }
    const currentlyActive =
      typeof key.currentlyActive === 'boolean'
        ? key.currentlyActive
        : key.active === true;
    if (currentlyActive) {
      activeKeyIds.push(keyId);
    } else {
      inactiveKeyIds.push(keyId);
    }
  }
  return {
    environmentName: stringValue(decoded.environmentName),
    projectId: stringValue(decoded.projectId),
    region: stringValue(decoded.region),
    functionName: stringValue(decoded.functionName),
    miniProgramId: stringValue(decoded.miniProgramId),
    backendBaseUrl: stringValue(decoded.backendBaseUrl),
    activeKeyCount: numberValue(decoded.activeKeyCount),
    keyCount: numberValue(decoded.keyCount),
    activeKeyIds,
    inactiveKeyIds,
  };
}

export async function publisherBackendFirebaseAuthStatus(
  output: vscode.OutputChannel,
  statusProvider: MiniProgramStatusTreeProvider,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseAuthStatusCli044(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const hostMode = await vscode.window.showQuickPick(
    [
      {
        label: 'Check backend and host auth',
        description: 'Inspect a Flutter host app for SDK auth controller setup.',
        value: 'host' as const,
      },
      {
        label: 'Check backend only',
        description: 'Validate Firebase auth backend readiness only.',
        value: 'backend' as const,
      },
    ],
    {
      title: 'Firebase auth status',
      ignoreFocusOut: true,
    },
  );
  if (!hostMode) {
    return;
  }
  const hostProjectRoot =
    hostMode.value === 'host'
      ? await chooseHostProjectRootForFirebase()
      : undefined;
  if (hostMode.value === 'host' && !hostProjectRoot) {
    return;
  }
  const args = buildPublisherBackendFirebaseAuthStatusArgs({
    envName,
    miniProgramRoot: workspacePath,
    hostProjectRoot,
    json: true,
  });
  const result = await runCliCapture(
    'Publisher Backend Firebase Auth Status',
    args,
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
  if (!result) {
    return;
  }
  const decoded = parseJsonObject(result.stdout);
  const status = firebaseAuthStatusFromCli(decoded);
  statusProvider.setFirebaseAuthStatus(status);
  output.appendLine('');
  output.appendLine(`Firebase auth ready: ${status.ready === true ? 'yes' : 'no'}`);
  output.appendLine(`Deploy env ready: ${status.deployEnvReady === true ? 'yes' : 'no'}`);
  if (status.hostAuthChecked) {
    output.appendLine(
      `Host auth controller ready: ${status.hostAuthControllerReady === true ? 'yes' : 'no'}`,
    );
  }
  if ((status.issues ?? []).length > 0) {
    output.appendLine(`Firebase auth issues: ${(status.issues ?? []).join('; ')}`);
  }
  if ((status.hostAuthIssues ?? []).length > 0) {
    output.appendLine(`Host auth issues: ${(status.hostAuthIssues ?? []).join('; ')}`);
  }
  if ((status.warnings ?? []).length > 0) {
    output.appendLine(`Firebase auth warnings: ${(status.warnings ?? []).join('; ')}`);
  }
  if (status.ready === true && (!status.hostAuthChecked || status.hostAuthControllerReady !== false)) {
    vscode.window.showInformationMessage('Firebase auth status is ready.');
  } else {
    vscode.window.showWarningMessage(
      'Firebase auth status found issues. Check the MiniProgram sidebar.',
    );
  }
}
