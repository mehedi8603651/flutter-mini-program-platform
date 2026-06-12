import * as vscode from 'vscode';

import {
  buildCloudDeployArgs,
  buildCloudOutputsArgs,
  buildCloudStatusArgs,
  buildEnvConfigureAwsArgs,
  buildEnvConfigureFirebaseArgs,
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
} from '../cli';

import {
  chooseRequireAccessKeys,
  promptOptionalEnvName,
  requireWorkspacePath,
  runCliCommand,
  runWorkspaceCliCommand,
  validateEnvironmentName,
  validateOptionalAbsoluteUrl,
  validateOptionalEnvironmentName,
} from '../extensionSupport';

export async function envInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const useEnvironment = await vscode.window.showInputBox({
    prompt: 'Optional active environment to save now',
    placeHolder: 'Leave blank for local',
    ignoreFocusOut: true,
  });
  if (useEnvironment === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Env Init',
    buildEnvInitArgs({
      rootPath: workspacePath,
      useEnvironment: useEnvironment.trim() || undefined,
    }),
    output,
    refreshStatus,
  );
}

export async function configureAwsEnvironment(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const environmentName = await vscode.window.showInputBox({
    prompt: 'AWS environment name',
    placeHolder: 'my-aws-prod',
    value: 'my-aws-prod',
    ignoreFocusOut: true,
    validateInput: validateEnvironmentName,
  });
  if (!environmentName) {
    return;
  }
  const bucket = await vscode.window.showInputBox({
    prompt: 'AWS S3 bucket for mini-program artifacts',
    placeHolder: 'my-mini-program-prod-ap-south-1-001',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Bucket is required.',
  });
  if (!bucket) {
    return;
  }
  const region = await vscode.window.showInputBox({
    prompt: 'AWS region',
    placeHolder: 'ap-south-1',
    value: 'ap-south-1',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Region is required.',
  });
  if (!region) {
    return;
  }
  const awsProfile = await vscode.window.showInputBox({
    prompt: 'Optional AWS CLI profile',
    placeHolder: 'Leave blank to use the default AWS profile',
    ignoreFocusOut: true,
  });
  if (awsProfile === undefined) {
    return;
  }
  const stackName = await vscode.window.showInputBox({
    prompt: 'Optional CloudFormation stack name',
    placeHolder: 'mini-program-cloud-prod',
    ignoreFocusOut: true,
    validateInput: validateOptionalEnvironmentName,
  });
  if (stackName === undefined) {
    return;
  }
  const stageName = await vscode.window.showInputBox({
    prompt: 'Optional API Gateway stage name',
    placeHolder: 'prod',
    value: 'prod',
    ignoreFocusOut: true,
    validateInput: validateOptionalEnvironmentName,
  });
  if (stageName === undefined) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Optional existing backend API base URL',
    placeHolder: 'Leave blank until cloud deploy creates it',
    ignoreFocusOut: true,
    validateInput: validateOptionalAbsoluteUrl,
  });
  if (apiBaseUrl === undefined) {
    return;
  }
  const requireAccessKeys = await chooseRequireAccessKeys();
  if (requireAccessKeys === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Configure AWS Environment',
    buildEnvConfigureAwsArgs({
      environmentName: environmentName.trim(),
      rootPath: workspacePath,
      bucket: bucket.trim(),
      region: region.trim(),
      awsProfile: awsProfile.trim() || undefined,
      apiBaseUrl: apiBaseUrl.trim() || undefined,
      stackName: stackName.trim() || undefined,
      stageName: stageName.trim() || undefined,
      requireAccessKeys,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    const useNow = await vscode.window.showInformationMessage(
      `Configured AWS environment ${environmentName.trim()}.`,
      'Use Environment',
    );
    if (useNow === 'Use Environment') {
      await runWorkspaceCliCommand(
        'Use Environment',
        buildEnvUseArgs({
          environmentName: environmentName.trim(),
          rootPath: workspacePath,
        }),
        output,
        refreshStatus,
      );
      return;
    }
    await refreshStatus(false);
  }
}

export async function configureFirebaseEnvironment(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const environmentName = await vscode.window.showInputBox({
    prompt: 'Firebase Hosting environment name',
    placeHolder: 'my-firebase-prod',
    value: 'my-firebase-prod',
    ignoreFocusOut: true,
    validateInput: validateEnvironmentName,
  });
  if (!environmentName) {
    return;
  }
  const projectId = await vscode.window.showInputBox({
    prompt: 'Firebase project ID',
    placeHolder: 'my-firebase-project',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Firebase project ID is required.',
  });
  if (!projectId) {
    return;
  }

  const ok = await runCliCommand(
    'Configure Firebase Environment',
    buildEnvConfigureFirebaseArgs({
      environmentName: environmentName.trim(),
      rootPath: workspacePath,
      projectId: projectId.trim(),
    }),
    workspacePath,
    output,
  );
  if (ok) {
    const useNow = await vscode.window.showInformationMessage(
      `Configured Firebase environment ${environmentName.trim()}.`,
      'Use Environment',
    );
    if (useNow === 'Use Environment') {
      await runWorkspaceCliCommand(
        'Use Environment',
        buildEnvUseArgs({
          environmentName: environmentName.trim(),
          rootPath: workspacePath,
        }),
        output,
        refreshStatus,
      );
      return;
    }
    await refreshStatus(false);
  }
}

export async function useEnvironment(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const environmentName = await vscode.window.showInputBox({
    prompt: 'Environment to use',
    placeHolder: 'local or my-aws-prod',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Environment is required.',
  });
  if (!environmentName) {
    return;
  }

  await runWorkspaceCliCommand(
    'Use Environment',
    buildEnvUseArgs({
      environmentName: environmentName.trim(),
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

export async function cloudDeploy(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const ok = await runCliCommand(
    'Cloud Deploy',
    buildCloudDeployArgs({
      envName,
      rootPath: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

export async function cloudStatus(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  await runCliCommand(
    'Cloud Status',
    buildCloudStatusArgs({
      envName,
      rootPath: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function cloudOutputs(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const format = await vscode.window.showQuickPick(
    [
      { label: 'text', description: 'Human-readable cloud outputs' },
      {
        label: 'dart-define',
        description: 'Flutter --dart-define snippet for release builds',
      },
    ],
    { title: 'Cloud outputs format', ignoreFocusOut: true },
  );
  if (!format) {
    return;
  }
  await runCliCommand(
    'Cloud Outputs',
    buildCloudOutputsArgs({
      envName,
      rootPath: workspacePath,
      format: format.label as 'text' | 'dart-define',
    }),
    workspacePath,
    output,
  );
}
