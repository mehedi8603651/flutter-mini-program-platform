import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildPublisherBackendContractInitArgs,
  buildPublisherBackendContractSmokeArgs,
  buildPublisherBackendContractValidateArgs,
} from '../cli';

import {
  ensurePublisherBackendContractCli0405,
  requireMiniProgramRoot,
  runCliCommand,
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
  { readonly authToken?: string } | undefined
> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'No credentials',
        description: 'Use for public endpoints or expected auth-required checks',
        value: 'none' as const,
      },
      {
        label: 'Bearer token',
        description: 'Use for signed-in user smoke cases',
        value: 'auth_token' as const,
      },
    ],
    { title: 'Publisher API smoke credentials', ignoreFocusOut: true },
  );
  if (!choice) {
    return undefined;
  }
  let authToken: string | undefined;
  if (choice.value === 'auth_token') {
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
  return { authToken };
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

