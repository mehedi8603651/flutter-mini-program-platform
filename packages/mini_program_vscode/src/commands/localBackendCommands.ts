import * as vscode from 'vscode';

import {
  buildBackendInitArgs,
  buildBackendStartArgs,
  buildBackendStatusArgs,
  buildBackendStopArgs,
  buildPublisherBackendFirebaseStarterUiArgs,
  buildPublisherBackendRunArgs,
  buildPublisherBackendScaffoldArgs,
  buildPublisherBackendStatusArgs,
  buildPublisherBackendStopArgs,
} from '../cli';

import {
  chooseBackendRoot,
  chooseFirebaseStarterUiForScaffold,
  chooseFirebaseStarterUiMode,
  chooseForce,
  ensurePublisherBackendFirebaseStarterUiCli049,
  requireMiniProgramRoot,
  requireWorkspacePath,
  runCliCommand,
  runWorkspaceCliCommand,
  validatePort,
} from '../extensionSupport';

export async function backendInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const backendRoot = await chooseBackendRoot(workspacePath, {
    includeDefault: true,
    includeCurrentWorkspace: true,
  });
  if (backendRoot === undefined) {
    return;
  }
  const force = await chooseForce('Overwrite scaffold-managed backend files?');
  if (force === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Backend Init',
    buildBackendInitArgs({ backendRoot: backendRoot || undefined, force }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function backendStart(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const port = await vscode.window.showInputBox({
    prompt: 'Local backend port',
    value: '8080',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const backendRoot = await chooseBackendRoot(workspacePath, {
    includeDefault: true,
    includeCurrentWorkspace: false,
  });
  if (backendRoot === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Backend Start',
    buildBackendStartArgs({
      backendRoot: backendRoot || undefined,
      port: port.trim(),
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function backendStop(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const backendRoot = await chooseBackendRoot(workspacePath, {
    includeDefault: true,
    includeCurrentWorkspace: false,
  });
  if (backendRoot === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Backend Stop',
    buildBackendStopArgs({ backendRoot: backendRoot || undefined }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function backendStatus(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const backendRoot = await chooseBackendRoot(workspacePath, {
    includeDefault: true,
    includeCurrentWorkspace: false,
  });
  if (backendRoot === undefined) {
    return;
  }
  await runCliCommand(
    'Backend Status',
    buildBackendStatusArgs({
      backendRoot: backendRoot || undefined,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendSetup(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const templateChoice = await vscode.window.showQuickPick(
    [
      {
        label: 'Mock local',
        value: 'mock' as const,
        storageMode: undefined,
        description: 'Local JSON API starter for development',
      },
      {
        label: 'AWS Lambda bundled JSON',
        value: 'aws-lambda' as const,
        storageMode: 'bundled' as const,
        description: 'API Gateway + Lambda starter with bundled sample JSON',
      },
      {
        label: 'AWS Lambda + DynamoDB',
        value: 'aws-lambda' as const,
        storageMode: 'dynamodb' as const,
        description: 'Persistent DynamoDB storage for publisher backend data',
      },
      {
        label: 'Firebase Functions + Firestore',
        value: 'firebase-functions' as const,
        storageMode: 'firestore' as const,
        description: 'Cloud Functions v2 starter with Firestore storage',
      },
    ],
    { title: 'Publisher backend template', ignoreFocusOut: true },
  );
  if (!templateChoice) {
    return;
  }
  let withStarterUi = false;
  if (templateChoice.value === 'firebase-functions') {
    const starterUi = await chooseFirebaseStarterUiForScaffold();
    if (starterUi === undefined) {
      return;
    }
    withStarterUi = starterUi;
    if (
      withStarterUi &&
      !(await ensurePublisherBackendFirebaseStarterUiCli049(workspacePath, output))
    ) {
      return;
    }
  }
  const force = await chooseForce(
    'Overwrite scaffold-managed publisher backend files?',
  );
  if (force === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend Setup',
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: workspacePath,
      template: templateChoice.value,
      storageMode: templateChoice.value === 'aws-lambda' ||
        templateChoice.value === 'firebase-functions'
        ? templateChoice.storageMode
        : undefined,
      force,
      withStarterUi,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function publisherBackendFirebaseStarterUi(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseStarterUiCli049(workspacePath, output))) {
    return;
  }
  const mode = await chooseFirebaseStarterUiMode();
  if (!mode) {
    return;
  }
  await runWorkspaceCliCommand(
    'Publisher Backend Firebase Starter UI',
    buildPublisherBackendFirebaseStarterUiArgs({
      miniProgramRoot: workspacePath,
      force: mode.force,
    }),
    output,
    refreshStatus,
  );
}

export async function publisherBackendRun(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const port = await vscode.window.showInputBox({
    prompt: 'Publisher backend local port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend Run',
    buildPublisherBackendRunArgs({
      miniProgramRoot: workspacePath,
      port: port.trim(),
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function publisherBackendStop(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend Stop',
    buildPublisherBackendStopArgs({ miniProgramRoot: workspacePath }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
  if (ok) {
    await refreshStatus(false);
  }
}

export async function publisherBackendStatus(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Status',
    buildPublisherBackendStatusArgs({
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}
