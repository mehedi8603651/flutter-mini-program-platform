import * as fs from 'fs';
import * as vscode from 'vscode';

import {
  buildPartnerPackageArgs,
  buildPublisherBackendContractInitArgs,
  buildPublisherBackendUrlsArgs,
  formatCommandLine,
} from '../cli';
import {
  choosePartnerPackageFile,
  choosePartnerPackageOutputPath,
  configuredCliPath,
  errorMessage,
  promptAppId,
  requireWorkspacePath,
  runCliCapture,
  runCliCommand,
  titleFromAppId,
  validateAbsoluteUrl,
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
  const port = await vscode.window.showInputBox({
    prompt: 'Publisher mock backend port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const args = buildPublisherBackendContractInitArgs({
    publisherApiUrl: `http://127.0.0.1:${port.trim()}/`,
    allowLocalHttp: true,
  });
  const command = formatCommandLine(configuredCliPath(), args);
  await vscode.env.clipboard.writeText(command);
  vscode.window.showInformationMessage(
    'Mock Publisher API contract command copied.',
  );
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
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program static artifact base URL',
    placeHolder: 'https://cdn.example.com/public_mini_program/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }

  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return;
  }

  const ok = await runCliCommand(
    'Create Partner Package',
    buildPartnerPackageArgs({
      appId,
      title: title.trim() || undefined,
      apiBaseUrl: apiBaseUrl.trim(),
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
  const openChoice = await vscode.window.showInformationMessage(
    `Created static artifact partner package for ${appId}.`,
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
    output.appendLine(`Artifact base URL: ${decoded.artifactBaseUrl ?? decoded.apiBaseUrl}`);
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
