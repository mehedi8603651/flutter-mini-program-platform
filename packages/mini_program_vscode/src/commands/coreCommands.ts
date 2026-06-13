import * as fs from 'fs';
import * as vscode from 'vscode';

import {
  buildCreateArgs,
  buildPreviewArgs,
  buildPublishArgs,
  formatCommandLine,
} from '../cli';

import {
  appendFirebaseHostingDeliveryDiagnostics,
  chooseFirebaseHostingDryRun,
  chooseFirebaseHostingOutputFolder,
  chooseMiniProgramBackendStarter,
  chooseStaticClean,
  chooseStaticOutputFolder,
  configuredCliPath,
  configuredDefaultPreviewDevice,
  ensureFirebaseHostingPublishCli042,
  ensureMpCreateCli040,
  getWorkspacePath,
  parseJsonObject,
  requireMiniProgramRoot,
  resolveCreateOutputRoot,
  runCliCapture,
  runCliCommand,
  runMiniProgramWorkspaceCliCommand,
  stringValue,
  titleFromAppId,
  validateOptionalSafeSegment,
  withFirebaseHostingDeliveryDiagnostics,
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
        label: 'cloud',
        description: 'Publish to the active or selected cloud environment',
      },
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

  let envName: string | undefined;
  if (targetChoice.label === 'cloud') {
    const value = await vscode.window.showInputBox({
      prompt: 'Optional cloud environment name',
      placeHolder: 'Leave blank to use active environment',
      ignoreFocusOut: true,
    });
    if (value === undefined) {
      return;
    }
    envName = value.trim() || undefined;
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
        target: targetChoice.label as 'local' | 'cloud' | 'static',
        envName,
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

export async function publishFirebaseHostingMiniProgram(
  output: vscode.OutputChannel,
  refreshStatus: () => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensureFirebaseHostingPublishCli042(workspacePath, output))) {
    return;
  }
  const envName = await vscode.window.showInputBox({
    prompt: 'Firebase Hosting environment name',
    placeHolder: 'my-firebase-prod',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Environment is required.',
  });
  if (!envName) {
    return;
  }
  const outputPath = await chooseFirebaseHostingOutputFolder(workspacePath);
  if (!outputPath) {
    return;
  }
  const clean = await chooseStaticClean();
  if (clean === undefined) {
    return;
  }
  const siteIdInput = await vscode.window.showInputBox({
    prompt: 'Optional Firebase Hosting site ID',
    placeHolder: 'Leave blank to use the default project Hosting site',
    ignoreFocusOut: true,
    validateInput: validateOptionalSafeSegment,
  });
  if (siteIdInput === undefined) {
    return;
  }
  const dryRun = await chooseFirebaseHostingDryRun();
  if (dryRun === undefined) {
    return;
  }

  const result = await runCliCapture(
    'Publish MiniProgram to Firebase Hosting',
    buildPublishArgs({
      target: 'firebase-hosting',
      envName,
      outputPath,
      siteId: siteIdInput.trim() || undefined,
      clean,
      dryRun,
      json: true,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (!result) {
    return;
  }
  const decoded = parseJsonObject(result.stdout);
  const deliveryUrl = stringValue(decoded.deliveryApiBaseUrl);
  output.appendLine('');
  output.appendLine(
    dryRun
      ? 'Firebase Hosting static delivery prepared.'
      : 'Firebase Hosting static delivery published.',
  );
  if (deliveryUrl) {
    output.appendLine(`Static artifact base URL: ${deliveryUrl}`);
    if (!dryRun) {
      const deliveryStatus = await withFirebaseHostingDeliveryDiagnostics({
        miniProgramId: stringValue(decoded.miniProgramId),
        deliveryApiBaseUrl: deliveryUrl,
      });
      appendFirebaseHostingDeliveryDiagnostics(output, deliveryStatus);
      if (deliveryStatus.hostingCorsReady === false) {
        vscode.window.showWarningMessage(
          'Firebase Hosting published, but browser CORS headers were not detected. Republish with mini_program_tooling 0.3.42 or newer.',
        );
      }
    }
    output.appendLine('Next handoff step:');
    output.appendLine(publisherApiHandoffCommand(deliveryUrl));
  }
  await refreshStatus();

  const action = await vscode.window.showInformationMessage(
    dryRun
      ? 'Firebase Hosting dry-run completed.'
      : 'Firebase Hosting publish completed.',
    ...(deliveryUrl
      ? ['Copy Publisher API handoff command', 'Copy delivery URL']
      : ['Close']),
  );
  if (action === 'Copy delivery URL' && deliveryUrl) {
    await vscode.env.clipboard.writeText(deliveryUrl);
    vscode.window.showInformationMessage('Firebase Hosting delivery URL copied.');
  }
  if (action === 'Copy Publisher API handoff command' && deliveryUrl) {
    await vscode.env.clipboard.writeText(publisherApiHandoffCommand(deliveryUrl));
    vscode.window.showInformationMessage('Publisher API handoff command copied.');
  }
}

function publisherApiHandoffCommand(deliveryUrl: string): string {
  return `miniprogram publisher-api contract handoff --delivery-url ${deliveryUrl} --public`;
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
