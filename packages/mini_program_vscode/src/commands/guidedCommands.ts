import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildAccessKeyCreateArgs,
  buildAccessKeyListArgs,
  buildBuildArgs,
  buildCloudAppInfoArgs,
  buildCloudStatusArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedCloudConfigureArgs,
  buildEmbedInitArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
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
  configuredCliPath,
  configuredDefaultPreviewDevice,
  detectPublisherBackendAwsCli027,
  diagnosticCommandTitle,
  errorMessage,
  extractAccessKey,
  parseJsonObject,
  promptAppId,
  promptHostEndpointInputs,
  promptKeyId,
  promptOptionalEnvName,
  readWorkspaceManifest,
  requireHostProjectRoot,
  requireMiniProgramRoot,
  requireWorkspacePath,
  resolveCreateOutputRoot,
  runGuidedCliStep,
  runGuidedCliStepCapture,
  runGuidedMiniProgramBuildValidatePublish,
  titleFromAppId,
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

export async function guidedPublishMiniProgramToAws(
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

export async function checkHostEndpointRemote(output: vscode.OutputChannel): Promise<void> {
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

export async function copyCleanupCommands(output: vscode.OutputChannel): Promise<void> {
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
