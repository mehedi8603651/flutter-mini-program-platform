import * as fs from 'fs';
import * as vscode from 'vscode';

import {
  buildCreateArgs,
  buildPreviewArgs,
  buildPublishArgs,
  formatCommandLine,
} from '../cli';

import {
  chooseMiniProgramBackendStarter,
  chooseStaticClean,
  chooseStaticOutputFolder,
  configuredCliPath,
  configuredDefaultPreviewDevice,
  ensureMpCreateCli040,
  getWorkspacePath,
  requireMiniProgramRoot,
  resolveCreateOutputRoot,
  runCliCommand,
  runMiniProgramWorkspaceCliCommand,
  titleFromAppId,
} from '../extensionSupport';

export async function createMiniProgram(output: vscode.OutputChannel): Promise<void> {
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
  if (!(await ensureMpCreateCli040(parentFolder, output))) {
    return;
  }

  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
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
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }

  const backendChoice = await chooseMiniProgramBackendStarter();
  if (!backendChoice) {
    return;
  }
  const outputRoot = resolveCreateOutputRoot(parentFolder, appId);
  let force = false;
  if (directoryHasEntries(outputRoot)) {
    const overwriteChoice = await vscode.window.showQuickPick(
      [
        {
          label: 'Cancel',
          description: 'Choose a different appId or empty folder',
          force: false,
        },
        {
          label: 'Overwrite scaffold-managed files',
          description: 'Pass --force; unrelated files are left in place',
          force: true,
        },
      ],
      {
        title: 'Mini-program target folder already exists',
        ignoreFocusOut: true,
      },
    );
    if (!overwriteChoice?.force) {
      return;
    }
    force = true;
  }
  const args = buildCreateArgs({
    appId,
    title,
    outputRoot,
      backendTemplate: backendChoice.backendTemplate,
      screenFormat: 'mp',
      force,
  });
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

function directoryHasEntries(directoryPath: string): boolean {
  try {
    return fs.existsSync(directoryPath) && fs.readdirSync(directoryPath).length > 0;
  } catch {
    return false;
  }
}

export async function publishMiniProgram(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const targetChoice = await vscode.window.showQuickPick(
    [
      {
        label: 'static',
        description: 'Export public/CDN-ready files for GitHub Pages or static hosting',
      },
      { label: 'local', description: 'Publish to local delivery artifacts' },
    ],
    { title: 'MiniProgram publish target', ignoreFocusOut: true },
  );
  if (!targetChoice) {
    return;
  }

  let outputPath: string | undefined;
  let clean = false;
  if (targetChoice.label === 'static') {
    outputPath = await chooseStaticOutputFolder();
    if (!outputPath) {
      return;
    }
    const cleanChoice = await chooseStaticClean();
    if (cleanChoice === undefined) {
      return;
    }
    clean = cleanChoice;
  }

  await runMiniProgramWorkspaceCliCommand(
    'Publish',
    (workspacePath) =>
      buildPublishArgs({
        target: targetChoice.label as 'local' | 'static',
        outputPath,
        clean,
        miniProgramRoot: workspacePath,
      }),
    output,
    refreshStatus,
  );
}

export async function publishPublicStaticMiniProgram(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const outputPath = await chooseStaticOutputFolder();
  if (!outputPath) {
    return;
  }
  const clean = await chooseStaticClean();
  if (clean === undefined) {
    return;
  }

  await runMiniProgramWorkspaceCliCommand(
    'Publish Public Static MiniProgram',
    (workspacePath) =>
      buildPublishArgs({
        target: 'static',
        outputPath,
        clean,
        miniProgramRoot: workspacePath,
      }),
    output,
    refreshStatus,
  );
}

export async function previewMiniProgram(): Promise<void> {
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
    ignoreFocusOut: true,
  });
  if (!deviceId) {
    return;
  }

  const cliPath = configuredCliPath();
  const args = buildPreviewArgs({
    deviceId: deviceId.trim(),
    miniProgramRoot: workspacePath,
  });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Preview',
    cwd: workspacePath,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
}
