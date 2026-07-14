import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildEmbedInitArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  formatCommandLine,
} from '../cli';
import {
  buildDemoHostButtonSnippet,
  buildRegistryFile,
  titleFromAppId as hostTitleFromAppId,
  upsertRegistryEntry,
} from '../hostIntegration';

import {
  chooseAppIdForRegistry,
  chooseForce,
  chooseHostMiniProgramEntry,
  configuredCliPath,
  configuredDefaultPreviewDevice,
  hostRegistryPath,
  readHostEndpointAppIds,
  readOptionalText,
  requireHostProjectRoot,
  runWorkspaceCliCommand,
  validateAbsoluteUrl,
  validateAppId,
  writeRegistryEntry,
} from '../extensionSupport';

export async function embedInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const force = await chooseForce('Overwrite scaffold-managed host adapter files?');
  if (force === undefined) {
    return;
  }
  await runWorkspaceCliCommand(
    'Embed Init',
    buildEmbedInitArgs({ projectRoot, force }),
    output,
    refreshStatus,
  );
}

export async function importHostEndpoint(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const selectedFiles = await vscode.window.showOpenDialog({
    canSelectFiles: true,
    canSelectFolders: false,
    canSelectMany: false,
    filters: {
      'Partner package JSON': ['json'],
    },
    openLabel: 'Import partner package',
    title: 'Choose a MiniProgram partner package',
  });
  const partnerPackagePath = selectedFiles?.[0]?.fsPath;
  if (!partnerPackagePath) {
    return;
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Import Host Endpoint',
    buildHostEndpointImportArgs({ partnerPackagePath, projectRoot, force }),
    output,
    refreshStatus,
  );
}

export async function addHostEndpoint(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId.trim()),
    placeHolder: 'Coupon Demo',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program static artifact base URL',
    placeHolder: 'https://example.com/prod/api',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Add Host Endpoint',
    buildHostEndpointAddArgs({
      appId: appId.trim(),
      title: title.trim(),
      apiBaseUrl: apiBaseUrl.trim(),
      projectRoot,
      force,
    }),
    output,
    refreshStatus,
  );
}

export async function runHostApp(): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const defaultDevice = configuredDefaultPreviewDevice();
  const deviceId = await vscode.window.showInputBox({
    prompt: 'Flutter device ID',
    value: defaultDevice,
    placeHolder: 'emulator-5554',
    ignoreFocusOut: true,
  });
  if (!deviceId) {
    return;
  }
  const cliPath = configuredCliPath();
  const args = buildHostRunArgs({
    deviceId: deviceId.trim(),
    projectRoot,
  });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Host',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
}

export async function generateMiniProgramRegistry(
  output: vscode.OutputChannel,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appIds = await readHostEndpointAppIds(projectRoot);
  if (appIds.length === 0) {
    vscode.window.showWarningMessage(
      'No host endpoints found. Import or add an endpoint first.',
    );
    return;
  }

  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const entries = appIds.map((appId) => ({
    appId,
    title: hostTitleFromAppId(appId),
  }));
  const source = entries.reduce(
    (current, entry) => upsertRegistryEntry(current, entry),
    existingSource || buildRegistryFile(),
  );

  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
  output.show(true);
  output.appendLine('');
  output.appendLine(`Generated MiniProgram registry: ${registryPath}`);
  output.appendLine(`Entries: ${entries.map((entry) => entry.appId).join(', ')}`);
  vscode.window.showInformationMessage('MiniProgram registry generated.');
}

export async function addMiniProgramToRegistry(
  output: vscode.OutputChannel,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const endpointAppIds = await readHostEndpointAppIds(projectRoot);
  const appId = await chooseAppIdForRegistry(endpointAppIds);
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title',
    value: hostTitleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }

  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const source = upsertRegistryEntry(existingSource, {
    appId,
    title: title.trim() || hostTitleFromAppId(appId),
  });
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
  output.show(true);
  output.appendLine('');
  output.appendLine(`Updated MiniProgram registry: ${registryPath}`);
  output.appendLine(`Added/updated: ${appId}`);
  vscode.window.showInformationMessage(`MiniProgram registry updated for ${appId}.`);
}

export async function copyDemoHostButton(output: vscode.OutputChannel): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const entry = await chooseHostMiniProgramEntry(projectRoot);
  if (!entry) {
    return;
  }
  const style = await vscode.window.showQuickPick(
    [
      {
        label: 'Use MiniPrograms registry',
        description: 'Recommended for host apps with many mini-programs',
        useRegistry: true,
      },
      {
        label: 'Use inline appId/title',
        description: 'Simpler for one-button demos',
        useRegistry: false,
      },
    ],
    { title: 'Demo button style', ignoreFocusOut: true },
  );
  if (!style) {
    return;
  }

  if (style.useRegistry) {
    await writeRegistryEntry(projectRoot, entry);
  }
  const buttonSnippet = buildDemoHostButtonSnippet(entry, {
    useRegistry: style.useRegistry,
  });
  const importLines = [
    'mini_program/mini_program_launcher.dart',
    ...(style.useRegistry ? ['mini_program/mini_program_registry.dart'] : []),
  ].map((importPath) => `import '${importPath}';`);
  const snippet = [
    '// Add these imports if they are not already in this Dart file:',
    ...importLines.map((line) => `// ${line}`),
    '',
    buttonSnippet,
  ].join('\n');
  await vscode.env.clipboard.writeText(snippet);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied demo host button snippet:');
  output.appendLine(snippet);
  vscode.window.showInformationMessage(
    'Demo host button copied. Paste it into your host-owned UI.',
  );
}
