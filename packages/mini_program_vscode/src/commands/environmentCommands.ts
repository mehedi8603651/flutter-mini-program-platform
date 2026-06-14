import * as vscode from 'vscode';

import {
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
} from '../cli';

import {
  requireWorkspacePath,
  runCliCommand,
  runWorkspaceCliCommand,
} from '../extensionSupport';

export async function envInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  await runWorkspaceCliCommand(
    'Env Init',
    buildEnvInitArgs({
      rootPath: workspacePath,
      useEnvironment: 'local',
    }),
    output,
    refreshStatus,
  );
}

export async function useEnvironment(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  await runWorkspaceCliCommand(
    'Use Local Environment',
    buildEnvUseArgs({
      environmentName: 'local',
      rootPath: workspacePath,
    }),
    output,
    refreshStatus,
  );
}

export async function environmentStatus(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  await runCliCommand(
    'Environment Status',
    buildEnvStatusArgs({ rootPath: workspacePath, json: true }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}
