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
  readonly miniProgramRoot?: string;
}

export interface PreviewArgsOptions {
  readonly deviceId: string;
  readonly miniProgramRoot?: string;
}

export interface WorkspaceMiniProgramArgsOptions {
  readonly miniProgramRoot?: string;
}

export interface EmbedInitArgsOptions {
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface EmbedCloudConfigureArgsOptions {
  readonly projectRoot: string;
  readonly envName?: string;
}

export interface HostEndpointImportArgsOptions {
  readonly partnerPackagePath: string;
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface HostEndpointAddArgsOptions {
  readonly appId: string;
  readonly apiBaseUrl: string;
  readonly accessKey: string;
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface HostRunArgsOptions {
  readonly deviceId: string;
  readonly projectRoot: string;
  readonly envName?: string;
}

export interface AccessKeyCreateArgsOptions {
  readonly appId: string;
  readonly keyId: string;
  readonly envName?: string;
}

export interface AccessKeyListArgsOptions {
  readonly appId: string;
  readonly envName?: string;
  readonly json?: boolean;
}

export interface AccessKeyRevokeArgsOptions {
  readonly appId: string;
  readonly keyId: string;
  readonly envName?: string;
}

export interface AccessKeyRotateArgsOptions {
  readonly appId: string;
  readonly keyId: string;
  readonly newKeyId?: string;
  readonly envName?: string;
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

export function buildBuildArgs(
  options: WorkspaceMiniProgramArgsOptions = {},
): string[] {
  return withMiniProgramRoot(['build'], options.miniProgramRoot);
}

export function buildValidateArgs(
  options: WorkspaceMiniProgramArgsOptions = {},
): string[] {
  return withMiniProgramRoot(['validate'], options.miniProgramRoot);
}

export function buildPreviewArgs(options: PreviewArgsOptions): string[] {
  return withMiniProgramRoot(
    ['preview', '-d', options.deviceId],
    options.miniProgramRoot,
  );
}

export function buildPublishArgs(options: PublishArgsOptions): string[] {
  const args = ['publish', '--target', options.target];
  if (options.envName?.trim()) {
    args.push('--env', options.envName.trim());
  }
  return withMiniProgramRoot(args, options.miniProgramRoot);
}

export function buildEmbedInitArgs(options: EmbedInitArgsOptions): string[] {
  const args = ['embed', 'init', '--project-root', options.projectRoot];
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildEmbedCloudConfigureArgs(
  options: EmbedCloudConfigureArgsOptions,
): string[] {
  const args = [
    'embed',
    'cloud',
    'configure',
    '--project-root',
    options.projectRoot,
  ];
  if (options.envName?.trim()) {
    args.push('--env', options.envName.trim());
  }
  return args;
}

export function buildHostEndpointImportArgs(
  options: HostEndpointImportArgsOptions,
): string[] {
  const args = [
    'host',
    'endpoint',
    'import',
    options.partnerPackagePath,
    '--project-root',
    options.projectRoot,
  ];
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildHostEndpointAddArgs(
  options: HostEndpointAddArgsOptions,
): string[] {
  const args = [
    'host',
    'endpoint',
    'add',
    options.appId,
    '--api-base-url',
    options.apiBaseUrl,
    '--access-key',
    options.accessKey,
    '--project-root',
    options.projectRoot,
  ];
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildHostRunArgs(options: HostRunArgsOptions): string[] {
  const args = ['host', 'run', '-d', options.deviceId, '--project-root', options.projectRoot];
  if (options.envName?.trim()) {
    args.push('--env', options.envName.trim());
  }
  return args;
}

export function buildAccessKeyCreateArgs(
  options: AccessKeyCreateArgsOptions,
): string[] {
  const args = [
    'access-key',
    'create',
    options.appId,
    '--key-id',
    options.keyId,
  ];
  return withEnvName(args, options.envName);
}

export function buildAccessKeyListArgs(
  options: AccessKeyListArgsOptions,
): string[] {
  const args = ['access-key', 'list', options.appId];
  if (options.json ?? true) {
    args.push('--json');
  }
  return withEnvName(args, options.envName);
}

export function buildAccessKeyRevokeArgs(
  options: AccessKeyRevokeArgsOptions,
): string[] {
  const args = [
    'access-key',
    'revoke',
    options.appId,
    '--key-id',
    options.keyId,
  ];
  return withEnvName(args, options.envName);
}

export function buildAccessKeyRotateArgs(
  options: AccessKeyRotateArgsOptions,
): string[] {
  const args = [
    'access-key',
    'rotate',
    options.appId,
    '--key-id',
    options.keyId,
  ];
  if (options.newKeyId?.trim()) {
    args.push('--new-key-id', options.newKeyId.trim());
  }
  return withEnvName(args, options.envName);
}

export function formatCommandLine(command: string, args: readonly string[]): string {
  return [command, ...args].map(shellQuote).join(' ');
}

export function formatRedactedCommandLine(
  command: string,
  args: readonly string[],
): string {
  return formatCommandLine(command, redactSecretArgs(args));
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

function withMiniProgramRoot(args: string[], miniProgramRoot?: string): string[] {
  if (miniProgramRoot?.trim()) {
    args.push('--mini-program-root', miniProgramRoot.trim());
  }
  return args;
}

function withEnvName(args: string[], envName?: string): string[] {
  if (envName?.trim()) {
    args.push('--env', envName.trim());
  }
  return args;
}

function redactSecretArgs(args: readonly string[]): string[] {
  const secretOptions = new Set(['--access-key', '--key']);
  const redacted = [...args];
  for (let index = 0; index < redacted.length; index += 1) {
    if (secretOptions.has(redacted[index]) && index + 1 < redacted.length) {
      redacted[index + 1] = '<redacted>';
    } else if (redacted[index].startsWith('--access-key=')) {
      redacted[index] = '--access-key=<redacted>';
    } else if (redacted[index].startsWith('--key=')) {
      redacted[index] = '--key=<redacted>';
    }
  }
  return redacted;
}
