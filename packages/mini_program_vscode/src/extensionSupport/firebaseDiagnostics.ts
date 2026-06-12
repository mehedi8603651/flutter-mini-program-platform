import * as http from 'http';
import * as https from 'https';
import * as vscode from 'vscode';

import {
  formatRedactedCommandLine,
  runCli,
} from '../cli';
import {
  redactSecrets,
} from '../diagnostics';
import {
  FirebaseHostEndpointStatus,
} from '../statusTreeModel';

import {
  booleanValue,
  errorMessage,
  parseJsonObject,
  stringArrayValue,
  stringValue,
} from './jsonValues';
import {
  configuredCliPath,
} from './workspace';

export async function runFirebaseHostCommandJson(
  label: string,
  args: readonly string[],
  cwd: string,
  output: vscode.OutputChannel,
): Promise<Record<string, unknown> | undefined> {
  const cliPath = configuredCliPath();
  output.show(true);
  output.appendLine('');
  output.appendLine(`> ${formatRedactedCommandLine(cliPath, args)}`);
  try {
    const result = await runCli(cliPath, args, {
      cwd,
      timeoutMs: 120000,
    });
    if (result.stderr.trim()) {
      output.append(redactSecrets(result.stderr));
    }
    if (result.exitCode !== 0) {
      const detail = redactSecrets((result.stderr || result.stdout).trim());
      vscode.window.showErrorMessage(`${label} failed with exit code ${result.exitCode}.`);
      if (detail) {
        output.appendLine(detail);
      }
      return undefined;
    }
    const decoded = parseJsonObject(result.stdout);
    output.appendLine(`${label} completed.`);
    output.appendLine(
      `Host endpoint ready: ${decoded.hostEndpointReady === true ? 'yes' : 'no'}`,
    );
    if (typeof decoded.hostAuthControllerReady === 'boolean') {
      output.appendLine(
        `Host auth controller ready: ${decoded.hostAuthControllerReady === true ? 'yes' : 'no'}`,
      );
    }
    const issues = stringArrayValue(decoded.hostEndpointIssues);
    if (issues.length > 0) {
      output.appendLine(`Host endpoint issues: ${issues.join('; ')}`);
    }
    const authIssues = stringArrayValue(decoded.hostAuthIssues);
    if (authIssues.length > 0) {
      output.appendLine(`Host auth issues: ${authIssues.join('; ')}`);
    }
    return decoded;
  } catch (error) {
    const message = errorMessage(error);
    output.appendLine(message);
    vscode.window.showErrorMessage(message);
    return undefined;
  }
}

export function firebaseHostEndpointStatusFromHostCommand(
  decoded: Record<string, unknown>,
): FirebaseHostEndpointStatus {
  return {
    ready:
      typeof decoded.hostEndpointReady === 'boolean'
        ? decoded.hostEndpointReady
        : undefined,
    miniProgramId: stringValue(decoded.miniProgramId),
    hostProjectRootPath: stringValue(decoded.hostProjectRootPath),
    hostEndpointMapPath: stringValue(decoded.hostEndpointMapPath),
    deliveryApiBaseUrl: stringValue(decoded.deliveryApiBaseUrl),
    backendBaseUrl: stringValue(decoded.backendBaseUrl),
    accessMode: stringValue(decoded.accessMode),
    hostEndpointBackendMode: stringValue(decoded.hostEndpointBackendMode),
    hostEndpointIssues: stringArrayValue(decoded.hostEndpointIssues),
    hostAuthControllerReady: booleanValue(decoded.hostAuthControllerReady),
    hostRuntimeSetupPath: stringValue(decoded.hostRuntimeSetupPath),
    hostAuthControllerConfigured: booleanValue(decoded.hostAuthControllerConfigured),
    hostSecureAuthControllerConfigured: booleanValue(decoded.hostSecureAuthControllerConfigured),
    hostDisposeAuthControllerConfigured: booleanValue(decoded.hostDisposeAuthControllerConfigured),
    hostAuthIssues: stringArrayValue(decoded.hostAuthIssues),
  };
}

export async function withFirebaseHostingDeliveryDiagnostics(
  status: FirebaseHostEndpointStatus,
): Promise<FirebaseHostEndpointStatus> {
  const deliveryUrl = status.deliveryApiBaseUrl;
  const appId = status.miniProgramId;
  if (!deliveryUrl || !appId || !isFirebaseHostingUrl(deliveryUrl)) {
    return status;
  }
  const manifestUrl = resolveUrl(
    deliveryUrl,
    `manifests/${appId}/latest.json`,
  );
  try {
    const response = await getTextResponse(manifestUrl);
    const allowOrigin = headerValue(
      response.headers,
      'access-control-allow-origin',
    );
    return {
      ...status,
      hostingManifestReachable: response.statusCode === 200,
      hostingCorsReady: Boolean(allowOrigin),
      hostingManifestUrl: manifestUrl,
      hostingCorsAllowOrigin: allowOrigin,
      hostingDeliveryIssue:
        response.statusCode === 200
          ? allowOrigin
            ? undefined
            : 'Missing Access-Control-Allow-Origin header. Republish with mini_program_tooling 0.3.42 or newer.'
          : `Manifest returned HTTP ${response.statusCode}.`,
    };
  } catch (error) {
    return {
      ...status,
      hostingManifestReachable: false,
      hostingCorsReady: false,
      hostingManifestUrl: manifestUrl,
      hostingDeliveryIssue: errorMessage(error),
    };
  }
}

export function appendFirebaseHostingDeliveryDiagnostics(
  output: vscode.OutputChannel,
  status: FirebaseHostEndpointStatus,
): void {
  if (!status.hostingManifestUrl) {
    return;
  }
  output.appendLine(
    `Firebase Hosting manifest reachable: ${status.hostingManifestReachable === true ? 'yes' : 'no'}`,
  );
  output.appendLine(
    `Firebase Hosting CORS ready: ${status.hostingCorsReady === true ? 'yes' : 'no'}`,
  );
  if (status.hostingDeliveryIssue) {
    output.appendLine(`Firebase Hosting issue: ${status.hostingDeliveryIssue}`);
  }
}

export function isFirebaseHostingUrl(value: string): boolean {
  try {
    const host = new URL(value).hostname.toLowerCase();
    return host.endsWith('.web.app') || host.endsWith('.firebaseapp.com');
  } catch {
    return false;
  }
}

export function resolveUrl(baseUrl: string, relativePath: string): string {
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
  return new URL(relativePath, normalizedBase).toString();
}

export async function getTextResponse(
  url: string,
): Promise<{
  readonly statusCode: number;
  readonly headers: http.IncomingHttpHeaders;
}> {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https:') ? https : http;
    const request = client.get(url, { timeout: 5000 }, (response) => {
      response.resume();
      response.on('end', () => {
        resolve({
          statusCode: response.statusCode ?? 0,
          headers: response.headers,
        });
      });
    });
    request.on('timeout', () => {
      request.destroy(new Error(`Request timed out: ${url}`));
    });
    request.on('error', reject);
  });
}

export function headerValue(
  headers: http.IncomingHttpHeaders,
  headerName: string,
): string | undefined {
  const value = headers[headerName.toLowerCase()];
  if (Array.isArray(value)) {
    return value.join(', ');
  }
  return value;
}
