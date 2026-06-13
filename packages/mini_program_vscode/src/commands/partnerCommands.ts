import * as fs from 'fs';
import * as vscode from 'vscode';

import {
  buildAccessKeyCreateArgs,
  buildAccessKeyListArgs,
  buildAccessKeyRevokeArgs,
  buildAccessKeyRotateArgs,
  buildHostEndpointAddArgs,
  buildPartnerPackageArgs,
  buildPublisherBackendUrlsArgs,
  formatCommandLine,
} from '../cli';
import { titleFromAppId as hostTitleFromAppId } from '../hostIntegration';

import {
  chooseEndpointAccessMode,
  choosePartnerPackageFile,
  choosePartnerPackageOutputPath,
  configuredCliPath,
  errorMessage,
  promptAppId,
  promptKeyId,
  promptOptionalEnvName,
  promptOptionalPublisherBackendBaseUrl,
  requireMiniProgramRoot,
  requireWorkspacePath,
  runCliCapture,
  runCliCommand,
  titleFromAppId,
  validateAbsoluteUrl,
  validateAppId,
  validatePartnerPackageJson,
  validatePort,
} from '../extensionSupport';

export async function copyPublisherBackendUrls(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const port = await vscode.window.showInputBox({
    prompt: 'Mock Publisher API local port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const result = await runCliCapture(
    'Mock Publisher API URLs',
    buildPublisherBackendUrlsArgs({ port: port.trim() }),
    workspacePath,
    output,
    { allowNonZeroExit: false },
  );
  if (!result) {
    return;
  }
  const text = result.stdout.trim();
  await vscode.env.clipboard.writeText(text);
  output.show(true);
  output.appendLine('');
  output.appendLine(text);
  vscode.window.showInformationMessage('Mock Publisher API URLs copied.');
}

export async function copyMockBackendHostCommand(): Promise<void> {
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_app',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId.trim()),
    placeHolder: 'Coupon App',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program static artifact base URL',
    placeHolder: 'https://cdn.example.com/public_mini_program/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const port = await vscode.window.showInputBox({
    prompt: 'Publisher mock backend port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const args = buildHostEndpointAddArgs({
    appId: appId.trim(),
    title: title.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
    public: true,
    backendLocalMock: true,
    backendLocalMockPort: port.trim(),
    projectRoot: '.',
  }).filter((arg, index, all) => {
    return !(arg === '--project-root' || all[index - 1] === '--project-root');
  });
  const command = formatCommandLine(configuredCliPath(), args);
  await vscode.env.clipboard.writeText(command);
  vscode.window.showInformationMessage('Mock backend host command copied.');
}

export async function createAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id', 'host-a');
  if (!keyId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Create Access Key',
    buildAccessKeyCreateArgs({ appId, keyId, envName }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
    vscode.window.showInformationMessage(
      'Access key created. Copy the generated key from the MiniProgram output channel.',
    );
  }
}

export async function listAccessKeys(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'List Access Keys',
    buildAccessKeyListArgs({ appId, envName, json: true }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

export async function revokeAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id to revoke', 'host-a');
  if (!keyId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Revoke access key "${keyId}" for "${appId}"?`,
    { modal: true },
    'Revoke',
  );
  if (confirmed !== 'Revoke') {
    return;
  }

  const ok = await runCliCommand(
    'Revoke Access Key',
    buildAccessKeyRevokeArgs({ appId, keyId, envName }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

export async function rotateAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id to rotate', 'host-a');
  if (!keyId) {
    return;
  }
  const newKeyId = await vscode.window.showInputBox({
    prompt: 'Optional new access key id',
    placeHolder: `${keyId}-next`,
    ignoreFocusOut: true,
  });
  if (newKeyId === undefined) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Rotate access key "${keyId}" for "${appId}"? The old key will be revoked.`,
    { modal: true },
    'Rotate',
  );
  if (confirmed !== 'Rotate') {
    return;
  }

  const ok = await runCliCommand(
    'Rotate Access Key',
    buildAccessKeyRotateArgs({
      appId,
      keyId,
      newKeyId: newKeyId.trim() || undefined,
      envName,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
    vscode.window.showInformationMessage(
      'Access key rotated. Copy the new generated key from the MiniProgram output channel.',
    );
  }
}

export async function createPartnerPackage(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title for host developers',
    value: titleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
  }
  let accessKey: string | undefined;
  if (accessMode === 'protected') {
    const value = await vscode.window.showInputBox({
      prompt: 'MiniProgram access key for this host/partner',
      password: true,
      placeHolder: 'mpk_live_...',
      ignoreFocusOut: true,
      validateInput: (input) =>
        input.trim() ? undefined : 'Access key is required.',
    });
    if (!value) {
      return;
    }
    accessKey = value.trim();
  }
  const deliverySource = await vscode.window.showQuickPick(
    [
      {
        label: 'Configured environment',
        description: 'Use active or selected env to resolve API base URL',
        value: 'env',
      },
      {
        label: 'Direct API base URL',
        description: 'Paste the backend API URL manually',
        value: 'api',
      },
    ],
    { title: 'Partner package delivery source', ignoreFocusOut: true },
  );
  if (!deliverySource) {
    return;
  }

  let envName: string | undefined;
  let apiBaseUrl: string | undefined;
  if (deliverySource.value === 'env') {
    const value = await promptOptionalEnvName();
    if (value === undefined) {
      return;
    }
    envName = value;
  } else {
    const value = await vscode.window.showInputBox({
      prompt: 'Mini-program static artifact base URL',
      placeHolder: 'https://example.com/prod/api',
      ignoreFocusOut: true,
      validateInput: validateAbsoluteUrl,
    });
    if (!value) {
      return;
    }
    apiBaseUrl = value.trim();
  }

  const backendBaseUrl = await promptOptionalPublisherBackendBaseUrl();

  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return;
  }

  const ok = await runCliCommand(
    'Create Partner Package',
    buildPartnerPackageArgs({
      appId,
      title: title.trim() || undefined,
      accessKey,
      public: accessMode === 'public',
      envName,
      apiBaseUrl,
      backendBaseUrl,
      outputPath,
      rootPath: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (!ok) {
    return;
  }
  await refreshStatus(false);
  const packageMessage = accessMode === 'public'
    ? `Created public partner package for ${appId}.`
    : `Created partner package for ${appId}. Treat this file as secret.`;
  const openChoice = await vscode.window.showInformationMessage(
    packageMessage,
    'Open File',
    'Reveal Folder',
  );
  if (openChoice === 'Open File') {
    const document = await vscode.workspace.openTextDocument(outputPath);
    await vscode.window.showTextDocument(document);
  } else if (openChoice === 'Reveal Folder') {
    await vscode.commands.executeCommand(
      'revealFileInOS',
      vscode.Uri.file(outputPath),
    );
  }
}

export async function validatePartnerPackage(output: vscode.OutputChannel): Promise<void> {
  const packagePath = await choosePartnerPackageFile();
  if (!packagePath) {
    return;
  }
  await validatePartnerPackageFile(packagePath, output);
}

export async function validatePartnerPackageFile(
  packagePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  try {
    const decoded = JSON.parse(await fs.promises.readFile(packagePath, 'utf8'));
    const errors = validatePartnerPackageJson(decoded);
    output.show(true);
    output.appendLine('');
    output.appendLine(`Validated partner package: ${packagePath}`);
    if (errors.length > 0) {
      for (const error of errors) {
        output.appendLine(`- ${error}`);
      }
      vscode.window.showErrorMessage(
        `Partner package is invalid. See MiniProgram output.`,
      );
      return false;
    }
    output.appendLine(`App ID: ${decoded.appId}`);
    output.appendLine(`Title: ${decoded.title ?? ''}`);
    output.appendLine(`API base URL: ${decoded.apiBaseUrl}`);
    output.appendLine(`Publisher API URL: ${decoded.backendBaseUrl ?? 'not configured'}`);
    output.appendLine(`Access mode: ${decoded.accessMode ?? 'protected'}`);
    output.appendLine(`Access key: ${decoded.accessKey ? '<redacted>' : 'not required'}`);
    vscode.window.showInformationMessage('Partner package looks valid.');
    return true;
  } catch (error) {
    const message = `Failed to validate partner package: ${errorMessage(error)}`;
    output.show(true);
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
    return false;
  }
}

export async function openPartnerPackage(): Promise<void> {
  const packagePath = await choosePartnerPackageFile();
  if (!packagePath) {
    return;
  }
  const choice = await vscode.window.showQuickPick(
    [
      { label: 'Open File', value: 'open' },
      { label: 'Reveal Folder', value: 'reveal' },
    ],
    { title: 'Open partner package', ignoreFocusOut: true },
  );
  if (!choice) {
    return;
  }
  if (choice.value === 'open') {
    const document = await vscode.workspace.openTextDocument(packagePath);
    await vscode.window.showTextDocument(document);
  } else {
    await vscode.commands.executeCommand(
      'revealFileInOS',
      vscode.Uri.file(packagePath),
    );
  }
}
