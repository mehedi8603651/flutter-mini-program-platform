import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  resolveCliPath,
} from '../cli';
import {
  MiniProgramRegistryEntry,
  parseEndpointAppIds,
  parseRegistryEntries,
  upsertRegistryEntry,
} from '../hostIntegration';

import {
  stringValue,
} from './jsonValues';

export function configuredCliPath(): string {
  return resolveCliPath(
    vscode.workspace.getConfiguration('miniProgram').get<string>('cliPath'),
  );
}

export function configuredDefaultPreviewDevice(): string {
  const value = vscode.workspace
    .getConfiguration('miniProgram')
    .get<string>('defaultPreviewDevice');
  return value?.trim() || 'emulator-5554';
}

export function autoRefreshEnabled(): boolean {
  return vscode.workspace
    .getConfiguration('miniProgram')
    .get<boolean>('status.autoRefresh', true);
}

export function getWorkspacePath(): string | undefined {
  const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
  if (workspaceFolder) {
    return workspaceFolder.uri.fsPath;
  }
  const activeFile = vscode.window.activeTextEditor?.document.uri;
  if (activeFile?.scheme === 'file') {
    return path.dirname(activeFile.fsPath);
  }
  return undefined;
}

export async function requireHostProjectRoot(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage('Open a Flutter host app folder first.');
    return undefined;
  }
  if (!fs.existsSync(path.join(workspacePath, 'pubspec.yaml'))) {
    vscode.window.showWarningMessage(
      'Open the Flutter host app root folder that contains pubspec.yaml.',
    );
    return undefined;
  }
  return workspacePath;
}

export async function requireMiniProgramRoot(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage('Open a mini-program workspace first.');
    return undefined;
  }
  if (!fs.existsSync(path.join(workspacePath, 'manifest.json'))) {
    vscode.window.showWarningMessage(
      'Open the exact mini-program root folder that contains manifest.json.',
    );
    return undefined;
  }
  return workspacePath;
}

export async function requireWorkspacePath(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage(
      'Open a mini-program or Flutter host app folder first.',
    );
    return undefined;
  }
  return workspacePath;
}

export async function readHostEndpointAppIds(projectRoot: string): Promise<string[]> {
  const endpointPath = path.join(
    projectRoot,
    'lib',
    'mini_program',
    'mini_program_endpoints.dart',
  );
  const source = await readOptionalText(endpointPath);
  return source ? parseEndpointAppIds(source) : [];
}

export async function readHostRegistryEntries(
  projectRoot: string,
): Promise<MiniProgramRegistryEntry[]> {
  const source = await readOptionalText(hostRegistryPath(projectRoot));
  return source ? parseRegistryEntries(source) : [];
}

export async function writeRegistryEntry(
  projectRoot: string,
  entry: MiniProgramRegistryEntry,
): Promise<void> {
  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const source = upsertRegistryEntry(existingSource, entry);
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
}

export async function readWorkspaceManifest(
  workspacePath: string,
): Promise<{ readonly id?: string; readonly title?: string } | undefined> {
  try {
    const raw = await fs.promises.readFile(
      path.join(workspacePath, 'manifest.json'),
      'utf8',
    );
    const decoded = JSON.parse(raw) as Record<string, unknown>;
    return {
      id: typeof decoded.id === 'string' ? decoded.id : undefined,
      title: typeof decoded.title === 'string' ? decoded.title : undefined,
    };
  } catch {
    return undefined;
  }
}

export async function readOptionalText(filePath: string): Promise<string | undefined> {
  try {
    return await fs.promises.readFile(filePath, 'utf8');
  } catch {
    return undefined;
  }
}

export function hostRegistryPath(projectRoot: string): string {
  return path.join(projectRoot, 'lib', 'mini_program', 'mini_program_registry.dart');
}

export async function readMiniProgramManifestInfo(
  workspacePath: string,
): Promise<{ readonly id?: string; readonly title?: string } | undefined> {
  try {
    const manifestPath = path.join(workspacePath, 'manifest.json');
    const decoded = JSON.parse(await fs.promises.readFile(manifestPath, 'utf8')) as Record<
      string,
      unknown
    >;
    return {
      id: stringValue(decoded.id),
      title: stringValue(decoded.title),
    };
  } catch {
    return undefined;
  }
}

export async function readMiniProgramManifestId(
  workspacePath: string,
): Promise<string | undefined> {
  return (await readMiniProgramManifestInfo(workspacePath))?.id;
}

export async function inferWorkspaceMiniProgramAppId(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    return undefined;
  }
  const manifestPath = path.join(workspacePath, 'manifest.json');
  try {
    if (!fs.existsSync(manifestPath)) {
      return undefined;
    }
    const decoded = JSON.parse(await fs.promises.readFile(manifestPath, 'utf8'));
    return typeof decoded.id === 'string' ? decoded.id : undefined;
  } catch {
    return undefined;
  }
}
