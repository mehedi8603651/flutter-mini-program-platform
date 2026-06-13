import * as vscode from 'vscode';

import {
  buildBackendInitArgs,
  buildBackendStartArgs,
  buildBackendStatusArgs,
  buildBackendStopArgs,
  buildPublisherBackendRunArgs,
  buildPublisherBackendScaffoldArgs,
  buildPublisherBackendStatusArgs,
  buildPublisherBackendStopArgs,
} from '../cli';

import {
  chooseBackendRoot,
  chooseForce,
  requireMiniProgramRoot,
  requireWorkspacePath,
  runCliCommand,
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
  const force = await chooseForce(
    'Overwrite scaffold-managed artifact host files?',
  );
  if (force === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Artifact Host Init',
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
    prompt: 'Local artifact host port',
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
    'Artifact Host Start',
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
    'Artifact Host Stop',
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
    'Artifact Host Status',
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
        description: 'Local JSON API starter for development',
      },
    ],
    { title: 'Publisher API mock template', ignoreFocusOut: true },
  );
  if (!templateChoice) {
    return;
  }
  const force = await chooseForce(
    'Overwrite scaffold-managed Publisher API mock files?',
  );
  if (force === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Mock Publisher API Setup',
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: workspacePath,
      template: templateChoice.value,
      force,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
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
    prompt: 'Mock Publisher API local port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const ok = await runCliCommand(
    'Mock Publisher API Run',
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
    'Mock Publisher API Stop',
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
    'Mock Publisher API Status',
    buildPublisherBackendStatusArgs({
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}
