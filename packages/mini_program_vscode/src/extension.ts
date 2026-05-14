import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildBuildArgs,
  buildCreateArgs,
  buildPreviewArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  formatCommandLine,
  resolveCliPath,
  runCli,
  runCliStreaming,
} from './cli';
import { MiniProgramStatusTreeProvider } from './statusTree';
import { parseWorkflowStatusJson } from './workflowStatus';

const outputChannelName = 'MiniProgram';

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel(outputChannelName);
  const statusProvider = new MiniProgramStatusTreeProvider();

  context.subscriptions.push(output);
  context.subscriptions.push(
    vscode.window.registerTreeDataProvider(
      'miniProgramTools.statusView',
      statusProvider,
    ),
  );

  const refreshStatus = async (remote: boolean) => {
    const workspacePath = getWorkspacePath();
    if (!workspacePath) {
      const message = 'Open a mini-program or Flutter host app folder first.';
      statusProvider.setError(message);
      vscode.window.showWarningMessage(message);
      return;
    }

    const cliPath = configuredCliPath();
    const args = buildWorkflowStatusArgs({ workspacePath, remote });
    output.appendLine(`> ${formatCommandLine(cliPath, args)}`);
    try {
      const result = await runCli(cliPath, args, {
        cwd: workspacePath,
        timeoutMs: remote ? 120000 : 30000,
      });
      if (result.stderr.trim()) {
        output.append(result.stderr);
      }
      if (result.exitCode !== 0) {
        const detail = (result.stderr || result.stdout).trim();
        throw new Error(
          `Workflow status failed with exit code ${result.exitCode}.${detail ? `\n${detail}` : ''}`,
        );
      }
      const report = parseWorkflowStatusJson(result.stdout);
      statusProvider.setReport(report);
      output.appendLine(
        remote ? 'Remote workflow status refreshed.' : 'Workflow status refreshed.',
      );
    } catch (error) {
      const message = errorMessage(error);
      statusProvider.setError(message);
      output.appendLine(message);
      vscode.window.showErrorMessage(message);
    }
  };

  context.subscriptions.push(
    vscode.commands.registerCommand('miniProgramTools.refreshStatus', () =>
      refreshStatus(false),
    ),
    vscode.commands.registerCommand('miniProgramTools.refreshRemoteStatus', () =>
      refreshStatus(true),
    ),
    vscode.commands.registerCommand('miniProgramTools.createMiniProgram', () =>
      createMiniProgram(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.build', () =>
      runWorkspaceCliCommand('Build', buildBuildArgs(), output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.validate', () =>
      runWorkspaceCliCommand(
        'Validate',
        buildValidateArgs(),
        output,
        refreshStatus,
      ),
    ),
    vscode.commands.registerCommand('miniProgramTools.preview', () =>
      previewMiniProgram(),
    ),
    vscode.commands.registerCommand('miniProgramTools.publish', () =>
      publishMiniProgram(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.openOutput', () =>
      output.show(true),
    ),
  );

  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      if (autoRefreshEnabled()) {
        void refreshStatus(false);
      }
    }),
  );

  if (autoRefreshEnabled()) {
    void refreshStatus(false);
  }
}

export function deactivate(): void {
  // No long-running extension-owned process is kept alive.
}

async function createMiniProgram(output: vscode.OutputChannel): Promise<void> {
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    openLabel: 'Select parent folder',
    title: 'Choose where to create the mini-program',
  });
  const parentFolder = folders?.[0]?.fsPath;
  if (!parentFolder) {
    return;
  }

  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    validateInput: (value) => {
      const trimmed = value.trim();
      if (!trimmed) {
        return 'App ID is required.';
      }
      if (!/^[a-z][a-z0-9_]*$/.test(trimmed)) {
        return 'Use lowercase letters, numbers, and underscores, starting with a letter.';
      }
      return undefined;
    },
  });
  if (!appId) {
    return;
  }

  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title',
    placeHolder: titleFromAppId(appId),
    value: titleFromAppId(appId),
  });
  if (title === undefined) {
    return;
  }

  const outputRoot = path.join(parentFolder, appId);
  const args = buildCreateArgs({ appId, title, outputRoot });
  const ok = await runCliCommand('Create MiniProgram', args, parentFolder, output);
  if (!ok) {
    return;
  }

  const openChoice = await vscode.window.showInformationMessage(
    `Created mini-program ${appId}.`,
    'Open Folder',
  );
  if (openChoice === 'Open Folder') {
    await vscode.commands.executeCommand(
      'vscode.openFolder',
      vscode.Uri.file(outputRoot),
      false,
    );
  }
}

async function publishMiniProgram(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const targetChoice = await vscode.window.showQuickPick(
    [
      {
        label: 'cloud',
        description: 'Publish to the active or selected cloud environment',
      },
      { label: 'local', description: 'Publish to local delivery artifacts' },
    ],
    { title: 'MiniProgram publish target' },
  );
  if (!targetChoice) {
    return;
  }

  let envName: string | undefined;
  if (targetChoice.label === 'cloud') {
    const value = await vscode.window.showInputBox({
      prompt: 'Optional cloud environment name',
      placeHolder: 'Leave blank to use active environment',
    });
    if (value === undefined) {
      return;
    }
    envName = value.trim() || undefined;
  }

  await runWorkspaceCliCommand(
    'Publish',
    buildPublishArgs({ target: targetChoice.label as 'local' | 'cloud', envName }),
    output,
    refreshStatus,
  );
}

async function previewMiniProgram(): Promise<void> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage(
      'Open a mini-program workspace before running preview.',
    );
    return;
  }

  const defaultDevice = configuredDefaultPreviewDevice();
  const deviceId = await vscode.window.showInputBox({
    prompt: 'Preview device ID',
    value: defaultDevice,
    placeHolder: 'emulator-5554',
  });
  if (!deviceId) {
    return;
  }

  const cliPath = configuredCliPath();
  const args = buildPreviewArgs({ deviceId: deviceId.trim() });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Preview',
    cwd: workspacePath,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
}

async function runWorkspaceCliCommand(
  label: string,
  args: readonly string[],
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage(
      'Open a mini-program or Flutter host app folder first.',
    );
    return;
  }

  const ok = await runCliCommand(label, args, workspacePath, output);
  if (ok) {
    await refreshStatus(false);
  }
}

async function runCliCommand(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`> ${formatCommandLine(cliPath, args)}`);
  try {
    const result = await runCliStreaming(cliPath, args, {
      cwd,
      timeoutMs: 600000,
      onStdout: (chunk) => output.append(chunk),
      onStderr: (chunk) => output.append(chunk),
    });
    if (result.exitCode !== 0) {
      vscode.window.showErrorMessage(
        `${label} failed with exit code ${result.exitCode}.`,
      );
      return false;
    }
    vscode.window.showInformationMessage(`${label} completed.`);
    return true;
  } catch (error) {
    const message = errorMessage(error);
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
    return false;
  }
}

function configuredCliPath(): string {
  return resolveCliPath(
    vscode.workspace.getConfiguration('miniProgram').get<string>('cliPath'),
  );
}

function configuredDefaultPreviewDevice(): string {
  const value = vscode.workspace
    .getConfiguration('miniProgram')
    .get<string>('defaultPreviewDevice');
  return value?.trim() || 'emulator-5554';
}

function autoRefreshEnabled(): boolean {
  return vscode.workspace
    .getConfiguration('miniProgram')
    .get<boolean>('status.autoRefresh', true);
}

function getWorkspacePath(): string | undefined {
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

function titleFromAppId(appId: string): string {
  return appId
    .split(/[._-]+/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      return 'MiniProgram CLI was not found. Install it with `dart pub global activate mini_program_tooling` or set miniProgram.cliPath.';
    }
    return error.message;
  }
  return String(error);
}
