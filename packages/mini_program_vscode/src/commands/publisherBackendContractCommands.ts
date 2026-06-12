import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildPublisherBackendContractHandoffArgs,
  buildPublisherBackendContractInitArgs,
  buildPublisherBackendContractSmokeArgs,
  buildPublisherBackendContractValidateArgs,
} from '../cli';

import {
  chooseEndpointAccessMode,
  choosePartnerPackageOutputPath,
  ensurePublisherBackendContractCli0405,
  readMiniProgramManifestInfo,
  requireMiniProgramRoot,
  runCliCommand,
  safeFileSegment,
  validateAbsoluteUrl,
} from '../extensionSupport';

export async function publisherBackendContractInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!await ensurePublisherBackendContractCli0405(workspacePath, output)) {
    return;
  }

  const backendBaseUrl = await vscode.window.showInputBox({
    prompt: 'Publisher API base URL',
    placeHolder: 'https://api.publisher.example/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!backendBaseUrl) {
    return;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
  }
  const healthEndpoint = await vscode.window.showInputBox({
    prompt: 'Health endpoint',
    value: 'health',
    placeHolder: 'health',
    ignoreFocusOut: true,
    validateInput: (value) =>
      value.trim() ? undefined : 'Health endpoint is required.',
  });
  if (healthEndpoint === undefined) {
    return;
  }
  const allowLocalHttp = await chooseAllowLocalHttpIfNeeded(
    backendBaseUrl.trim(),
    'Publisher API URL policy',
  );
  if (allowLocalHttp === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Init Publisher API Contract',
    buildPublisherBackendContractInitArgs({
      miniProgramRoot: workspacePath,
      backendBaseUrl,
      public: accessMode === 'public',
      healthEndpoint,
      allowLocalHttp,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
    vscode.window.showInformationMessage('Publisher API contract created.');
  }
}

export async function publisherBackendContractValidate(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!await ensurePublisherBackendContractCli0405(workspacePath, output)) {
    return;
  }
  const contractPath = await chooseContractPath(workspacePath);
  if (contractPath === undefined) {
    return;
  }
  const allowLocalHttp = await chooseAllowLocalHttp('Backend contract URL policy');
  if (allowLocalHttp === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Validate Publisher API Contract',
    buildPublisherBackendContractValidateArgs({
      miniProgramRoot: workspacePath,
      contractPath: contractPath || undefined,
      allowLocalHttp,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    vscode.window.showInformationMessage('Publisher API contract is valid.');
  }
}

export async function publisherBackendContractSmoke(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!await ensurePublisherBackendContractCli0405(workspacePath, output)) {
    return;
  }
  const contractPath = await chooseContractPath(workspacePath);
  if (contractPath === undefined) {
    return;
  }
  const credentials = await chooseSmokeCredentials();
  if (!credentials) {
    return;
  }
  const timeoutSeconds = await vscode.window.showInputBox({
    prompt: 'Optional smoke timeout in seconds',
    placeHolder: 'Leave blank for CLI default',
    ignoreFocusOut: true,
    validateInput: (value) => {
      const trimmed = value.trim();
      if (!trimmed) {
        return undefined;
      }
      const parsed = Number.parseInt(trimmed, 10);
      return Number.isInteger(parsed) && parsed > 0 && parsed <= 300
        ? undefined
        : 'Timeout must be between 1 and 300 seconds.';
    },
  });
  if (timeoutSeconds === undefined) {
    return;
  }
  const allowLocalHttp = await chooseAllowLocalHttp('Backend contract URL policy');
  if (allowLocalHttp === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Smoke Test Publisher API Contract',
    buildPublisherBackendContractSmokeArgs({
      miniProgramRoot: workspacePath,
      contractPath: contractPath || undefined,
      accessKey: credentials.accessKey,
      authToken: credentials.authToken,
      timeoutSeconds: timeoutSeconds.trim() || undefined,
      allowLocalHttp,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    vscode.window.showInformationMessage('Publisher API smoke passed.');
  }
}

export async function publisherBackendContractHandoff(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!await ensurePublisherBackendContractCli0405(workspacePath, output)) {
    return;
  }
  const contractPath = await chooseContractPath(workspacePath);
  if (contractPath === undefined) {
    return;
  }
  const manifest = await readMiniProgramManifestInfo(workspacePath);
  const appId =
    await readContractAppId(contractPath || path.join(workspacePath, 'publisher_backend.json')) ??
    manifest?.id ??
    safeFileSegment(path.basename(workspacePath));
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title for host developers',
    value: manifest?.title ?? titleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }
  const deliveryUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program static delivery URL',
    placeHolder: 'https://cdn.example.com/public_mini_program/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!deliveryUrl) {
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
  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return;
  }
  const allowLocalHttp = await chooseAllowLocalHttp('Backend and delivery URL policy');
  if (allowLocalHttp === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Create Publisher API Handoff Package',
    buildPublisherBackendContractHandoffArgs({
      miniProgramRoot: workspacePath,
      contractPath: contractPath || undefined,
      deliveryUrl,
      title: title.trim() || undefined,
      accessKey,
      public: accessMode === 'public',
      outputPath,
      allowLocalHttp,
    }),
    workspacePath,
    output,
  );
  if (!ok) {
    return;
  }
  await refreshStatus(false);
  const message = accessMode === 'public'
    ? 'Publisher API handoff package created.'
    : 'Protected Publisher API handoff package created. Treat this file as secret.';
  const openChoice = await vscode.window.showInformationMessage(
    message,
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

async function chooseContractPath(workspacePath: string): Promise<string | undefined> {
  const defaultPath = path.join(workspacePath, 'publisher_backend.json');
  const files = await findContractFiles(workspacePath);
  const choices = [
    {
      label: fs.existsSync(defaultPath)
        ? 'publisher_backend.json'
        : 'Default publisher_backend.json',
      description: fs.existsSync(defaultPath)
        ? defaultPath
        : 'Use CLI default path',
      value: '' as const,
    },
    ...files
      .filter((filePath) => path.resolve(filePath) !== path.resolve(defaultPath))
      .map((filePath) => ({
        label: path.basename(filePath),
        description: path.dirname(filePath),
        value: filePath,
      })),
    {
      label: 'Choose another file...',
      description: 'Select a Publisher API contract JSON file',
      value: '__choose__' as const,
    },
  ];
  const selected = await vscode.window.showQuickPick(choices, {
    title: 'Publisher API contract',
    ignoreFocusOut: true,
  });
  if (!selected) {
    return undefined;
  }
  if (selected.value === '') {
    return '';
  }
  if (selected.value !== '__choose__') {
    return selected.value;
  }
  const selectedFiles = await vscode.window.showOpenDialog({
    canSelectFiles: true,
    canSelectFolders: false,
    canSelectMany: false,
    defaultUri: vscode.Uri.file(defaultPath),
    filters: {
      'Publisher API contract JSON': ['json'],
    },
    openLabel: 'Use contract',
    title: 'Choose Publisher API contract file',
  });
  return selectedFiles?.[0]?.fsPath;
}

async function findContractFiles(workspacePath: string): Promise<string[]> {
  const files: string[] = [];
  async function visit(directoryPath: string, depth: number): Promise<void> {
    if (depth > 2 || files.length >= 20) {
      return;
    }
    let entries: fs.Dirent[];
    try {
      entries = await fs.promises.readdir(directoryPath, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (
        entry.name === 'node_modules' ||
        entry.name === '.git' ||
        entry.name === 'build' ||
        entry.name === '.dart_tool'
      ) {
        continue;
      }
      const entryPath = path.join(directoryPath, entry.name);
      if (
        entry.isFile() &&
        entry.name.endsWith('.json') &&
        entry.name.includes('publisher_backend')
      ) {
        files.push(entryPath);
      } else if (entry.isDirectory()) {
        await visit(entryPath, depth + 1);
      }
      if (files.length >= 20) {
        return;
      }
    }
  }
  await visit(workspacePath, 0);
  return files.sort((left, right) => left.localeCompare(right));
}

async function chooseSmokeCredentials(): Promise<
  { readonly accessKey?: string; readonly authToken?: string } | undefined
> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'No credentials',
        description: 'Use for public endpoints or expected auth-required checks',
        value: 'none' as const,
      },
      {
        label: 'Access key',
        description: 'Use for protected partner/backend access',
        value: 'access_key' as const,
      },
      {
        label: 'Bearer token',
        description: 'Use for signed-in user smoke cases',
        value: 'auth_token' as const,
      },
      {
        label: 'Access key + bearer token',
        description: 'Use for protected signed-in user smoke cases',
        value: 'both' as const,
      },
    ],
    { title: 'Publisher API smoke credentials', ignoreFocusOut: true },
  );
  if (!choice) {
    return undefined;
  }
  let accessKey: string | undefined;
  let authToken: string | undefined;
  if (choice.value === 'access_key' || choice.value === 'both') {
    const value = await vscode.window.showInputBox({
      prompt: 'MiniProgram access key for smoke',
      password: true,
      placeHolder: 'mpk_live_...',
      ignoreFocusOut: true,
      validateInput: (input) =>
        input.trim() ? undefined : 'Access key is required.',
    });
    if (!value) {
      return undefined;
    }
    accessKey = value.trim();
  }
  if (choice.value === 'auth_token' || choice.value === 'both') {
    const value = await vscode.window.showInputBox({
      prompt: 'Authorization bearer token for smoke',
      password: true,
      ignoreFocusOut: true,
      validateInput: (input) =>
        input.trim() ? undefined : 'Bearer token is required.',
    });
    if (!value) {
      return undefined;
    }
    authToken = value.trim();
  }
  return { accessKey, authToken };
}

async function chooseAllowLocalHttpIfNeeded(
  url: string,
  title: string,
): Promise<boolean | undefined> {
  return /^http:\/\//i.test(url) ? chooseAllowLocalHttp(title) : false;
}

async function chooseAllowLocalHttp(title: string): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'HTTPS or loopback only',
        description: 'Production-safe default',
        value: false,
      },
      {
        label: 'Allow LAN HTTP for device testing',
        description: 'Pass --allow-local-http',
        value: true,
      },
    ],
    { title, ignoreFocusOut: true },
  );
  return choice?.value;
}

async function readContractAppId(filePath: string): Promise<string | undefined> {
  try {
    const decoded = JSON.parse(await fs.promises.readFile(filePath, 'utf8')) as {
      readonly appId?: unknown;
    };
    return typeof decoded.appId === 'string' && decoded.appId.trim()
      ? decoded.appId.trim()
      : undefined;
  } catch {
    return undefined;
  }
}

function titleFromAppId(appId: string): string {
  return appId
    .split(/[_-]+/)
    .filter(Boolean)
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join(' ') || appId;
}
