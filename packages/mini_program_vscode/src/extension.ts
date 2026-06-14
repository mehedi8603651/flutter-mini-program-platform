import * as vscode from 'vscode';

import {
  buildBuildArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  formatRedactedCommandLine,
  runCli,
} from './cli';
import {
  createMiniProgram,
  previewMiniProgram,
  publishMiniProgram,
  publishPublicStaticMiniProgram,
} from './commands/coreCommands';
import {
  envInit,
  environmentStatus,
  useEnvironment,
} from './commands/environmentCommands';
import {
  checkHostEndpointRemote,
  copyCleanupCommands,
  copyWorkflowCommands,
  diagnoseWorkspace,
  runGuidedWorkflow,
} from './commands/guidedCommands';
import {
  addHostEndpoint,
  addMiniProgramToRegistry,
  copyDemoHostButton,
  embedInit,
  generateMiniProgramRegistry,
  importHostEndpoint,
  runHostApp,
} from './commands/hostCommands';
import {
  backendInit,
  backendStart,
  backendStatus,
  backendStop,
  publisherBackendRun,
  publisherBackendSetup,
  publisherBackendStatus,
  publisherBackendStop,
} from './commands/localBackendCommands';
import {
  copyMockBackendHostCommand,
  copyPublisherBackendUrls,
  createPartnerPackage,
  openPartnerPackage,
  validatePartnerPackage,
} from './commands/partnerCommands';
import {
  publisherBackendContractInit,
  publisherBackendContractSmoke,
  publisherBackendContractValidate,
} from './commands/publisherBackendContractCommands';
import {
  autoRefreshEnabled,
  configuredCliPath,
  errorMessage,
  getWorkspacePath,
  runMiniProgramWorkspaceCliCommand,
} from './extensionSupport';
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
    vscode.commands.registerCommand('miniProgramTools.useEnvironment', () =>
      useEnvironment(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.environmentStatus', () =>
      environmentStatus(output),
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
    vscode.commands.registerCommand('miniProgramTools.publisherBackendContractInit', () =>
      publisherBackendContractInit(output, refreshStatus),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendContractValidate', () =>
      publisherBackendContractValidate(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.publisherBackendContractSmoke', () =>
      publisherBackendContractSmoke(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyPublisherBackendUrls', () =>
      copyPublisherBackendUrls(output),
    ),
    vscode.commands.registerCommand('miniProgramTools.copyMockBackendHostCommand', () =>
      copyMockBackendHostCommand(),
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
    vscode.commands.registerCommand('miniProgramTools.setupNewMiniProgram', () =>
      runGuidedWorkflow('setupNewMiniProgram', output),
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
