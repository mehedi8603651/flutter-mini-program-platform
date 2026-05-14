import { spawn } from 'child_process';

export const defaultCliPath = 'miniprogram';

export interface CliResult {
  readonly exitCode: number | null;
  readonly stdout: string;
  readonly stderr: string;
  readonly commandLine: string;
}

export interface CliRunOptions {
  readonly cwd?: string;
  readonly timeoutMs?: number;
  readonly onStdout?: (chunk: string) => void;
  readonly onStderr?: (chunk: string) => void;
}

export interface WorkflowStatusArgsOptions {
  readonly workspacePath: string;
  readonly envName?: string;
  readonly remote?: boolean;
}

export interface CreateArgsOptions {
  readonly appId: string;
  readonly title?: string;
  readonly outputRoot: string;
}

export interface PublishArgsOptions {
  readonly target: 'local' | 'cloud';
  readonly envName?: string;
}

export interface PreviewArgsOptions {
  readonly deviceId: string;
}

export function resolveCliPath(value: string | undefined | null): string {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : defaultCliPath;
}

export function buildWorkflowStatusArgs(
  options: WorkflowStatusArgsOptions,
): string[] {
  const args = [
    'workflow',
    'status',
    '--workspace',
    options.workspacePath,
    '--json',
  ];
  if (options.envName?.trim()) {
    args.push('--env', options.envName.trim());
  }
  if (options.remote) {
    args.push('--remote');
  }
  return args;
}

export function buildCreateArgs(options: CreateArgsOptions): string[] {
  const args = ['create', options.appId, '--output-root', options.outputRoot];
  if (options.title?.trim()) {
    args.push('--title', options.title.trim());
  }
  return args;
}

export function buildBuildArgs(): string[] {
  return ['build'];
}

export function buildValidateArgs(): string[] {
  return ['validate'];
}

export function buildPreviewArgs(options: PreviewArgsOptions): string[] {
  return ['preview', '-d', options.deviceId];
}

export function buildPublishArgs(options: PublishArgsOptions): string[] {
  const args = ['publish', '--target', options.target];
  if (options.envName?.trim()) {
    args.push('--env', options.envName.trim());
  }
  return args;
}

export function formatCommandLine(command: string, args: readonly string[]): string {
  return [command, ...args].map(shellQuote).join(' ');
}

export function runCli(
  command: string,
  args: readonly string[],
  options: CliRunOptions = {},
): Promise<CliResult> {
  return runCliStreaming(command, args, options);
}

export function runCliStreaming(
  command: string,
  args: readonly string[],
  options: CliRunOptions = {},
): Promise<CliResult> {
  const commandLine = formatCommandLine(command, args);
  return new Promise((resolve, reject) => {
    const child = spawn(command, [...args], {
      cwd: options.cwd,
      shell: process.platform === 'win32',
      windowsHide: true,
    });
    let stdout = '';
    let stderr = '';
    let settled = false;
    const timer =
      options.timeoutMs && options.timeoutMs > 0
        ? setTimeout(() => {
            if (settled) {
              return;
            }
            settled = true;
            child.kill();
            reject(new Error(`Command timed out: ${commandLine}`));
          }, options.timeoutMs)
        : undefined;

    child.stdout?.on('data', (data: Buffer) => {
      const chunk = data.toString();
      stdout += chunk;
      options.onStdout?.(chunk);
    });
    child.stderr?.on('data', (data: Buffer) => {
      const chunk = data.toString();
      stderr += chunk;
      options.onStderr?.(chunk);
    });
    child.on('error', (error) => {
      if (settled) {
        return;
      }
      settled = true;
      if (timer) {
        clearTimeout(timer);
      }
      reject(error);
    });
    child.on('close', (exitCode) => {
      if (settled) {
        return;
      }
      settled = true;
      if (timer) {
        clearTimeout(timer);
      }
      resolve({ exitCode, stdout, stderr, commandLine });
    });
  });
}

function shellQuote(value: string): string {
  if (/^[A-Za-z0-9_./:=@+-]+$/.test(value)) {
    return value;
  }
  if (process.platform === 'win32') {
    return `"${value.replace(/"/g, '\\"')}"`;
  }
  return `'${value.replace(/'/g, "'\\''")}'`;
}
