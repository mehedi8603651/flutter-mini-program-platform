import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import {
  buildBuildArgs,
  buildPublishArgs,
  buildValidateArgs,
  formatRedactedCommandLine,
  runCli,
  runCliStreaming,
} from '../cli';

import {
  errorMessage,
} from './jsonValues';
import {
  configuredCliPath,
  getWorkspacePath,
} from './workspace';

export async function runWorkspaceCliCommand(
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

export async function runMiniProgramWorkspaceCliCommand(
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

export async function runGuidedMiniProgramBuildValidatePublish(
  workspacePath: string,
  outputPath: string | undefined,
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
      target: 'static',
      outputPath: outputPath?.trim() || undefined,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
}

export async function runGuidedCliStep(
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

export async function runGuidedCliStepCapture(
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

export async function runCliCommand(
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

export async function runCliCapture(
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
