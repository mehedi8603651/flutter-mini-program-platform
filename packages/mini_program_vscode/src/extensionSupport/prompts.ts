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
  validateOptionalAbsoluteUrl,
  validatePort,
} from './jsonValues';
import {
  getWorkspacePath,
  inferWorkspaceMiniProgramAppId,
  readHostEndpointAppIds,
  readHostRegistryEntries,
} from './workspace';

export async function chooseHostProjectRootForFirebase(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    defaultUri: workspacePath ? vscode.Uri.file(path.dirname(workspacePath)) : undefined,
    openLabel: 'Use host app root',
    title: 'Choose Flutter host app root',
  });
  const projectRoot = folders?.[0]?.fsPath;
  if (!projectRoot) {
    return undefined;
  }
  if (!fs.existsSync(path.join(projectRoot, 'pubspec.yaml'))) {
    vscode.window.showWarningMessage(
      'Choose the Flutter host app root folder that contains pubspec.yaml.',
    );
    return undefined;
  }
  return projectRoot;
}

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

export async function promptKeyId(
  prompt: string,
  placeHolder: string,
): Promise<string | undefined> {
  const keyId = await vscode.window.showInputBox({
    prompt,
    placeHolder,
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Key id is required.',
  });
  return keyId?.trim() || undefined;
}

export async function promptHostEndpointInputs(): Promise<
  | {
      readonly appId: string;
      readonly title: string;
      readonly apiBaseUrl: string;
      readonly backendBaseUrl?: string;
      readonly backendLocalMock?: boolean;
      readonly backendLocalMockPort?: string;
      readonly accessKey?: string;
      readonly public?: boolean;
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
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://example.com/prod/api',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return undefined;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return undefined;
  }
  let accessKey: string | undefined;
  if (accessMode === 'protected') {
    const value = await vscode.window.showInputBox({
      prompt: 'MiniProgram access key',
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
  const backend = await choosePublisherBackendMode();
  if (!backend) {
    return undefined;
  }
  return {
    appId: appId.trim(),
    title: title.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
    backendBaseUrl: backend.kind === 'remote' ? backend.backendBaseUrl : undefined,
    backendLocalMock: backend.kind === 'local_mock',
    backendLocalMockPort: backend.kind === 'local_mock' ? backend.port : undefined,
    accessKey,
    public: accessMode === 'public',
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

export async function promptOptionalEnvName(): Promise<string | undefined> {
  const envName = await vscode.window.showInputBox({
    prompt: 'Optional cloud environment name',
    placeHolder: 'Leave blank to use active environment',
    ignoreFocusOut: true,
  });
  return envName === undefined ? undefined : envName.trim() || '';
}

export async function promptRequiredEnvName(prompt: string): Promise<string | undefined> {
  const envName = await vscode.window.showInputBox({
    prompt,
    placeHolder: 'my-aws-prod',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Environment is required.',
  });
  return envName === undefined ? undefined : envName.trim();
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

export async function chooseFirebaseHostingOutputFolder(
  workspacePath: string,
): Promise<string | undefined> {
  const defaultUri = vscode.Uri.file(
    path.join(workspacePath, 'backend', 'firebase_hosting', 'public'),
  );
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    defaultUri,
    openLabel: 'Use Firebase Hosting public folder',
    title: 'Choose Firebase Hosting public folder',
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

export async function chooseFirebaseHostingDryRun(): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Deploy to Firebase Hosting',
        description: 'Build static delivery and run firebase deploy',
        value: false,
      },
      {
        label: 'Dry run only',
        description: 'Build static delivery and firebase.json without deploying',
        value: true,
      },
    ],
    { title: 'Firebase Hosting publish mode', ignoreFocusOut: true },
  );
  return choice?.value;
}

export async function chooseRequireAccessKeys(): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Require access keys',
        description: 'Recommended for shared cloud delivery',
        value: true,
      },
      {
        label: 'Do not require access keys',
        description: 'Only use for private/testing environments',
        value: false,
      },
    ],
    { title: 'Cloud delivery access-key policy', ignoreFocusOut: true },
  );
  return choice?.value;
}

export async function chooseEndpointAccessMode(): Promise<'protected' | 'public' | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Protected endpoint',
        description: 'Requires a MiniProgram access key',
        value: 'protected' as const,
      },
      {
        label: 'Public/static endpoint',
        description: 'No access key; use only for public CDN/GitHub Pages content',
        value: 'public' as const,
      },
    ],
    { title: 'MiniProgram endpoint access mode', ignoreFocusOut: true },
  );
  return choice?.value;
}

export async function promptOptionalPublisherBackendBaseUrl(): Promise<string | undefined> {
  const value = await vscode.window.showInputBox({
    prompt: 'Optional publisher-owned backend base URL',
    placeHolder: 'https://publisher.example.com/api/ (leave blank for none)',
    ignoreFocusOut: true,
    validateInput: validateOptionalAbsoluteUrl,
  });
  return value?.trim() || undefined;
}

export async function choosePublisherBackendMode(): Promise<PublisherBackendMode | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'No backend',
        description: 'Only configure manifest/screen delivery',
        value: 'none' as const,
      },
      {
        label: 'Local mock Publisher API',
        description: 'Use miniprogram publisher-backend run, default port 9090',
        value: 'local_mock' as const,
      },
      {
        label: 'Remote Publisher API',
        description: 'Use a real HTTPS publisher-owned API base URL',
        value: 'remote' as const,
      },
    ],
    { title: 'Publisher API mode', ignoreFocusOut: true },
  );
  if (!choice) {
    return undefined;
  }
  if (choice.value === 'none') {
    return { kind: 'none' };
  }
  if (choice.value === 'local_mock') {
    const port = await vscode.window.showInputBox({
      prompt: 'Publisher mock backend port',
      value: '9090',
      ignoreFocusOut: true,
      validateInput: validatePort,
    });
    return port ? { kind: 'local_mock', port: port.trim() } : undefined;
  }
  const backendBaseUrl = await promptOptionalPublisherBackendBaseUrl();
  return backendBaseUrl ? { kind: 'remote', backendBaseUrl } : undefined;
}

export type PublisherBackendMode =
  | { readonly kind: 'none' }
  | { readonly kind: 'local_mock'; readonly port: string }
  | { readonly kind: 'remote'; readonly backendBaseUrl: string };

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
      label: 'Discovered/default backend workspace',
      description: 'Do not pass --root',
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
    title: 'Backend workspace root',
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
    openLabel: 'Use backend root',
    title: 'Choose backend workspace root',
  });
  return folders?.[0]?.fsPath;
}
