import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  MiniProgramRegistryEntry,
  titleFromAppId as hostTitleFromAppId,
} from '../hostIntegration';

import {
  validateAbsoluteUrl,
  validateAppId,
  validatePort,
} from './jsonValues';
import {
  getWorkspacePath,
  inferWorkspaceMiniProgramAppId,
  readHostEndpointAppIds,
  readHostRegistryEntries,
} from './workspace';

export async function promptAppId(): Promise<string | undefined> {
  const inferredAppId = await inferWorkspaceMiniProgramAppId();
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    value: inferredAppId,
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  return appId?.trim() || undefined;
}

export async function chooseMiniProgramBackendStarter(): Promise<
  { readonly backendTemplate?: 'mock' } | undefined
> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Normal mini-program',
        description: 'No mock Publisher API starter',
        backendTemplate: undefined,
      },
      {
        label: 'Mini-program with mock backend',
        description: 'Generate backend/mock and backend-bound starter UI',
        backendTemplate: 'mock' as const,
      },
    ],
    { title: 'Mock Publisher API starter', ignoreFocusOut: true },
  );
  return choice
    ? { backendTemplate: choice.backendTemplate }
    : undefined;
}

export async function promptHostEndpointInputs(): Promise<
  | {
      readonly appId: string;
      readonly title: string;
      readonly apiBaseUrl: string;
    }
  | undefined
> {
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return undefined;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId.trim()),
    placeHolder: 'Coupon Demo',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return undefined;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program static artifact base URL',
    placeHolder: 'https://example.com/prod/api',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return undefined;
  }
  return {
    appId: appId.trim(),
    title: title.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
  };
}

export async function chooseAppIdForRegistry(
  endpointAppIds: readonly string[],
): Promise<string | undefined> {
  if (endpointAppIds.length === 0) {
    const appId = await vscode.window.showInputBox({
      prompt: 'Mini-program appId',
      placeHolder: 'coupon_demo',
      ignoreFocusOut: true,
      validateInput: validateAppId,
    });
    return appId?.trim() || undefined;
  }

  const selected = await vscode.window.showQuickPick(
    [
      ...endpointAppIds.map((appId) => ({
        label: appId,
        description: 'Configured host endpoint',
        appId,
      })),
      {
        label: 'Enter another appId...',
        description: 'Add a registry entry before endpoint import',
        appId: '',
      },
    ],
    { title: 'Mini-program appId', ignoreFocusOut: true },
  );
  if (!selected) {
    return undefined;
  }
  if (selected.appId) {
    return selected.appId;
  }
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  return appId?.trim() || undefined;
}

export async function chooseHostEndpointAppId(
  projectRoot: string,
): Promise<string | undefined> {
  const endpointAppIds = await readHostEndpointAppIds(projectRoot);
  if (endpointAppIds.length === 0) {
    vscode.window.showWarningMessage(
      'No host endpoints found. Import or add an endpoint first.',
    );
    return undefined;
  }
  const selected = await vscode.window.showQuickPick(
    endpointAppIds.map((appId) => ({
      label: appId,
      description: 'Configured host endpoint',
      appId,
    })),
    { title: 'Choose host endpoint appId', ignoreFocusOut: true },
  );
  return selected?.appId;
}

export async function chooseHostMiniProgramEntry(
  projectRoot: string,
): Promise<MiniProgramRegistryEntry | undefined> {
  const registryEntries = await readHostRegistryEntries(projectRoot);
  const endpointAppIds = await readHostEndpointAppIds(projectRoot);
  const knownEntries = [
    ...registryEntries,
    ...endpointAppIds
      .filter((appId) => !registryEntries.some((entry) => entry.appId === appId))
      .map((appId) => ({ appId, title: hostTitleFromAppId(appId) })),
  ];

  const selected = await vscode.window.showQuickPick(
    [
      ...knownEntries.map((entry) => ({
        label: entry.title,
        description: entry.appId,
        entry,
      })),
      {
        label: 'Enter another mini-program...',
        description: 'Use a manual appId/title',
        entry: undefined,
      },
    ],
    { title: 'Choose mini-program for demo button', ignoreFocusOut: true },
  );
  if (!selected) {
    return undefined;
  }
  if (selected.entry) {
    return selected.entry;
  }
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return undefined;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title',
    value: hostTitleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return undefined;
  }
  return { appId: appId.trim(), title: title.trim() || hostTitleFromAppId(appId) };
}

export async function choosePartnerPackageOutputPath(
  workspacePath: string,
  appId: string,
): Promise<string | undefined> {
  const uri = await vscode.window.showSaveDialog({
    defaultUri: vscode.Uri.file(path.join(workspacePath, `${appId}.partner.json`)),
    filters: {
      'Partner package JSON': ['json'],
    },
    saveLabel: 'Create partner package',
    title: 'Choose partner package output file',
  });
  return uri?.fsPath;
}

export async function choosePartnerPackageFile(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  const existingPackages = workspacePath
    ? await findPartnerPackageFiles(workspacePath)
    : [];
  if (existingPackages.length > 0) {
    const selected = await vscode.window.showQuickPick(
      [
        ...existingPackages.map((filePath) => ({
          label: path.basename(filePath),
          description: path.dirname(filePath),
          filePath,
        })),
        {
          label: 'Choose another file...',
          description: 'Select a .partner.json file',
          filePath: '',
        },
      ],
      { title: 'Choose a MiniProgram partner package', ignoreFocusOut: true },
    );
    if (!selected) {
      return undefined;
    }
    if (selected.filePath) {
      return selected.filePath;
    }
  }

  const selectedFiles = await vscode.window.showOpenDialog({
    canSelectFiles: true,
    canSelectFolders: false,
    canSelectMany: false,
    filters: {
      'Partner package JSON': ['json'],
    },
    openLabel: 'Choose partner package',
    title: 'Choose a MiniProgram partner package',
  });
  return selectedFiles?.[0]?.fsPath;
}

export async function findPartnerPackageFiles(workspacePath: string): Promise<string[]> {
  const files: string[] = [];
  async function visit(directoryPath: string, depth: number): Promise<void> {
    if (depth > 3 || files.length >= 20) {
      return;
    }
    let entries: fs.Dirent[];
    try {
      entries = await fs.promises.readdir(directoryPath, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'build') {
        continue;
      }
      const entryPath = path.join(directoryPath, entry.name);
      if (entry.isFile() && entry.name.endsWith('.partner.json')) {
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

export async function chooseForce(prompt: string): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      { label: 'Normal', description: 'Do not pass --force', force: false },
      { label: 'Force', description: prompt, force: true },
    ],
    { title: 'MiniProgram command mode', ignoreFocusOut: true },
  );
  return choice?.force;
}

export interface HostRendererChoice {
  readonly enabled: boolean;
}

export async function chooseHostRendererChoice(): Promise<HostRendererChoice | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Mp-only host',
        description: 'Recommended default; smallest host with the Mp renderer',
        enabled: true,
      },
    ],
    { title: 'MiniProgram host renderer support', ignoreFocusOut: true },
  );
  return choice ? { enabled: choice.enabled } : undefined;
}

export async function chooseStaticOutputFolder(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  const defaultUri = workspacePath
    ? vscode.Uri.file(path.join(workspacePath, 'public_mini_program'))
    : undefined;
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    defaultUri,
    openLabel: 'Use static output folder',
    title: 'Choose public static output folder',
  });
  return folders?.[0]?.fsPath;
}

export async function chooseStaticClean(): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Clean generated output first',
        description: 'Removes generated manifests/screens/assets/metadata before publishing',
        value: true,
      },
      {
        label: 'Keep existing generated output',
        description: 'Overwrites current version files and keeps older versions',
        value: false,
      },
    ],
    { title: 'Public static publish cleanup', ignoreFocusOut: true },
  );
  return choice?.value;
}

export async function chooseBackendRoot(
  workspacePath: string,
  options: {
    readonly includeDefault: boolean;
    readonly includeCurrentWorkspace: boolean;
  },
): Promise<string | undefined> {
  const choices: Array<{
    readonly label: string;
    readonly description: string;
    readonly value: 'default' | 'workspace' | 'choose';
  }> = [];
  if (options.includeDefault) {
    choices.push({
      label: 'Discovered/default artifact host workspace',
      description: 'Default local artifact host workspace; do not pass --root',
      value: 'default',
    });
  }
  if (options.includeCurrentWorkspace) {
    choices.push({
      label: 'Current workspace',
      description: workspacePath,
      value: 'workspace',
    });
  }
  choices.push({
    label: 'Choose folder',
    description: 'Pass --root <folder>',
    value: 'choose',
  });

  const choice = await vscode.window.showQuickPick(choices, {
    title: 'Artifact host workspace root',
    ignoreFocusOut: true,
  });
  if (!choice) {
    return undefined;
  }
  if (choice.value === 'default') {
    return '';
  }
  if (choice.value === 'workspace') {
    return workspacePath;
  }
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    openLabel: 'Use artifact host root',
    title: 'Choose artifact host workspace root',
  });
  return folders?.[0]?.fsPath;
}
