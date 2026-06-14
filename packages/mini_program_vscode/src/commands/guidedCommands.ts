import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildBuildArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedInitArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  formatCommandLine,
  formatRedactedCommandLine,
  runCli,
} from '../cli';
import {
  DiagnosticScope,
  buildDiagnosticsReport,
  formatDiagnosticsReport,
  redactSecrets,
} from '../diagnostics';
import {
  GuidedWorkflowId,
  formatGuidedWorkflowPlan,
  guidedWorkflowById,
} from '../guidedWorkflows';
import {
  buildCleanupCommandTemplate,
  buildHostCommandTemplate,
  buildPublisherCommandTemplate,
  titleFromAppId as hostTitleFromAppId,
} from '../hostIntegration';
import { parseWorkflowStatusJson } from '../workflowStatus';

import {
  chooseForce,
  chooseHostEndpointAppId,
  chooseMiniProgramBackendStarter,
  choosePartnerPackageFile,
  choosePartnerPackageOutputPath,
  chooseStaticClean,
  chooseStaticOutputFolder,
  configuredCliPath,
  configuredDefaultPreviewDevice,
  detectPublisherApiCliCapabilities,
  diagnosticCommandTitle,
  errorMessage,
  parseJsonObject,
  promptAppId,
  promptHostEndpointInputs,
  readWorkspaceManifest,
  requireHostProjectRoot,
  requireMiniProgramRoot,
  requireWorkspacePath,
  resolveCreateOutputRoot,
  runGuidedCliStep,
  titleFromAppId,
  validateAbsoluteUrl,
  validateAppId,
} from '../extensionSupport';
import {
  validatePartnerPackageFile,
} from './partnerCommands';

export async function diagnoseWorkspace(
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

  const cliCapabilities = await detectPublisherApiCliCapabilities(
    workspacePath,
    output,
  );

  const report = await buildDiagnosticsReport({
    workspacePath,
    scope,
    workflowReport,
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

export async function runGuidedWorkflow(
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
      case 'publishMiniProgramStatic':
        completed = await guidedPublishMiniProgramStatic(output);
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

export async function guidedSetupNewMiniProgram(
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

export async function guidedPublishMiniProgramStatic(
  output: vscode.OutputChannel,
): Promise<boolean> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return false;
  }
  const outputPath = await chooseStaticOutputFolder();
  if (!outputPath) {
    return false;
  }
  const clean = await chooseStaticClean();
  if (clean === undefined) {
    return false;
  }
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
    'Publish Static Artifacts',
    buildPublishArgs({
      target: 'static',
      outputPath,
      clean,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
}

export async function guidedPreparePartnerHandoff(
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
  const artifactBaseUrl = await vscode.window.showInputBox({
    prompt: 'Public static artifact base URL',
    placeHolder: 'https://cdn.example.com/coupon_demo/',
    ignoreFocusOut: true,
    validateInput: validateAbsoluteUrl,
  });
  if (!artifactBaseUrl) {
    return false;
  }
  const outputPath = await choosePartnerPackageOutputPath(workspacePath, appId);
  if (!outputPath) {
    return false;
  }
  if (!(await guidedPublishMiniProgramStatic(output))) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Create Partner Package',
    buildPartnerPackageArgs({
      appId,
      title: title.trim() || undefined,
      apiBaseUrl: artifactBaseUrl.trim(),
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

export async function guidedSetupHostApp(output: vscode.OutputChannel): Promise<boolean> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return false;
  }
  const force = await chooseForce('Overwrite scaffold-managed host adapter files?');
  if (force === undefined) {
    return false;
  }
  if (!(await runGuidedCliStep(
    'Embed Init',
    buildEmbedInitArgs({ projectRoot, force }),
    projectRoot,
    output,
  ))) {
    return false;
  }
  await diagnoseWorkspace('hostApp', output);
  return true;
}

export async function guidedAddMiniProgramToHost(
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
        description: 'Enter appId, static artifact URL, and optional runtime API',
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

export async function guidedRunHostSmokeTest(output: vscode.OutputChannel): Promise<boolean> {
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
  const cliPath = configuredCliPath();
  const args = buildHostRunArgs({
    deviceId: deviceId.trim(),
    projectRoot,
  });
  const terminal = vscode.window.createTerminal({
    name: 'MiniProgram Host Smoke Test',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(formatCommandLine(cliPath, args));
  return true;
}

export async function copyWorkflowCommands(output: vscode.OutputChannel): Promise<void> {
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

export async function checkHostEndpointRemote(output: vscode.OutputChannel): Promise<void> {
  const projectRoot = await requireHostProjectRoot();
  if (!projectRoot) {
    return;
  }
  const appId = await chooseHostEndpointAppId(projectRoot);
  if (!appId) {
    return;
  }
  output.show(true);
  output.appendLine('');
  output.appendLine(`== MiniProgram: Check Host Endpoint ==`);
  output.appendLine(`Endpoint appId: ${appId}`);
  output.appendLine(
    'Provider remote delivery checks were removed. Use host diagnostics to verify the public static artifact URL and optional runtime Publisher API.',
  );
  await diagnoseWorkspace('hostApp', output);
}

export async function copyCleanupCommands(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireWorkspacePath();
  if (!workspacePath) {
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
        description: 'No provider cleanup is needed for public static artifacts',
        value: false,
      },
    ],
    { title: 'Cleanup command scope', ignoreFocusOut: true },
  );
  if (!includeWorkspaceDelete) {
    return;
  }

  const commands = buildCleanupCommandTemplate({
    workspacePath: includeWorkspaceDelete.value ? workspacePath : undefined,
  });
  await vscode.env.clipboard.writeText(commands);
  output.show(true);
  output.appendLine('');
  output.appendLine('Copied cleanup commands:');
  output.appendLine(commands);
  vscode.window.showInformationMessage('MiniProgram cleanup commands copied.');
}
