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
  buildPublisherBackendRunArgs,
  buildPublisherBackendAwsDeployArgs,
  buildPublisherBackendAwsDataExportArgs,
  buildPublisherBackendAwsDataImportArgs,
  buildPublisherBackendAwsDataRedemptionsArgs,
  buildPublisherBackendAwsDataStatusArgs,
  buildPublisherBackendAwsDestroyArgs,
  buildPublisherBackendAwsLogsArgs,
  buildPublisherBackendAwsOutputsArgs,
  buildPublisherBackendAwsSeedArgs,
  buildPublisherBackendAwsSmokeArgs,
  buildPublisherBackendAwsStatusArgs,
  buildPublisherBackendScaffoldArgs,
  buildPublisherBackendStatusArgs,
  buildPublisherBackendStopArgs,
  buildPublisherBackendUrlsArgs,
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
    vscode.commands.registerCommand('miniProgramTools.publisherBackendSetup', () =>
      publisherBackendSetup(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendRun', () =>
      publisherBackendRun(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendStop', () =>
      publisherBackendStop(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendStatus', () =>
      publisherBackendStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDeploy', () =>
      publisherBackendAwsDeploy(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsStatus', () =>
      publisherBackendAwsStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsOutputs', () =>
      publisherBackendAwsOutputs(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsSmoke', () =>
      publisherBackendAwsSmoke(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsSmokeWrite', () =>
      publisherBackendAwsSmokeWrite(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsSeed', () =>
      publisherBackendAwsSeed(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDataStatus', () =>
      publisherBackendAwsDataStatus(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDataExport', () =>
      publisherBackendAwsDataExport(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDataImportDryRun', () =>
      publisherBackendAwsDataImportDryRun(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDataRedemptions', () =>
      publisherBackendAwsDataRedemptions(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsLogs', () =>
      publisherBackendAwsLogs(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendAwsDestroy', () =>
      publisherBackendAwsDestroy(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyAwsBackendHostCommand', () =>
      copyAwsBackendHostCommand(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyPublisherBackendUrls', () =>
      copyPublisherBackendUrls(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyMockBackendHostCommand', () =>
      copyMockBackendHostCommand(),
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

  const backendChoice = await chooseMiniProgramBackendStarter();
  if (!backendChoice) {
    return;
  }
  const outputRoot = resolveCreateOutputRoot(parentFolder, appId);
  const args = buildCreateArgs({
    appId,
    title,
    outputRoot,
    backendTemplate: backendChoice.backendTemplate,
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
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId.trim()),
    placeHolder: 'Coupon Demo',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
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
  const backend = await choosePublisherBackendMode();
  if (!backend) {
    return;
  }
  const force = await chooseForce('Replace an unrecognized endpoint file?');
  if (force === undefined) {
    return;
  }

  await runWorkspaceCliCommand(
    'Add Host Endpoint',
    buildHostEndpointAddArgs({
      appId: appId.trim(),
      title: title.trim(),
      apiBaseUrl: apiBaseUrl.trim(),
      backendBaseUrl: backend.kind === 'remote' ? backend.backendBaseUrl : undefined,
      backendLocalMock: backend.kind === 'local_mock',
      backendLocalMockPort: backend.kind === 'local_mock' ? backend.port : undefined,
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

async function publisherBackendSetup(
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
    ],
    { title: 'Publisher backend template', ignoreFocusOut: true },
  );
  if (!templateChoice) {
    return;
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
      storageMode: templateChoice.value === 'aws-lambda'
        ? templateChoice.storageMode
        : undefined,
      force,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(false);
  }
}

async function publisherBackendRun(
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

async function publisherBackendStop(
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

async function publisherBackendStatus(output: vscode.OutputChannel): Promise<void> {
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

async function publisherBackendAwsDeploy(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend AWS Deploy',
    buildPublisherBackendAwsDeployArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

async function publisherBackendAwsStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Status',
    buildPublisherBackendAwsStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsOutputs(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Outputs',
    buildPublisherBackendAwsOutputsArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsSmoke(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Smoke',
    buildPublisherBackendAwsSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
}

async function publisherBackendAwsSmokeWrite(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const couponId = await vscode.window.showInputBox({
    prompt: 'Coupon ID for write smoke',
    value: 'coupon-10',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Coupon ID is required.',
  });
  if (!couponId) {
    return;
  }
  const userId = await vscode.window.showInputBox({
    prompt: 'User ID for write smoke',
    value: 'smoke-user',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'User ID is required.',
  });
  if (!userId) {
    return;
  }
  const confirmation = await vscode.window.showWarningMessage(
    'Write smoke calls POST /coupon/redeem and may create a DynamoDB redemption record.',
    { modal: true },
    'Run Write Smoke',
  );
  if (confirmation !== 'Run Write Smoke') {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Write Smoke',
    buildPublisherBackendAwsSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
      includeWrite: true,
      writeCouponId: couponId.trim(),
      writeUserId: userId.trim(),
    }),
    workspacePath,
    output,
  );
}

async function publisherBackendAwsSeed(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend AWS DynamoDB Seed',
    buildPublisherBackendAwsSeedArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

async function publisherBackendAwsDataStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Data Status',
    buildPublisherBackendAwsDataStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsDataExport(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const includeMode = await vscode.window.showQuickPick(
    [
      {
        label: 'App records only',
        description: 'Export home, session, and coupons.',
        includeRedemptions: false,
      },
      {
        label: 'Include redemptions',
        description: 'Also export redemption history.',
        includeRedemptions: true,
      },
    ],
    {
      title: 'Choose AWS DynamoDB export scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  const outputPath = await chooseAwsDataExportPath(workspacePath, envName);
  if (!outputPath) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Data Export',
    buildPublisherBackendAwsDataExportArgs({
      envName,
      miniProgramRoot: workspacePath,
      output: outputPath,
      includeRedemptions: includeMode.includeRedemptions,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsDataImportDryRun(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const inputPath = await chooseAwsDataImportFile(workspacePath);
  if (!inputPath) {
    return;
  }
  const includeMode = await vscode.window.showQuickPick(
    [
      {
        label: 'Skip redemptions',
        description: 'Validate only app records from the export.',
        includeRedemptions: false,
      },
      {
        label: 'Include redemptions',
        description: 'Validate redemption records too.',
        includeRedemptions: true,
      },
    ],
    {
      title: 'Choose AWS DynamoDB import dry-run scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Import Dry Run',
    buildPublisherBackendAwsDataImportArgs({
      envName,
      miniProgramRoot: workspacePath,
      input: inputPath,
      dryRun: true,
      includeRedemptions: includeMode.includeRedemptions,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsDataRedemptions(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const couponId = await vscode.window.showInputBox({
    prompt: 'Optional coupon ID filter',
    placeHolder: 'coupon-20',
    ignoreFocusOut: true,
  });
  if (couponId === undefined) {
    return;
  }
  const userId = await vscode.window.showInputBox({
    prompt: 'Optional user ID filter',
    placeHolder: 'smoke-user',
    ignoreFocusOut: true,
  });
  if (userId === undefined) {
    return;
  }
  const limit = await vscode.window.showInputBox({
    prompt: 'Maximum redemption records to print',
    value: '50',
    ignoreFocusOut: true,
    validateInput: (value) => {
      const parsed = Number.parseInt(value.trim(), 10);
      return Number.isInteger(parsed) && parsed >= 1 && parsed <= 500
        ? undefined
        : 'Limit must be between 1 and 500.';
    },
  });
  if (!limit) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Redemptions',
    buildPublisherBackendAwsDataRedemptionsArgs({
      envName,
      miniProgramRoot: workspacePath,
      couponId: couponId.trim(),
      userId: userId.trim(),
      limit: limit.trim(),
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsLogs(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const since = await vscode.window.showInputBox({
    prompt: 'CloudWatch log time range',
    value: '1h',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Time range is required.',
  });
  if (!since) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Logs',
    buildPublisherBackendAwsLogsArgs({
      envName,
      miniProgramRoot: workspacePath,
      since: since.trim(),
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function publisherBackendAwsDestroy(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const mode = await vscode.window.showQuickPick(
    [
      {
        label: 'Guarded delete',
        description: 'Delete only if DynamoDB data guard allows it.',
        confirmDataLoss: false,
      },
      {
        label: 'Delete stack and DynamoDB data',
        description: 'Pass --confirm-data-loss after extra confirmation.',
        confirmDataLoss: true,
      },
    ],
    {
      title: 'Destroy AWS publisher backend stack',
      ignoreFocusOut: true,
    },
  );
  if (!mode) {
    return;
  }
  if (mode.confirmDataLoss) {
    const typed = await vscode.window.showInputBox({
      prompt: 'Type delete data to confirm stack and DynamoDB data deletion',
      ignoreFocusOut: true,
      validateInput: (value) =>
        value.trim() === 'delete data' ? undefined : 'Type delete data to confirm.',
    });
    if (typed?.trim() !== 'delete data') {
      return;
    }
  } else {
    const confirmation = await vscode.window.showWarningMessage(
      'This will request AWS stack deletion. The CLI will block deletion if stack-owned DynamoDB data exists.',
      { modal: true },
      'Run Guarded Delete',
    );
    if (confirmation !== 'Run Guarded Delete') {
      return;
    }
  }
  await runCliCommand(
    'Publisher Backend AWS Destroy',
    buildPublisherBackendAwsDestroyArgs({
      envName,
      miniProgramRoot: workspacePath,
      yes: true,
      confirmDataLoss: mode.confirmDataLoss,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

async function copyAwsBackendHostCommand(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const appId = await promptAppId();
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId),
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://cdn.example.com/public_mini_program/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const result = await runCliCapture(
    'Publisher Backend AWS Outputs',
    buildPublisherBackendAwsOutputsArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: false },
  );
  if (!result) {
    return;
  }
  const json = parseJsonObject(result.stdout);
  const outputs = json.outputs && typeof json.outputs === 'object'
    ? (json.outputs as Record<string, unknown>)
    : {};
  const backendBaseUrl =
    stringValue(json.backendBaseUrl) ??
    stringValue(outputs.PublisherBackendBaseUrl);
  if (!backendBaseUrl) {
    vscode.window.showErrorMessage(
      'PublisherBackendBaseUrl was not found. Deploy the AWS publisher backend first.',
    );
    return;
  }
  const args = buildHostEndpointAddArgs({
    appId,
    title: title.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
    public: true,
    backendBaseUrl,
    projectRoot: '.',
  }).filter((arg, index, all) => {
    return !(arg === '--project-root' || all[index - 1] === '--project-root');
  });
  const command = formatCommandLine(configuredCliPath(), args);
  await vscode.env.clipboard.writeText(command);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied AWS publisher backend host command:');
  output.appendLine(command);
  vscode.window.showInformationMessage('AWS backend host command copied.');
}

async function copyPublisherBackendUrls(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireWorkspacePath();
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
  const result = await runCliCapture(
    'Publisher Backend URLs',
    buildPublisherBackendUrlsArgs({ port: port.trim() }),
    workspacePath,
    output,
    { allowNonZeroExit: false },
  );
  if (!result) {
    return;
  }
  const text = result.stdout.trim();
  await vscode.env.clipboard.writeText(text);
  output.show(true);
  output.appendLine('');
  output.appendLine(text);
  vscode.window.showInformationMessage('Publisher backend URLs copied.');
}

async function copyMockBackendHostCommand(): Promise<void> {
  const appId = await vscode.window.showInputBox({
    prompt: 'Mini-program appId',
    placeHolder: 'coupon_app',
    ignoreFocusOut: true,
    validateInput: validateAppId,
  });
  if (!appId) {
    return;
  }
  const title = await vscode.window.showInputBox({
    prompt: 'Mini-program display title',
    value: hostTitleFromAppId(appId.trim()),
    placeHolder: 'Coupon App',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Title is required.',
  });
  if (!title) {
    return;
  }
  const apiBaseUrl = await vscode.window.showInputBox({
    prompt: 'Mini-program delivery API base URL',
    placeHolder: 'https://cdn.example.com/public_mini_program/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!apiBaseUrl) {
    return;
  }
  const port = await vscode.window.showInputBox({
    prompt: 'Publisher mock backend port',
    value: '9090',
    ignoreFocusOut: true,
    validateInput: validatePort,
  });
  if (!port) {
    return;
  }
  const args = buildHostEndpointAddArgs({
    appId: appId.trim(),
    title: title.trim(),
    apiBaseUrl: apiBaseUrl.trim(),
    public: true,
    backendLocalMock: true,
    backendLocalMockPort: port.trim(),
    projectRoot: '.',
  }).filter((arg, index, all) => {
    return !(arg === '--project-root' || all[index - 1] === '--project-root');
  });
  const command = formatCommandLine(configuredCliPath(), args);
  await vscode.env.clipboard.writeText(command);
  vscode.window.showInformationMessage('Mock backend host command copied.');
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

  const backendBaseUrl = await promptOptionalPublisherBackendBaseUrl();

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
      backendBaseUrl,
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
    output.appendLine(`Publisher backend URL: ${decoded.backendBaseUrl ?? 'not configured'}`);
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

  const cliCapabilities = await detectPublisherBackendAwsCli027(
    workspacePath,
    output,
  );

  const report = await buildDiagnosticsReport({
    workspacePath,
    scope,
    workflowReport,
    remoteWorkflowReport,
    doctorReport,
    cliCapabilities,
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
  const backendChoice = await chooseMiniProgramBackendStarter();
  if (!backendChoice) {
    return false;
  }

  const outputRoot = resolveCreateOutputRoot(parentFolder, appId.trim());
  if (!(await runGuidedCliStep(
    'Create MiniProgram',
    buildCreateArgs({
      appId: appId.trim(),
      title: title.trim() || undefined,
      outputRoot,
      backendTemplate: backendChoice.backendTemplate,
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

async function runCliCapture(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
  options: { readonly allowNonZeroExit?: boolean } = {},
): Promise<{ readonly stdout: string; readonly stderr: string } | undefined> {
  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, args)}`);
  try {
    const result = await runCli(cliPath, args, {
      cwd,
      timeoutMs: 120000,
    });
    if (result.stdout.trim()) {
      output.append(result.stdout);
    }
    if (result.stderr.trim()) {
      output.append(result.stderr);
    }
    if (result.exitCode !== 0 && !options.allowNonZeroExit) {
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

async function chooseMiniProgramBackendStarter(): Promise<
  { readonly backendTemplate?: 'mock' } | undefined
> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'Normal mini-program',
        description: 'No publisher backend starter',
        backendTemplate: undefined,
      },
      {
        label: 'Mini-program with mock backend',
        description: 'Generate backend/mock and backend-bound starter UI',
        backendTemplate: 'mock' as const,
      },
    ],
    { title: 'Publisher backend starter', ignoreFocusOut: true },
  );
  return choice
    ? { backendTemplate: choice.backendTemplate }
    : undefined;
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

async function promptRequiredEnvName(prompt: string): Promise<string | undefined> {
  const envName = await vscode.window.showInputBox({
    prompt,
    placeHolder: 'my-aws-prod',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Environment is required.',
  });
  return envName === undefined ? undefined : envName.trim();
}

async function promptPublisherBackendAwsEnvName(
  workspacePath: string,
): Promise<string | undefined> {
  const defaultEnv = readPublisherBackendAwsStateValue(
    workspacePath,
    'environmentName',
  );
  const envName = await vscode.window.showInputBox({
    prompt: 'AWS environment name',
    value: defaultEnv,
    placeHolder: 'my-aws-prod',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Environment is required.',
  });
  return envName === undefined ? undefined : envName.trim();
}

function readPublisherBackendAwsStateValue(
  workspacePath: string,
  key: string,
): string | undefined {
  try {
    const statePath = path.join(
      workspacePath,
      '.mini_program',
      'publisher_backend.aws.json',
    );
    if (!fs.existsSync(statePath)) {
      return undefined;
    }
    const decoded = JSON.parse(fs.readFileSync(statePath, 'utf8')) as Record<
      string,
      unknown
    >;
    return stringValue(decoded[key]);
  } catch {
    return undefined;
  }
}

interface PublisherBackendAwsCliCapability {
  readonly checked: boolean;
  readonly supportsWriteSmoke: boolean;
  readonly supportsDataManagement: boolean;
  readonly detail?: string;
}

async function detectPublisherBackendAwsCliCapabilities(
  workspacePath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  const cliPath = configuredCliPath();
  const smokeArgs = ['publisher-backend', 'aws', 'smoke', '--help'];
  const dataExportArgs = ['publisher-backend', 'aws', 'data', 'export', '--help'];
  const redemptionsArgs = [
    'publisher-backend',
    'aws',
    'data',
    'redemptions',
    '--help',
  ];
  output?.appendLine(`> ${formatRedactedCommandLine(cliPath, smokeArgs)}`);
  try {
    const smokeResult = await runCli(cliPath, smokeArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    const combined = `${smokeResult.stdout}\n${smokeResult.stderr}`;
    const supportsWriteSmoke =
      smokeResult.exitCode === 0 && combined.includes('--include-write');
    output?.appendLine(`> ${formatRedactedCommandLine(cliPath, dataExportArgs)}`);
    const dataExportResult = await runCli(cliPath, dataExportArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    output?.appendLine(`> ${formatRedactedCommandLine(cliPath, redemptionsArgs)}`);
    const redemptionsResult = await runCli(cliPath, redemptionsArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    const dataCombined = `${dataExportResult.stdout}\n${dataExportResult.stderr}\n${redemptionsResult.stdout}\n${redemptionsResult.stderr}`;
    const supportsDataManagement =
      dataExportResult.exitCode === 0 &&
      redemptionsResult.exitCode === 0 &&
      dataCombined.includes('--include-redemptions') &&
      dataCombined.includes('--coupon-id');
    const details = [
      supportsWriteSmoke
        ? undefined
        : 'Configured CLI does not list --include-write in publisher-backend aws smoke --help.',
      supportsDataManagement
        ? undefined
        : 'Configured CLI does not expose AWS DynamoDB data export/redemptions help.',
    ].filter((value): value is string => Boolean(value));
    return {
      checked: true,
      supportsWriteSmoke,
      supportsDataManagement,
      detail: details.join(' '),
    };
  } catch (error) {
    return {
      checked: true,
      supportsWriteSmoke: false,
      supportsDataManagement: false,
      detail: errorMessage(error),
    };
  }
}

async function detectPublisherBackendAwsCli027(
  workspacePath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherBackendAwsCliCapability> {
  return detectPublisherBackendAwsCliCapabilities(workspacePath, output);
}

async function ensurePublisherBackendAwsCli027(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (capability.supportsWriteSmoke) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.27 or newer is required for AWS DynamoDB sidebar actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.27`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

async function ensurePublisherBackendAwsCli028(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherBackendAwsCliCapabilities(
    workspacePath,
    output,
  );
  if (capability.supportsDataManagement) {
    return true;
  }
  const message =
    'MiniProgram CLI 0.3.28 or newer is required for AWS DynamoDB data management actions. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.28`.';
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
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

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

async function chooseAwsDataExportPath(
  workspacePath: string,
  envName: string,
): Promise<string | undefined> {
  const appId = await readMiniProgramManifestId(workspacePath);
  const timestamp = compactTimestamp(new Date());
  const fileName = `${safeFileSegment(appId ?? path.basename(workspacePath))}-${safeFileSegment(envName)}-data-export-${timestamp}.json`;
  const uri = await vscode.window.showSaveDialog({
    defaultUri: vscode.Uri.file(
      path.join(workspacePath, 'backend', 'aws_lambda', 'exports', fileName),
    ),
    filters: {
      'AWS DynamoDB data export JSON': ['json'],
    },
    saveLabel: 'Export DynamoDB data',
    title: 'Choose AWS DynamoDB data export file',
  });
  return uri?.fsPath;
}

async function chooseAwsDataImportFile(
  workspacePath: string,
): Promise<string | undefined> {
  const exportFiles = await findAwsDataExportFiles(workspacePath);
  if (exportFiles.length > 0) {
    const selected = await vscode.window.showQuickPick(
      [
        ...exportFiles.map((filePath) => ({
          label: path.basename(filePath),
          description: path.dirname(filePath),
          filePath,
        })),
        {
          label: 'Choose another file...',
          description: 'Select an AWS DynamoDB export JSON file',
          filePath: '',
        },
      ],
      { title: 'Choose AWS DynamoDB data export file', ignoreFocusOut: true },
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
      'AWS DynamoDB data export JSON': ['json'],
    },
    openLabel: 'Choose export file',
    title: 'Choose AWS DynamoDB data export file',
    defaultUri: vscode.Uri.file(
      path.join(workspacePath, 'backend', 'aws_lambda', 'exports'),
    ),
  });
  return selectedFiles?.[0]?.fsPath;
}

async function findAwsDataExportFiles(workspacePath: string): Promise<string[]> {
  const exportsRoot = path.join(workspacePath, 'backend', 'aws_lambda', 'exports');
  try {
    const entries = await fs.promises.readdir(exportsRoot, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith('.json'))
      .map((entry) => path.join(exportsRoot, entry.name))
      .sort((left, right) => right.localeCompare(left))
      .slice(0, 20);
  } catch {
    return [];
  }
}

async function readMiniProgramManifestId(
  workspacePath: string,
): Promise<string | undefined> {
  try {
    const manifestPath = path.join(workspacePath, 'manifest.json');
    const decoded = JSON.parse(await fs.promises.readFile(manifestPath, 'utf8')) as Record<
      string,
      unknown
    >;
    return stringValue(decoded.id);
  } catch {
    return undefined;
  }
}

function compactTimestamp(value: Date): string {
  return value
    .toISOString()
    .replace(/[-:]/g, '')
    .replace(/\.\d{3}Z$/, 'Z');
}

function safeFileSegment(value: string): string {
  return value.replace(/[^A-Za-z0-9_.-]+/g, '_') || 'mini_program';
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

async function promptOptionalPublisherBackendBaseUrl(): Promise<string | undefined> {
  const value = await vscode.window.showInputBox({
    prompt: 'Optional publisher-owned backend base URL',
    placeHolder: 'https://publisher.example.com/api/ (leave blank for none)',
    ignoreFocusOut: true,
    validateInput: validateOptionalAbsoluteUrl,
  });
  return value?.trim() || undefined;
}

type PublisherBackendMode =
  | { readonly kind: 'none' }
  | { readonly kind: 'local_mock'; readonly port: string }
  | { readonly kind: 'remote'; readonly backendBaseUrl: string };

async function choosePublisherBackendMode(): Promise<PublisherBackendMode | undefined> {
  const choice = await vscode.window.showQuickPick(
    [
      {
        label: 'No backend',
        description: 'Only configure manifest/screen delivery',
        value: 'none' as const,
      },
      {
        label: 'Local mock backend',
        description: 'Use miniprogram publisher-backend run, default port 9090',
        value: 'local_mock' as const,
      },
      {
        label: 'Remote publisher backend',
        description: 'Use a real HTTPS publisher-owned API base URL',
        value: 'remote' as const,
      },
    ],
    { title: 'Publisher backend mode', ignoreFocusOut: true },
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
  if (
    object.backendBaseUrl !== undefined &&
    (typeof object.backendBaseUrl !== 'string' ||
      validateAbsoluteUrl(object.backendBaseUrl))
  ) {
    errors.push('backendBaseUrl must be an absolute URL when present.');
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
