/// <reference types="node" />

import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

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
  readonly remote?: boolean;
}

export interface DoctorArgsOptions {
  readonly json?: boolean;
}

export interface CapabilitiesArgsOptions {
  readonly json?: boolean;
}

export interface CreateArgsOptions {
  readonly appId: string;
  readonly title?: string;
  readonly outputRoot: string;
  readonly backendTemplate?: 'mock';
  readonly screenFormat?: 'mp';
  readonly force?: boolean;
}

export interface PublishArgsOptions {
  readonly target: 'local' | 'static';
  readonly miniProgramRoot?: string;
  readonly outputPath?: string;
  readonly clean?: boolean;
  readonly json?: boolean;
  readonly mpBuildScript?: string;
}

export interface PreviewArgsOptions {
  readonly deviceId: string;
  readonly miniProgramRoot?: string;
  readonly mpBuildScript?: string;
}

export interface WorkspaceMiniProgramArgsOptions {
  readonly miniProgramRoot?: string;
}

export interface BuildArgsOptions extends WorkspaceMiniProgramArgsOptions {
  readonly mpBuildScript?: string;
}

export interface EmbedInitArgsOptions {
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface HostEndpointImportArgsOptions {
  readonly partnerPackagePath: string;
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface HostEndpointAddArgsOptions {
  readonly appId: string;
  readonly title?: string;
  readonly apiBaseUrl: string;
  readonly projectRoot: string;
  readonly force?: boolean;
}

export interface HostRunArgsOptions {
  readonly deviceId: string;
  readonly projectRoot: string;
}

export interface EnvInitArgsOptions {
  readonly rootPath?: string;
  readonly useEnvironment?: string;
}

export interface EnvUseArgsOptions {
  readonly environmentName: string;
  readonly rootPath?: string;
}

export interface EnvStatusArgsOptions {
  readonly rootPath?: string;
  readonly json?: boolean;
}

export interface BackendInitArgsOptions {
  readonly backendRoot?: string;
  readonly force?: boolean;
}

export interface BackendStartArgsOptions {
  readonly backendRoot?: string;
  readonly port?: number | string;
}

export interface BackendStopArgsOptions {
  readonly backendRoot?: string;
}

export interface BackendStatusArgsOptions {
  readonly backendRoot?: string;
  readonly json?: boolean;
}

export interface PublisherBackendScaffoldArgsOptions {
  readonly miniProgramRoot?: string;
  readonly template?: 'mock';
  readonly force?: boolean;
}

export interface PublisherBackendRunArgsOptions {
  readonly miniProgramRoot?: string;
  readonly port?: number | string;
}

export interface PublisherBackendStatusArgsOptions {
  readonly miniProgramRoot?: string;
  readonly json?: boolean;
}

export interface PublisherBackendStopArgsOptions {
  readonly miniProgramRoot?: string;
}

export interface PublisherBackendUrlsArgsOptions {
  readonly port?: number | string;
}

export interface PublisherBackendContractBaseArgsOptions {
  readonly miniProgramRoot?: string;
  readonly contractPath?: string;
  readonly allowLocalHttp?: boolean;
  readonly json?: boolean;
}

export interface PublisherBackendContractInitArgsOptions
  extends PublisherBackendContractBaseArgsOptions {
  readonly publisherApiUrl: string;
  readonly appId?: string;
  readonly permissionReason?: string;
  readonly healthEndpoint?: string;
  readonly outputPath?: string;
}

export interface PublisherBackendContractValidateArgsOptions
  extends PublisherBackendContractBaseArgsOptions {}

export interface PublisherBackendContractSmokeArgsOptions
  extends PublisherBackendContractBaseArgsOptions {
  readonly authToken?: string;
  readonly timeoutSeconds?: number | string;
}

export interface PartnerPackageArgsOptions {
  readonly appId: string;
  readonly title?: string;
  readonly apiBaseUrl?: string;
  readonly outputPath?: string;
  readonly rootPath?: string;
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
  if (options.remote) {
    args.push('--remote');
  }
  return args;
}

export function buildDoctorArgs(options: DoctorArgsOptions = {}): string[] {
  const args = ['doctor'];
  if (options.json ?? true) {
    args.push('--json');
  }
  return args;
}

export function buildCapabilitiesArgs(
  options: CapabilitiesArgsOptions = {},
): string[] {
  const args = ['capabilities'];
  if (options.json ?? true) {
    args.push('--json');
  }
  return args;
}

export function buildCreateArgs(options: CreateArgsOptions): string[] {
  const args = ['create', '--output-root', options.outputRoot];
  if (options.screenFormat?.trim()) {
    args.push('--screen-format', options.screenFormat.trim());
  }
  if (options.title?.trim()) {
    args.push('--title', options.title.trim());
  }
  if (options.backendTemplate?.trim()) {
    args.push('--with-backend', options.backendTemplate.trim());
  }
  if (options.force) {
    args.push('--force');
  }
  args.push(options.appId);
  return args;
}

export function buildBuildArgs(
  options: BuildArgsOptions = {},
): string[] {
  const args = ['build'];
  if (options.mpBuildScript?.trim()) {
    args.push('--mp-build-script', options.mpBuildScript.trim());
  }
  return withMiniProgramRoot(args, options.miniProgramRoot);
}

export function buildValidateArgs(
  options: WorkspaceMiniProgramArgsOptions = {},
): string[] {
  return withMiniProgramRoot(['validate'], options.miniProgramRoot);
}

export function buildPreviewArgs(options: PreviewArgsOptions): string[] {
  const args = ['preview', '-d', options.deviceId];
  if (options.mpBuildScript?.trim()) {
    args.push('--mp-build-script', options.mpBuildScript.trim());
  }
  return withMiniProgramRoot(args, options.miniProgramRoot);
}

export function buildPublishArgs(options: PublishArgsOptions): string[] {
  const args = ['publish', '--target', options.target];
  if (options.outputPath?.trim()) {
    args.push('--output', options.outputPath.trim());
  }
  if (options.clean) {
    args.push('--clean');
  }
  if (options.json) {
    args.push('--json');
  }
  if (options.mpBuildScript?.trim()) {
    args.push('--mp-build-script', options.mpBuildScript.trim());
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
    '--artifact-base-url',
    options.apiBaseUrl,
  ];
  if (options.title?.trim()) {
    args.push('--title', options.title.trim());
  }
  args.push('--project-root', options.projectRoot);
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildHostRunArgs(options: HostRunArgsOptions): string[] {
  const args = ['host', 'run', '-d', options.deviceId, '--project-root', options.projectRoot];
  return args;
}

export function buildEnvInitArgs(options: EnvInitArgsOptions = {}): string[] {
  const args = ['env', 'init'];
  withRootPath(args, options.rootPath);
  if (options.useEnvironment?.trim()) {
    args.push('--use', options.useEnvironment.trim());
  }
  return args;
}

export function buildEnvUseArgs(options: EnvUseArgsOptions): string[] {
  const args = ['env', 'use', options.environmentName];
  return withRootPath(args, options.rootPath);
}

export function buildEnvStatusArgs(options: EnvStatusArgsOptions = {}): string[] {
  const args = ['env', 'status'];
  if (options.json ?? true) {
    args.push('--json');
  }
  return withRootPath(args, options.rootPath);
}

export function buildBackendInitArgs(options: BackendInitArgsOptions = {}): string[] {
  const args = ['artifact-host', 'init'];
  withRootPath(args, options.backendRoot);
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildBackendStartArgs(options: BackendStartArgsOptions = {}): string[] {
  const args = ['artifact-host', 'start'];
  withRootPath(args, options.backendRoot);
  if (options.port !== undefined && `${options.port}`.trim()) {
    args.push('--port', `${options.port}`.trim());
  }
  return args;
}

export function buildBackendStopArgs(options: BackendStopArgsOptions = {}): string[] {
  const args = ['artifact-host', 'stop'];
  return withRootPath(args, options.backendRoot);
}

export function buildBackendStatusArgs(options: BackendStatusArgsOptions = {}): string[] {
  const args = ['artifact-host', 'status'];
  if (options.json ?? true) {
    args.push('--json');
  }
  return withRootPath(args, options.backendRoot);
}

export function buildPublisherBackendScaffoldArgs(
  options: PublisherBackendScaffoldArgsOptions = {},
): string[] {
  const args = ['publisher-api', 'scaffold'];
  args.push('--template', options.template ?? 'mock');
  withMiniProgramRoot(args, options.miniProgramRoot);
  if (options.force) {
    args.push('--force');
  }
  return args;
}

export function buildPublisherBackendRunArgs(
  options: PublisherBackendRunArgsOptions = {},
): string[] {
  const args = ['publisher-api', 'run'];
  withMiniProgramRoot(args, options.miniProgramRoot);
  if (options.port !== undefined && `${options.port}`.trim()) {
    args.push('--port', `${options.port}`.trim());
  }
  return args;
}

export function buildPublisherBackendStatusArgs(
  options: PublisherBackendStatusArgsOptions = {},
): string[] {
  const args = ['publisher-api', 'status'];
  if (options.json ?? true) {
    args.push('--json');
  }
  return withMiniProgramRoot(args, options.miniProgramRoot);
}

export function buildPublisherBackendStopArgs(
  options: PublisherBackendStopArgsOptions = {},
): string[] {
  return withMiniProgramRoot(['publisher-api', 'stop'], options.miniProgramRoot);
}

export function buildPublisherBackendUrlsArgs(
  options: PublisherBackendUrlsArgsOptions = {},
): string[] {
  const args = ['publisher-api', 'urls'];
  if (options.port !== undefined && `${options.port}`.trim()) {
    args.push('--port', `${options.port}`.trim());
  }
  return args;
}

export function buildPublisherBackendContractInitArgs(
  options: PublisherBackendContractInitArgsOptions,
): string[] {
  const args = [
    'publisher-api',
    'contract',
    'init',
    '--publisher-api-url',
    options.publisherApiUrl.trim(),
  ];
  if (options.appId?.trim()) {
    args.push('--app-id', options.appId.trim());
  }
  if (options.permissionReason?.trim()) {
    args.push('--permission-reason', options.permissionReason.trim());
  }
  if (options.healthEndpoint?.trim()) {
    args.push('--health-endpoint', options.healthEndpoint.trim());
  }
  if (options.outputPath?.trim()) {
    args.push('--output', options.outputPath.trim());
  }
  return withPublisherBackendContractOptions(args, options);
}

export function buildPublisherBackendContractValidateArgs(
  options: PublisherBackendContractValidateArgsOptions = {},
): string[] {
  return withPublisherBackendContractOptions(
    ['publisher-api', 'contract', 'validate'],
    options,
  );
}

export function buildPublisherBackendContractSmokeArgs(
  options: PublisherBackendContractSmokeArgsOptions = {},
): string[] {
  const args = ['publisher-api', 'contract', 'smoke'];
  if (options.authToken?.trim()) {
    args.push('--auth-token', options.authToken.trim());
  }
  if (options.timeoutSeconds !== undefined && `${options.timeoutSeconds}`.trim()) {
    args.push('--timeout-seconds', `${options.timeoutSeconds}`.trim());
  }
  return withPublisherBackendContractOptions(args, options);
}

export function buildPartnerPackageArgs(
  options: PartnerPackageArgsOptions,
): string[] {
  const args = [
    'partner',
    'package',
    options.appId,
  ];
  if (options.title?.trim()) {
    args.push('--title', options.title.trim());
  }
  if (options.apiBaseUrl?.trim()) {
    args.push('--artifact-base-url', options.apiBaseUrl.trim());
  }
  if (options.outputPath?.trim()) {
    args.push('--output', options.outputPath.trim());
  }
  return withRootPath(args, options.rootPath);
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
    const invocation = resolveCliInvocation(command, args);
    const child = spawn(invocation.command, invocation.args, {
      cwd: options.cwd,
      shell: invocation.shell,
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

    child.stdout?.on('data', (data: { toString(): string }) => {
      const chunk = data.toString();
      stdout += chunk;
      options.onStdout?.(chunk);
    });
    child.stderr?.on('data', (data: { toString(): string }) => {
      const chunk = data.toString();
      stderr += chunk;
      options.onStderr?.(chunk);
    });
    child.on('error', (error: Error) => {
      if (settled) {
        return;
      }
      settled = true;
      if (timer) {
        clearTimeout(timer);
      }
      reject(error);
    });
    child.on('close', (exitCode: number | null) => {
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

export function resolveCliInvocation(
  command: string,
  args: readonly string[],
): {
  readonly command: string;
  readonly args: readonly string[];
  readonly shell: boolean;
} {
  if (process.platform === 'win32' && command.trim().toLowerCase() === defaultCliPath) {
    const miniprogramShim = findWindowsExecutable([
      'miniprogram.bat',
      'miniprogram.cmd',
      'miniprogram.exe',
    ]);
    if (miniprogramShim) {
      return {
        command: process.env.ComSpec || 'cmd.exe',
        args: ['/d', '/c', 'call', miniprogramShim, ...args],
        shell: false,
      };
    }
    const commandLine = formatCommandLine(command, args);
    return {
      command: commandLine,
      args: [],
      shell: true,
    };
  }
  const useShell = process.platform === 'win32';
  return {
    command: useShell ? formatCommandLine(command, args) : command,
    args: useShell ? [] : [...args],
    shell: useShell,
  };
}

function findWindowsExecutable(fileNames: readonly string[]): string | undefined {
  const pathEntries = (process.env.PATH ?? '')
    .split(path.delimiter)
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  for (const entry of pathEntries) {
    for (const fileName of fileNames) {
      const candidate = path.join(entry, fileName);
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }
  }
  return undefined;
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

function withRootPath(args: string[], rootPath?: string): string[] {
  if (rootPath?.trim()) {
    args.push('--root', rootPath.trim());
  }
  return args;
}

function withPublisherBackendContractOptions(
  args: string[],
  options: PublisherBackendContractBaseArgsOptions,
): string[] {
  if (options.contractPath?.trim()) {
    args.push('--contract', options.contractPath.trim());
  }
  if (options.allowLocalHttp) {
    args.push('--allow-local-http');
  }
  if (options.json ?? false) {
    args.push('--json');
  }
  return withMiniProgramRoot(args, options.miniProgramRoot);
}

function redactSecretArgs(args: readonly string[]): string[] {
  const secretOptions = new Set(['--auth-token']);
  const redacted = [...args];
  for (let index = 0; index < redacted.length; index += 1) {
    if (secretOptions.has(redacted[index]) && index + 1 < redacted.length) {
      redacted[index + 1] = '<redacted>';
    } else if (redacted[index].startsWith('--auth-token=')) {
      redacted[index] = '--auth-token=<redacted>';
    }
  }
  return redacted;
}
