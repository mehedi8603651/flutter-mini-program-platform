import * as path from 'path';
import * as fs from 'fs';
import * as vscode from 'vscode';

import {
  buildAccessKeyCreateArgs,
  buildAccessKeyListArgs,
  buildAccessKeyRevokeArgs,
  buildAccessKeyRotateArgs,
  buildBackendInitArgs,
  buildBackendStartArgs,
  buildBackendStatusArgs,
  buildBackendStopArgs,
  buildBuildArgs,
  buildCloudAppInfoArgs,
  buildCloudDeployArgs,
  buildCloudOutputsArgs,
  buildCloudStatusArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedCloudConfigureArgs,
  buildEmbedInitArgs,
  buildEnvConfigureAwsArgs,
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
  buildPreviewArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  formatCommandLine,
  formatRedactedCommandLine,
  resolveCliPath,
  runCli,
  runCliStreaming,
} from './cli';
import {
  DiagnosticScope,
  buildDiagnosticsReport,
  formatDiagnosticsReport,
  redactSecrets,
} from './diagnostics';
import {
  GuidedWorkflowId,
  formatGuidedWorkflowPlan,
  guidedWorkflowById,
} from './guidedWorkflows';
import {
  MiniProgramRegistryEntry,
  buildDemoHostButtonSnippet,
  buildCleanupCommandTemplate,
  buildHostCommandTemplate,
  buildPublisherCommandTemplate,
  buildRegistryFile,
  dartFieldNameFromAppId,
  parseEndpointAppIds,
  parseRegistryEntries,
  titleFromAppId as hostTitleFromAppId,
  upsertRegistryEntry,
} from './hostIntegration';
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
    output.appendLine(`> ${formatRedactedCommandLine(cliPath, args)}`);
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
      runMiniProgramWorkspaceCliCommand(
        'Build',
        (workspacePath) => buildBuildArgs({ miniProgramRoot: workspacePath }),
        output,
        refreshStatus,
      ),
    ),
    vscode.commands.registerCommand('miniProgramTools.validate', () =>
      runMiniProgramWorkspaceCliCommand(
        'Validate',
        (workspacePath) => buildValidateArgs({ miniProgramRoot: workspacePath }),
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
    vscode.commands.registerCommand('miniProgramTools.publishPublicStaticMiniProgram', () =>
      publishPublicStaticMiniProgram(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.embedInit', () =>
      embedInit(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.configureHostCloud', () =>
      configureHostCloud(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.importHostEndpoint', () =>
      importHostEndpoint(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.addHostEndpoint', () =>
      addHostEndpoint(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.runHostApp', () =>
      runHostApp(),
    ),
    vscode.commands.registerCommand('miniProgramTools.envInit', () =>
      envInit(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.configureAwsEnvironment', () =>
      configureAwsEnvironment(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.useEnvironment', () =>
      useEnvironment(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.environmentStatus', () =>
      environmentStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.cloudDeploy', () =>
      cloudDeploy(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.cloudStatus', () =>
      cloudStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.cloudOutputs', () =>
      cloudOutputs(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.backendInit', () =>
      backendInit(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.backendStart', () =>
      backendStart(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.backendStop', () =>
      backendStop(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.backendStatus', () =>
      backendStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.createAccessKey', () =>
      createAccessKey(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.listAccessKeys', () =>
      listAccessKeys(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.revokeAccessKey', () =>
      revokeAccessKey(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.rotateAccessKey', () =>
      rotateAccessKey(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.createPartnerPackage', () =>
      createPartnerPackage(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.validatePartnerPackage', () =>
      validatePartnerPackage(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.openPartnerPackage', () =>
      openPartnerPackage(),
    ),
    vscode.commands.registerCommand('miniProgramTools.diagnoseWorkspace', () =>
      diagnoseWorkspace('workspace', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.diagnoseMiniProgram', () =>
      diagnoseWorkspace('miniProgram', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.diagnoseHostApp', () =>
      diagnoseWorkspace('hostApp', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.diagnoseCloudDelivery', () =>
      diagnoseWorkspace('cloudDelivery', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.setupNewMiniProgram', () =>
      runGuidedWorkflow('setupNewMiniProgram', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publishMiniProgramToAws', () =>
      runGuidedWorkflow('publishMiniProgramToAws', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.preparePartnerHandoff', () =>
      runGuidedWorkflow('preparePartnerHandoff', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.setupHostApp', () =>
      runGuidedWorkflow('setupHostApp', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.addMiniProgramToHost', () =>
      runGuidedWorkflow('addMiniProgramToHost', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.runHostSmokeTest', () =>
      runGuidedWorkflow('runHostSmokeTest', output),
    ),
    vscode.commands.registerCommand('miniProgramTools.generateMiniProgramRegistry', () =>
      generateMiniProgramRegistry(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.addMiniProgramToRegistry', () =>
      addMiniProgramToRegistry(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyDemoHostButton', () =>
      copyDemoHostButton(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.insertDemoHostButton', () =>
      copyDemoHostButton(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyWorkflowCommands', () =>
      copyWorkflowCommands(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.checkHostEndpointRemote', () =>
      checkHostEndpointRemote(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyCleanupCommands', () =>
      copyCleanupCommands(output),
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

  const outputRoot = resolveCreateOutputRoot(parentFolder, appId);
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

async function publishPublicStaticMiniProgram(
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

async function embedInit(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const force = await chooseForce('Overwrite scaffold-managed host adapter files?');
  if (force === undefined) {
    return;
  }
  const withDemo = await chooseWithDemo();
  if (withDemo === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Embed Init',
    buildEmbedInitArgs({ projectRoot, force, withDemo }),
    output,
    refreshStatus,
  );
}

async function configureHostCloud(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const envName = await vscode.window.showInputBox({
    prompt: 'Optional cloud environment name',
    placeHolder: 'Leave blank to use active environment',
    ignoreFocusOut: true,
  });
  if (envName === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Configure Host Cloud',
    buildEmbedCloudConfigureArgs({
      projectRoot,
      envName: envName.trim() || undefined,
    }),
    output,
    refreshStatus,
  );
}

async function importHostEndpoint(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const selectedFiles = await vscode.window.showOpenDialog({
    canSelectFiles: true,
    canSelectFolders: false,
    canSelectMany: false,
    filters: {
      'Partner package JSON': ['json'],
    },
    openLabel: 'Import partner package',
    title: 'Choose a MiniProgram partner package',
  });
  const partnerPackagePath = selectedFiles?.[0]?.fsPath;
  if (!partnerPackagePath) {
    return;
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Import Host Endpoint',
    buildHostEndpointImportArgs({ partnerPackagePath, projectRoot, force }),
    output,
    refreshStatus,
  );
}

async function addHostEndpoint(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://example.com/prod/api',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
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
      return;
    }
    accessKey = value.trim();
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Add Host Endpoint',
    buildHostEndpointAddArgs({
      appId: appId.trim(),
      apiBaseUrl: apiBaseUrl.trim(),
      accessKey,
      public: accessMode === 'public',
      projectRoot,
      force,
    }),
    output,
    refreshStatus,
  );
}

async function runHostApp(): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const defaultDevice = configuredDefaultPreviewDevice();
  const deviceId = await vscode.window.showInputBox({
    prompt: 'Flutter device ID',
    value: defaultDevice,
    placeHolder: 'emulator-5554',
    ignoreFocusOut: true,
  });
  if (!deviceId) {
    return;
  }
  const envName = await vscode.window.showInputBox({
    prompt: 'Optional cloud environment name',
    placeHolder: 'Leave blank to use active/host environment',
    ignoreFocusOut: true,
  });
  if (envName === undefined) {
    return;
  }

  const cliPath = configuredCliPath();
  const args = buildHostRunArgs({
    deviceId: deviceId.trim(),
    projectRoot,
    envName: envName.trim() || undefined,
  });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Host',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
}

async function envInit(
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

async function configureAwsEnvironment(
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

async function useEnvironment(
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

async function environmentStatus(output: vscode.OutputChannel): Promise<void> {
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

async function cloudDeploy(
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

async function cloudStatus(output: vscode.OutputChannel): Promise<void> {
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

async function cloudOutputs(output: vscode.OutputChannel): Promise<void> {
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

async function backendInit(
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

async function backendStart(
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

async function backendStop(
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

async function backendStatus(output: vscode.OutputChannel): Promise<void> {
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

async function createAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id', 'host-a');
  if (!keyId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'Create Access Key',
    buildAccessKeyCreateArgs({ appId, keyId, envName }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
    vscode.window.showInformationMessage(
      'Access key created. Copy the generated key from the MiniProgram output channel.',
    );
  }
}

async function listAccessKeys(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }

  const ok = await runCliCommand(
    'List Access Keys',
    buildAccessKeyListArgs({ appId, envName, json: true }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

async function revokeAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id to revoke', 'host-a');
  if (!keyId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Revoke access key "${keyId}" for "${appId}"?`,
    { modal: true },
    'Revoke',
  );
  if (confirmed !== 'Revoke') {
    return;
  }

  const ok = await runCliCommand(
    'Revoke Access Key',
    buildAccessKeyRevokeArgs({ appId, keyId, envName }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

async function rotateAccessKey(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const keyId = await promptKeyId('Access key id to rotate', 'host-a');
  if (!keyId) {
    return;
  }
  const newKeyId = await vscode.window.showInputBox({
    prompt: 'Optional new access key id',
    placeHolder: `${keyId}-next`,
    ignoreFocusOut: true,
  });
  if (newKeyId === undefined) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const confirmed = await vscode.window.showWarningMessage(
    `Rotate access key "${keyId}" for "${appId}"? The old key will be revoked.`,
    { modal: true },
    'Rotate',
  );
  if (confirmed !== 'Rotate') {
    return;
  }

  const ok = await runCliCommand(
    'Rotate Access Key',
    buildAccessKeyRotateArgs({
      appId,
      keyId,
      newKeyId: newKeyId.trim() || undefined,
      envName,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
    vscode.window.showInformationMessage(
      'Access key rotated. Copy the new generated key from the MiniProgram output channel.',
    );
  }
}

async function createPartnerPackage(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title for host developers',
    value: titleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }
  const accessMode = await chooseEndpointAccessMode();
  if (!accessMode) {
    return;
  }
  let accessKey: string | undefined;
  if (accessMode === 'protected') {
    const value = await vscode.window.showInputBox({
      prompt: 'MiniProgram access key for this host/partner',
      password: true,
      placeHolder: 'mpk_live_...',
      ignoreFocusOut: true,
      validateInput: (input) =>
        input.trim() ? undefined : 'Access key is required.',
    });
    if (!value) {
      return;
    }
    accessKey = value.trim();
  }
  const deliverySource = await vscode.window.showQuickPick(
    [
      {
        label: 'Configured environment',
        description: 'Use active or selected env to resolve API base URL',
        value: 'env',
      },
      {
        label: 'Direct API base URL',
        description: 'Paste the backend API URL manually',
        value: 'api',
      },
    ],
    { title: 'Partner package delivery source', ignoreFocusOut: true },
  );
  if (!deliverySource) {
    return;
  }

  let envName: string | undefined;
  let apiBaseUrl: string | undefined;
  if (deliverySource.value === 'env') {
    const value = await promptOptionalEnvName();
    if (value === undefined) {
      return;
    }
    envName = value;
  } else {
    const value = await vscode.window.showInputBox({
      prompt: 'Mini-program delivery API base URL',
      placeHolder: 'https://example.com/prod/api',
      ignoreFocusOut: true,
      validateInput: validateAbsoluteUrl,
    });
    if (!value) {
      return;
    }
    apiBaseUrl = value.trim();
  }

  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return;
  }

  const ok = await runCliCommand(
    'Create Partner Package',
    buildPartnerPackageArgs({
      appId,
      title: title.trim() || undefined,
      accessKey,
      public: accessMode === 'public',
      envName,
      apiBaseUrl,
      outputPath,
      rootPath: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (!ok) {
    return;
  }
  await refreshStatus(false);
  const packageMessage = accessMode === 'public'
    ? `Created public partner package for ${appId}.`
    : `Created partner package for ${appId}. Treat this file as secret.`;
  const openChoice = await vscode.window.showInformationMessage(
    packageMessage,
    'Open File',
    'Reveal Folder',
  );
  if (openChoice === 'Open File') {
    const document = await vscode.workspace.openTextDocument(outputPath);
    await vscode.window.showTextDocument(document);
  } else if (openChoice === 'Reveal Folder') {
    await vscode.commands.executeCommand(
      'revealFileInOS',
      vscode.Uri.file(outputPath),
    );
  }
}

async function validatePartnerPackage(output: vscode.OutputChannel): Promise<void> {
  const packagePath = await choosePartnerPackageFile();
  if (!packagePath) {
    return;
  }
  await validatePartnerPackageFile(packagePath, output);
}

async function validatePartnerPackageFile(
  packagePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  try {
    const decoded = JSON.parse(await fs.promises.readFile(packagePath, 'utf8'));
    const errors = validatePartnerPackageJson(decoded);
    output.show(true);
    output.appendLine('');
    output.appendLine(`Validated partner package: ${packagePath}`);
    if (errors.length > 0) {
      for (const error of errors) {
        output.appendLine(`- ${error}`);
      }
      vscode.window.showErrorMessage(
        `Partner package is invalid. See MiniProgram output.`,
      );
      return false;
    }
    output.appendLine(`App ID: ${decoded.appId}`);
    output.appendLine(`Title: ${decoded.title ?? ''}`);
    output.appendLine(`API base URL: ${decoded.apiBaseUrl}`);
    output.appendLine(`Access mode: ${decoded.accessMode ?? 'protected'}`);
    output.appendLine(`Access key: ${decoded.accessKey ? '<redacted>' : 'not required'}`);
    vscode.window.showInformationMessage('Partner package looks valid.');
    return true;
  } catch (error) {
    const message = `Failed to validate partner package: ${errorMessage(error)}`;
    output.show(true);
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
    return false;
  }
}

async function openPartnerPackage(): Promise<void> {
  const packagePath = await choosePartnerPackageFile();
  if (!packagePath) {
    return;
  }
  const choice = await vscode.window.showQuickPick(
    [
      { label: 'Open File', value: 'open' },
      { label: 'Reveal Folder', value: 'reveal' },
    ],
    { title: 'Open partner package', ignoreFocusOut: true },
  );
  if (!choice) {
    return;
  }
  if (choice.value === 'open') {
    const document = await vscode.workspace.openTextDocument(packagePath);
    await vscode.window.showTextDocument(document);
  } else {
    await vscode.commands.executeCommand(
      'revealFileInOS',
      vscode.Uri.file(packagePath),
    );
  }
}

async function diagnoseWorkspace(
  scope: DiagnosticScope,
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }

  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`== ${diagnosticCommandTitle(scope)} ==`);

  let workflowReport;
  const workflowArgs = buildWorkflowStatusArgs({ workspacePath });
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, workflowArgs)}`);
  try {
    const result = await runCli(cliPath, workflowArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    if (result.stderr.trim()) {
      output.append(redactSecrets(result.stderr));
    }
    workflowReport = parseWorkflowStatusJson(result.stdout);
  } catch (error) {
    output.appendLine(`Workflow status failed: ${errorMessage(error)}`);
  }

  let doctorReport: Record<string, unknown> | undefined;
  const doctorArgs = buildDoctorArgs({ json: true });
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, doctorArgs)}`);
  try {
    const result = await runCli(cliPath, doctorArgs, {
      cwd: workspacePath,
      timeoutMs: 60000,
    });
    if (result.stderr.trim()) {
      output.append(redactSecrets(result.stderr));
    }
    doctorReport = parseJsonObject(result.stdout);
  } catch (error) {
    output.appendLine(`Doctor failed: ${errorMessage(error)}`);
  }

  let remoteWorkflowReport;
  if (scope === 'cloudDelivery') {
    const remoteArgs = buildWorkflowStatusArgs({ workspacePath, remote: true });
    output.appendLine(`> ${formatRedactedCommandLine(cliPath, remoteArgs)}`);
    try {
      const result = await runCli(cliPath, remoteArgs, {
        cwd: workspacePath,
        timeoutMs: 120000,
      });
      if (result.stderr.trim()) {
        output.append(redactSecrets(result.stderr));
      }
      remoteWorkflowReport = parseWorkflowStatusJson(result.stdout);
    } catch (error) {
      output.appendLine(`Remote workflow status failed: ${errorMessage(error)}`);
    }
  }

  const report = await buildDiagnosticsReport({
    workspacePath,
    scope,
    workflowReport,
    remoteWorkflowReport,
    doctorReport,
  });
  output.appendLine('');
  output.appendLine(formatDiagnosticsReport(report));
  if (report.summary.error > 0) {
    vscode.window.showErrorMessage('Diagnostics found errors.');
  } else if (report.summary.warning > 0) {
    vscode.window.showWarningMessage('Diagnostics found warnings.');
  } else {
    vscode.window.showInformationMessage('Diagnostics passed.');
  }
}

async function runGuidedWorkflow(
  workflowId: GuidedWorkflowId,
  output: vscode.OutputChannel,
): Promise<void> {
  const workflow = guidedWorkflowById(workflowId);
  output.show(true);
  output.appendLine('');
  output.appendLine(`== Guided workflow: ${workflow.title} ==`);
  output.appendLine(formatGuidedWorkflowPlan(workflow));
  output.appendLine('');

  try {
    let completed = false;
    switch (workflowId) {
      case 'setupNewMiniProgram':
        completed = await guidedSetupNewMiniProgram(output);
        break;
      case 'publishMiniProgramToAws':
        completed = await guidedPublishMiniProgramToAws(output);
        break;
      case 'preparePartnerHandoff':
        completed = await guidedPreparePartnerHandoff(output);
        break;
      case 'setupHostApp':
        completed = await guidedSetupHostApp(output);
        break;
      case 'addMiniProgramToHost':
        completed = await guidedAddMiniProgramToHost(output);
        break;
      case 'runHostSmokeTest':
        completed = await guidedRunHostSmokeTest(output);
        break;
    }
    if (completed) {
      vscode.window.showInformationMessage(`${workflow.title} completed.`);
    }
  } catch (error) {
    const message = `${workflow.title} failed: ${errorMessage(error)}`;
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
  }
}

async function guidedSetupNewMiniProgram(
  output: vscode.OutputChannel,
): Promise<boolean> {
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    openLabel: 'Select parent folder',
    title: 'Choose where to create the mini-program',
  });
  const parentFolder = folders?.[0]?.fsPath;
  if (!parentFolder) {
    return false;
  }
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_demo',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return false;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title',
    placeHolder: titleFromAppId(appId),
    value: titleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return false;
  }

  const outputRoot = resolveCreateOutputRoot(parentFolder, appId.trim());
  if (!(await runGuidedCliStep(
    'Create MiniProgram',
    buildCreateArgs({
      appId: appId.trim(),
      title: title.trim() || undefined,
      outputRoot,
    }),
    parentFolder,
    output,
  ))) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Build',
    buildBuildArgs({ miniProgramRoot: outputRoot }),
    outputRoot,
    output,
  ))) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Validate',
    buildValidateArgs({ miniProgramRoot: outputRoot }),
    outputRoot,
    output,
  ))) {
    return false;
  }

  const openChoice = await vscode.window.showInformationMessage(
    `Created and validated ${appId.trim()}.`,
    'Open Folder',
  );
  if (openChoice === 'Open Folder') {
    await vscode.commands.executeCommand(
      'vscode.openFolder',
      vscode.Uri.file(outputRoot),
      false,
    );
  }
  return true;
}

async function guidedPublishMiniProgramToAws(
  output: vscode.OutputChannel,
): Promise<boolean> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return false;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return false;
  }
  if (!(await runGuidedMiniProgramBuildValidatePublish(workspacePath, envName, output))) {
    return false;
  }
  await diagnoseWorkspace('cloudDelivery', output);
  return true;
}

async function guidedPreparePartnerHandoff(
  output: vscode.OutputChannel,
): Promise<boolean> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return false;
  }
  const appId = await promptAppId();
  if (!appId) {
    return false;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title for host developers',
    value: titleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return false;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return false;
  }
  const keyId = await promptKeyId('Access key id for this host/partner', 'host-a');
  if (!keyId) {
    return false;
  }
  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return false;
  }

  if (!(await runGuidedMiniProgramBuildValidatePublish(workspacePath, envName, output))) {
    return false;
  }
  const accessKeyResult = await runGuidedCliStepCapture(
    'Create Access Key',
    buildAccessKeyCreateArgs({ appId, keyId, envName }),
    workspacePath,
    output,
  );
  if (!accessKeyResult) {
    return false;
  }
  const accessKey = extractAccessKey(accessKeyResult.stdout);
  if (!accessKey) {
    vscode.window.showErrorMessage(
      'Access key was created, but the generated key could not be read from CLI output.',
    );
    return false;
  }
  if (!(await runGuidedCliStep(
    'Create Partner Package',
    buildPartnerPackageArgs({
      appId,
      title: title.trim() || undefined,
      accessKey,
      envName,
      outputPath,
      rootPath: workspacePath,
    }),
    workspacePath,
    output,
  ))) {
    return false;
  }
  return validatePartnerPackageFile(outputPath, output);
}

async function guidedSetupHostApp(output: vscode.OutputChannel): Promise<boolean> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return false;
  }
  const force = await chooseForce('Overwrite scaffold-managed host adapter files?');
  if (force === undefined) {
    return false;
  }
  const withDemo = await chooseWithDemo();
  if (withDemo === undefined) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Embed Init',
    buildEmbedInitArgs({ projectRoot, force, withDemo }),
    projectRoot,
    output,
  ))) {
    return false;
  }

  const configureCloud = await vscode.window.showQuickPick(
    [
      {
        label: 'Configure host cloud',
        description: 'Resolve backend API URL from active or selected env',
        value: true,
      },
      {
        label: 'Skip cloud configuration',
        description: 'Use endpoint maps only for now',
        value: false,
      },
    ],
    { title: 'Host cloud configuration', ignoreFocusOut: true },
  );
  if (!configureCloud) {
    return false;
  }
  if (configureCloud.value) {
    const envName = await promptOptionalEnvName();
    if (envName === undefined) {
      return false;
    }
    if (!(await runGuidedCliStep(
      'Configure Host Cloud',
      buildEmbedCloudConfigureArgs({
        projectRoot,
        envName: envName.trim() || undefined,
      }),
      projectRoot,
      output,
    ))) {
      return false;
    }
  }

  await diagnoseWorkspace('hostApp', output);
  return true;
}

async function guidedAddMiniProgramToHost(
  output: vscode.OutputChannel,
): Promise<boolean> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return false;
  }
  const mode = await vscode.window.showQuickPick(
    [
      {
        label: 'Import partner package',
        description: 'Recommended: use a .partner.json handoff file',
        value: 'import',
      },
      {
        label: 'Add endpoint manually',
        description: 'Enter appId, API base URL, and access key',
        value: 'manual',
      },
    ],
    { title: 'Add mini-program endpoint', ignoreFocusOut: true },
  );
  if (!mode) {
    return false;
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return false;
  }
  if (mode.value === 'import') {
    const partnerPackagePath = await choosePartnerPackageFile();
    if (!partnerPackagePath) {
      return false;
    }
    if (!(await runGuidedCliStep(
      'Import Host Endpoint',
      buildHostEndpointImportArgs({ partnerPackagePath, projectRoot, force }),
      projectRoot,
      output,
    ))) {
      return false;
    }
  } else {
    const endpoint = await promptHostEndpointInputs();
    if (!endpoint) {
      return false;
    }
    if (!(await runGuidedCliStep(
      'Add Host Endpoint',
      buildHostEndpointAddArgs({ ...endpoint, projectRoot, force }),
      projectRoot,
      output,
    ))) {
      return false;
    }
  }
  await diagnoseWorkspace('hostApp', output);
  return true;
}

async function guidedRunHostSmokeTest(output: vscode.OutputChannel): Promise<boolean> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return false;
  }
  await diagnoseWorkspace('hostApp', output);
  const defaultDevice = configuredDefaultPreviewDevice();
  const deviceId = await vscode.window.showInputBox({
    prompt: 'Flutter device ID',
    value: defaultDevice,
    placeHolder: 'emulator-5554',
    ignoreFocusOut: true,
  });
  if (!deviceId) {
    return false;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return false;
  }
  const cliPath = configuredCliPath();
  const args = buildHostRunArgs({
    deviceId: deviceId.trim(),
    projectRoot,
    envName: envName.trim() || undefined,
  });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Host Smoke Test',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
  return true;
}

async function generateMiniProgramRegistry(
  output: vscode.OutputChannel,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appIds = await readHostEndpointAppIds(projectRoot);
  if (appIds.length === 0) {
    vscode.window.showWarningMessage(
      'No host endpoints found. Import or add an endpoint first.',
    );
    return;
  }

  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const entries = appIds.map((appId) => ({
    appId,
    title: hostTitleFromAppId(appId),
  }));
  const source = entries.reduce(
    (current, entry) => upsertRegistryEntry(current, entry),
    existingSource || buildRegistryFile(),
  );

  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
  output.show(true);
  output.appendLine('');
  output.appendLine(`Generated MiniProgram registry: ${registryPath}`);
  output.appendLine(`Entries: ${entries.map((entry) => entry.appId).join(', ')}`);
  vscode.window.showInformationMessage('MiniProgram registry generated.');
}

async function addMiniProgramToRegistry(
  output: vscode.OutputChannel,
): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const endpointAppIds = await readHostEndpointAppIds(projectRoot);
  const appId = await chooseAppIdForRegistry(endpointAppIds);
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program title',
    value: hostTitleFromAppId(appId),
    ignoreFocusOut: true,
  });
  if (title === undefined) {
    return;
  }

  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const source = upsertRegistryEntry(existingSource, {
    appId,
    title: title.trim() || hostTitleFromAppId(appId),
  });
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
  output.show(true);
  output.appendLine('');
  output.appendLine(`Updated MiniProgram registry: ${registryPath}`);
  output.appendLine(`Added/updated: ${appId}`);
  vscode.window.showInformationMessage(`MiniProgram registry updated for ${appId}.`);
}

async function copyDemoHostButton(output: vscode.OutputChannel): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const entry = await chooseHostMiniProgramEntry(projectRoot);
  if (!entry) {
    return;
  }
  const style = await vscode.window.showQuickPick(
    [
      {
        label: 'Use MiniPrograms registry',
        description: 'Recommended for host apps with many mini-programs',
        useRegistry: true,
      },
      {
        label: 'Use inline appId/title',
        description: 'Simpler for one-button demos',
        useRegistry: false,
      },
    ],
    { title: 'Demo button style', ignoreFocusOut: true },
  );
  if (!style) {
    return;
  }

  if (style.useRegistry) {
    await writeRegistryEntry(projectRoot, entry);
  }
  const buttonSnippet = buildDemoHostButtonSnippet(entry, {
    useRegistry: style.useRegistry,
  });
  const importLines = [
    'mini_program/mini_program_launcher.dart',
    ...(style.useRegistry ? ['mini_program/mini_program_registry.dart'] : []),
  ].map((importPath) => `import '${importPath}';`);
  const snippet = [
    '// Add these imports if they are not already in this Dart file:',
    ...importLines.map((line) => `// ${line}`),
    '',
    buttonSnippet,
  ].join('\n');
  await vscode.env.clipboard.writeText(snippet);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied demo host button snippet:');
  output.appendLine(snippet);
  vscode.window.showInformationMessage(
    'Demo host button copied. Paste it into your host-owned UI.',
  );
}

async function copyWorkflowCommands(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const inferredMode = fs.existsSync(path.join(workspacePath, 'manifest.json'))
    ? 'publisher'
    : fs.existsSync(path.join(workspacePath, 'pubspec.yaml'))
      ? 'host'
      : undefined;
  const mode = inferredMode
    ? { value: inferredMode }
    : await vscode.window.showQuickPick(
        [
          { label: 'Publisher mini-program commands', value: 'publisher' },
          { label: 'Host app commands', value: 'host' },
        ],
        { title: 'Workflow command template', ignoreFocusOut: true },
      );
  if (!mode) {
    return;
  }

  let commands: string;
  if (mode.value === 'publisher') {
    const manifest = await readWorkspaceManifest(workspacePath);
    commands = buildPublisherCommandTemplate({
      appId: manifest?.id,
      title: manifest?.title || (manifest?.id ? hostTitleFromAppId(manifest.id) : undefined),
      envName: 'my-aws-prod',
    });
  } else {
    commands = buildHostCommandTemplate({
      projectRoot: workspacePath,
      deviceId: configuredDefaultPreviewDevice(),
    });
  }

  await vscode.env.clipboard.writeText(commands);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied workflow commands:');
  output.appendLine(commands);
  vscode.window.showInformationMessage('MiniProgram workflow commands copied.');
}

async function checkHostEndpointRemote(output: vscode.OutputChannel): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appId = await chooseHostEndpointAppId(projectRoot);
  if (!appId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }

  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`== MiniProgram: Check Host Endpoint Remote ==`);
  output.appendLine(`Endpoint appId: ${appId}`);

  const steps = [
    {
      label: 'Cloud Status',
      args: buildCloudStatusArgs({
        envName,
        rootPath: projectRoot,
        json: true,
      }),
      allowNonZeroExit: true,
    },
    {
      label: 'Cloud App Info',
      args: buildCloudAppInfoArgs({
        appId,
        envName,
        rootPath: projectRoot,
      }),
      allowNonZeroExit: true,
    },
    {
      label: 'Access Key List',
      args: buildAccessKeyListArgs({
        appId,
        envName,
        json: true,
      }),
      allowNonZeroExit: true,
    },
  ];

  let failed = false;
  for (const step of steps) {
    output.appendLine('');
    output.appendLine(`-- ${step.label}`);
    output.appendLine(`> ${formatRedactedCommandLine(cliPath, step.args)}`);
    try {
      const result = await runCli(cliPath, step.args, {
        cwd: projectRoot,
        timeoutMs: 120000,
      });
      if (result.stdout.trim()) {
        output.appendLine(redactSecrets(result.stdout.trim()));
      }
      if (result.stderr.trim()) {
        output.appendLine(redactSecrets(result.stderr.trim()));
      }
      if (result.exitCode !== 0) {
        failed = true;
        output.appendLine(`${step.label} exited with code ${result.exitCode}.`);
      }
    } catch (error) {
      failed = true;
      output.appendLine(`${step.label} failed: ${errorMessage(error)}`);
    }
  }

  if (failed) {
    vscode.window.showWarningMessage(
      `Remote endpoint check completed with warnings for ${appId}.`,
    );
  } else {
    vscode.window.showInformationMessage(
      `Remote endpoint check completed for ${appId}.`,
    );
  }
}

async function copyCleanupCommands(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
    return;
  }
  const appId = fs.existsSync(path.join(workspacePath, 'pubspec.yaml'))
    ? await chooseHostEndpointAppId(workspacePath)
    : await promptAppId();
  if (!appId) {
    return;
  }
  const envName = await promptOptionalEnvName();
  if (envName === undefined) {
    return;
  }
  const keyId = await vscode.window.showInputBox({
    prompt: 'Optional access key id to revoke',
    placeHolder: 'Leave blank to keep <KEY_ID> placeholder',
    ignoreFocusOut: true,
  });
  if (keyId === undefined) {
    return;
  }
  const includeWorkspaceDelete = await vscode.window.showQuickPick(
    [
      {
        label: 'Include local workspace delete',
        description: 'Adds Remove-Item for the current workspace',
        value: true,
      },
      {
        label: 'Do not include local workspace delete',
        description: 'Only copy cloud/access-key cleanup commands',
        value: false,
      },
    ],
    { title: 'Cleanup command scope', ignoreFocusOut: true },
  );
  if (!includeWorkspaceDelete) {
    return;
  }

  const commands = buildCleanupCommandTemplate({
    appId,
    envName,
    keyId: keyId.trim() || undefined,
    workspacePath: includeWorkspaceDelete.value ? workspacePath : undefined,
  });
  await vscode.env.clipboard.writeText(commands);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied cleanup commands:');
  output.appendLine(commands);
  vscode.window.showInformationMessage('MiniProgram cleanup commands copied.');
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

async function runMiniProgramWorkspaceCliCommand(
  label: string,
  buildArgs: (workspacePath: string) => readonly string[],
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage('Open a mini-program workspace first.');
    return;
  }
  if (!fs.existsSync(path.join(workspacePath, 'manifest.json'))) {
    vscode.window.showWarningMessage(
      'Open the exact mini-program root folder that contains manifest.json.',
    );
    return;
  }

  const ok = await runCliCommand(label, buildArgs(workspacePath), workspacePath, output);
  if (ok) {
    await refreshStatus(false);
  }
}

async function runGuidedMiniProgramBuildValidatePublish(
  workspacePath: string,
  envName: string | undefined,
  output: vscode.OutputChannel,
): Promise<boolean> {
  if (!(await runGuidedCliStep(
    'Build',
    buildBuildArgs({ miniProgramRoot: workspacePath }),
    workspacePath,
    output,
  ))) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Validate',
    buildValidateArgs({ miniProgramRoot: workspacePath }),
    workspacePath,
    output,
  ))) {
    return false;
  }
  return runGuidedCliStep(
    'Publish',
    buildPublishArgs({
      target: 'cloud',
      envName: envName?.trim() || undefined,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
}

async function runGuidedCliStep(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.appendLine(`-- Step: ${label}`);
  return runCliCommand(label, args, cwd, output, {
    showSuccessNotification: false,
  });
}

async function runGuidedCliStepCapture(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
): Promise<{ readonly stdout: string; readonly stderr: string } | undefined> {
  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine(`-- Step: ${label}`);
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, args)}`);
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
      return undefined;
    }
    return { stdout: result.stdout, stderr: result.stderr };
  } catch (error) {
    const message = errorMessage(error);
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
    return undefined;
  }
}

async function runCliCommand(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
  options: {
    readonly allowNonZeroExit?: boolean;
    readonly showSuccessNotification?: boolean;
  } = {},
): Promise<boolean> {
  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, args)}`);
  try {
    const result = await runCliStreaming(cliPath, args, {
      cwd,
      timeoutMs: 600000,
      onStdout: (chunk) => output.append(chunk),
      onStderr: (chunk) => output.append(chunk),
    });
    if (result.exitCode !== 0) {
      if (options.allowNonZeroExit) {
        vscode.window.showWarningMessage(
          `${label} completed with exit code ${result.exitCode}. Check MiniProgram output.`,
        );
        return true;
      }
      vscode.window.showErrorMessage(
        `${label} failed with exit code ${result.exitCode}.`,
      );
      return false;
    }
    if (options.showSuccessNotification ?? true) {
      vscode.window.showInformationMessage(`${label} completed.`);
    }
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

async function requireHostProjectRoot(): Promise<string | undefined> {
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

async function requireMiniProgramRoot(): Promise<string | undefined> {
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

async function requireWorkspacePath(): Promise<string | undefined> {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) {
    vscode.window.showWarningMessage(
      'Open a mini-program or Flutter host app folder first.',
    );
    return undefined;
  }
  return workspacePath;
}

async function promptAppId(): Promise<string | undefined> {
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

async function promptKeyId(
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

async function promptHostEndpointInputs(): Promise<
  | {
      readonly appId: string;
      readonly apiBaseUrl: string;
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
  return {
    appId: appId.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
    accessKey,
    public: accessMode === 'public',
  };
}

async function chooseAppIdForRegistry(
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

async function chooseHostEndpointAppId(
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

async function chooseHostMiniProgramEntry(
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

async function writeRegistryEntry(
  projectRoot: string,
  entry: MiniProgramRegistryEntry,
): Promise<void> {
  const registryPath = hostRegistryPath(projectRoot);
  const existingSource = await readOptionalText(registryPath);
  const source = upsertRegistryEntry(existingSource, entry);
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.promises.writeFile(registryPath, source, 'utf8');
}

async function readHostEndpointAppIds(projectRoot: string): Promise<string[]> {
  const endpointPath = path.join(
    projectRoot,
    'lib',
    'mini_program',
    'mini_program_endpoints.dart',
  );
  const source = await readOptionalText(endpointPath);
  return source ? parseEndpointAppIds(source) : [];
}

async function readHostRegistryEntries(
  projectRoot: string,
): Promise<MiniProgramRegistryEntry[]> {
  const source = await readOptionalText(hostRegistryPath(projectRoot));
  return source ? parseRegistryEntries(source) : [];
}

async function readWorkspaceManifest(
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

async function readOptionalText(filePath: string): Promise<string | undefined> {
  try {
    return await fs.promises.readFile(filePath, 'utf8');
  } catch {
    return undefined;
  }
}

function hostRegistryPath(projectRoot: string): string {
  return path.join(projectRoot, 'lib', 'mini_program', 'mini_program_registry.dart');
}

async function promptOptionalEnvName(): Promise<string | undefined> {
  const envName = await vscode.window.showInputBox({
    prompt: 'Optional cloud environment name',
    placeHolder: 'Leave blank to use active environment',
    ignoreFocusOut: true,
  });
  return envName === undefined ? undefined : envName.trim() || '';
}

function diagnosticCommandTitle(scope: DiagnosticScope): string {
  switch (scope) {
    case 'miniProgram':
      return 'MiniProgram: Diagnose MiniProgram';
    case 'hostApp':
      return 'MiniProgram: Diagnose Host App';
    case 'cloudDelivery':
      return 'MiniProgram: Diagnose Cloud Delivery';
    default:
      return 'MiniProgram: Diagnose Workspace';
  }
}

function parseJsonObject(rawOutput: string): Record<string, unknown> {
  const trimmed = rawOutput.trim();
  const jsonText = trimmed.startsWith('{') && trimmed.endsWith('}')
    ? trimmed
    : trimmed.slice(trimmed.indexOf('{'), trimmed.lastIndexOf('}') + 1);
  const decoded: unknown = JSON.parse(jsonText);
  if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) {
    throw new Error('Command did not return a JSON object.');
  }
  return decoded as Record<string, unknown>;
}

async function choosePartnerPackageOutputPath(
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

async function choosePartnerPackageFile(): Promise<string | undefined> {
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

async function findPartnerPackageFiles(workspacePath: string): Promise<string[]> {
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

async function inferWorkspaceMiniProgramAppId(): Promise<string | undefined> {
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

async function chooseForce(prompt: string): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      { label: 'Normal', description: 'Do not pass --force', force: false },
      { label: 'Force', description: prompt, force: true },
    ],
    { title: 'MiniProgram command mode', ignoreFocusOut: true },
  );
  return choice?.force;
}

async function chooseWithDemo(): Promise<boolean | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Add public demo endpoint',
        description: 'Recommended for first test; uses public jsDelivr/GitHub delivery',
        withDemo: true,
      },
      {
        label: 'Clean adapter only',
        description: 'No demo endpoint or registry; production-friendly default',
        withDemo: false,
      },
    ],
    { title: 'MiniProgram public demo', ignoreFocusOut: true },
  );
  return choice?.withDemo;
}

async function chooseStaticOutputFolder(): Promise<string | undefined> {
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

async function chooseStaticClean(): Promise<boolean | undefined> {
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

async function chooseRequireAccessKeys(): Promise<boolean | undefined> {
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

async function chooseEndpointAccessMode(): Promise<'protected' | 'public' | undefined> {
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

async function chooseBackendRoot(
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

function validateAppId(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'App ID is required.';
  }
  if (!/^[a-z][a-z0-9_]*$/.test(trimmed)) {
    return 'Use lowercase letters, numbers, and underscores, starting with a letter.';
  }
  return undefined;
}

function validateEnvironmentName(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'Environment name is required.';
  }
  if (!/^[a-z][a-z0-9_-]*$/.test(trimmed)) {
    return 'Use lowercase letters, numbers, underscores, or hyphens, starting with a letter.';
  }
  if (trimmed === 'local' || trimmed === 'cloud') {
    return 'Use a named cloud environment, for example my-aws-prod.';
  }
  return undefined;
}

function validateOptionalEnvironmentName(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }
  if (!/^[a-z][a-z0-9_-]*$/.test(trimmed)) {
    return 'Use lowercase letters, numbers, underscores, or hyphens, starting with a letter.';
  }
  return undefined;
}

function validateAbsoluteUrl(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'API base URL is required.';
  }
  try {
    const parsed = new URL(trimmed);
    if (!parsed.protocol || !parsed.host) {
      return 'Enter an absolute URL.';
    }
    return undefined;
  } catch {
    return 'Enter an absolute URL.';
  }
}

function validateOptionalAbsoluteUrl(value: string): string | undefined {
  return value.trim() ? validateAbsoluteUrl(value) : undefined;
}

function validatePort(value: string): string | undefined {
  const parsed = Number.parseInt(value.trim(), 10);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    return 'Port must be 1-65535.';
  }
  return undefined;
}

function extractAccessKey(output: string): string | undefined {
  return /Access key:\s*(mpk_live_[A-Za-z0-9._-]+)/.exec(output)?.[1];
}

function validatePartnerPackageJson(decoded: unknown): string[] {
  const errors: string[] = [];
  if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) {
    return ['Package must be a JSON object.'];
  }
  const object = decoded as Record<string, unknown>;
  if (object.schemaVersion !== 1 && object.schemaVersion !== 2) {
    errors.push('schemaVersion must be 1 or 2.');
  }
  if (object.type !== 'mini_program_partner_handoff') {
    errors.push('type must be mini_program_partner_handoff.');
  }
  if (typeof object.appId !== 'string' || !object.appId.trim()) {
    errors.push('appId is required.');
  }
  if (typeof object.title !== 'string' || !object.title.trim()) {
    errors.push('title is required.');
  }
  if (typeof object.apiBaseUrl !== 'string' || validateAbsoluteUrl(object.apiBaseUrl)) {
    errors.push('apiBaseUrl must be an absolute URL.');
  }
  const accessMode = object.schemaVersion === 1
    ? 'protected'
    : typeof object.accessMode === 'string'
      ? object.accessMode.trim()
      : '';
  if (object.schemaVersion === 2 && accessMode !== 'protected' && accessMode !== 'public') {
    errors.push('accessMode must be protected or public.');
  }
  if (accessMode === 'protected' && (typeof object.accessKey !== 'string' || !object.accessKey.trim())) {
    errors.push('accessKey is required for protected packages.');
  }
  if (accessMode === 'public' && typeof object.accessKey === 'string' && object.accessKey.trim()) {
    errors.push('accessKey must be omitted for public packages.');
  }
  return errors;
}

function titleFromAppId(appId: string): string {
  return appId
    .split(/[._-]+/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function resolveCreateOutputRoot(selectedFolder: string, appId: string): string {
  return path.basename(selectedFolder).toLowerCase() === appId.toLowerCase()
    ? selectedFolder
    : path.join(selectedFolder, appId);
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
