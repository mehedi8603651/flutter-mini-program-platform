import * as vscode from 'vscode';

import {
  buildCapabilitiesArgs,
  formatRedactedCommandLine,
  runCli,
} from '../cli';

import {
  errorMessage,
  parseJsonObject,
  recordValue,
  stringArrayValue,
  stringValue,
} from './jsonValues';
import { configuredCliPath } from './workspace';

export interface PublisherApiCliCapability {
  readonly checked: boolean;
  readonly supportsFirebaseHostingPublish?: boolean;
  readonly supportsPublisherApiMock?: boolean;
  readonly supportsPublisherBackendContract?: boolean;
  readonly supportsCapabilityDiscovery?: boolean;
  readonly toolingVersion?: string;
  readonly detail?: string;
}

export const publisherApiCliCapabilityCache = new Map<
  string,
  Promise<PublisherApiCliCapability>
>();

export async function detectPublisherApiCliCapabilities(
  workspacePath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherApiCliCapability> {
  const cliPath = configuredCliPath();
  const cacheKey = `${cliPath}\n${workspacePath}`;
  const cached = publisherApiCliCapabilityCache.get(cacheKey);
  if (cached) {
    return cached;
  }
  const pending = detectPublisherApiCliCapabilitiesUncached(
    workspacePath,
    cliPath,
    output,
  );
  publisherApiCliCapabilityCache.set(cacheKey, pending);
  return pending;
}

export async function detectPublisherApiCliCapabilitiesUncached(
  workspacePath: string,
  cliPath: string,
  output?: vscode.OutputChannel,
): Promise<PublisherApiCliCapability> {
  const capabilitiesArgs = buildCapabilitiesArgs({ json: true });
  output?.appendLine(`> ${formatRedactedCommandLine(cliPath, capabilitiesArgs)}`);
  try {
    const capabilitiesResult = await runCli(cliPath, capabilitiesArgs, {
      cwd: workspacePath,
      timeoutMs: 30000,
    });
    if (capabilitiesResult.exitCode === 0) {
      return capabilityFromCliCapabilitiesJson(
        parseJsonObject(capabilitiesResult.stdout),
      );
    }
    return {
      checked: true,
      supportsCapabilityDiscovery: false,
      detail: capabilitiesResult.stderr.trim() || capabilitiesResult.stdout.trim(),
    };
  } catch (error) {
    return {
      checked: true,
      supportsCapabilityDiscovery: false,
      detail: errorMessage(error),
    };
  }
}

export function capabilityFromCliCapabilitiesJson(
  decoded: Record<string, unknown>,
): PublisherApiCliCapability {
  const features = recordValue(decoded.features) ?? {};
  const capabilityIds = stringArrayValue(decoded.capabilityIds);
  const hasCapability = (id: string): boolean => capabilityIds.includes(id);
  const hasFeature = (key: string): boolean => features[key] === true;
  const supportsFirebaseHostingPublish =
    hasFeature('firebaseHostingPublish') ||
    hasCapability('publish.firebase_hosting');
  const supportsPublisherApiMock =
    hasFeature('publisherApiMock') ||
    hasCapability('publisher_api.mock.scaffold');
  const supportsPublisherBackendContract =
    (hasFeature('publisherBackendContractInit') &&
      hasFeature('publisherBackendContractValidate') &&
      hasFeature('publisherBackendContractSmoke') &&
      hasFeature('publisherBackendContractHandoff')) ||
    (hasCapability('publisher_backend.contract.init') &&
      hasCapability('publisher_backend.contract.validate') &&
      hasCapability('publisher_backend.contract.smoke') &&
      hasCapability('publisher_backend.contract.handoff')) ||
    (hasCapability('publisher_api.contract.init') &&
      hasCapability('publisher_api.contract.validate') &&
      hasCapability('publisher_api.contract.smoke') &&
      hasCapability('publisher_api.contract.handoff'));
  const details = [
    supportsFirebaseHostingPublish
      ? undefined
      : 'Configured CLI capabilities do not include Firebase Hosting publish.',
    supportsPublisherApiMock
      ? undefined
      : 'Configured CLI capabilities do not include Publisher API mock scaffold.',
    supportsPublisherBackendContract
      ? undefined
      : 'Configured CLI capabilities do not include provider-neutral Publisher API contract commands.',
  ].filter((value): value is string => Boolean(value));
  return {
    checked: true,
    supportsFirebaseHostingPublish,
    supportsPublisherApiMock,
    supportsPublisherBackendContract,
    supportsCapabilityDiscovery: true,
    toolingVersion: stringValue(decoded.toolingVersion),
    detail: details.join(' '),
  };
}

export async function ensurePublisherBackendContractCli0405(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherApiCliCapabilities(
    workspacePath,
    output,
  );
  if (
    capability.supportsPublisherBackendContract &&
    toolingVersionAtLeast(capability.toolingVersion, '0.4.0')
  ) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.4.0 or newer is required for provider-neutral Publisher API contracts. ' +
    `${versionDetail}Use the local mini_program_tooling package.`;
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensureMpCreateCli040(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherApiCliCapabilities(
    workspacePath,
    output,
  );
  if (toolingVersionAtLeast(capability.toolingVersion, '0.4.0')) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.4.0 or newer is required for Mp JSON mini-program creation. ' +
    `${versionDetail}Use the local mini_program_tooling package.`;
  output.appendLine(message);
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export async function ensureFirebaseHostingPublishCli042(
  workspacePath: string,
  output: vscode.OutputChannel,
): Promise<boolean> {
  output.show(true);
  const capability = await detectPublisherApiCliCapabilities(
    workspacePath,
    output,
  );
  if (firebaseHostingPublishCliAccepted(capability)) {
    return true;
  }
  const versionDetail = capability.toolingVersion
    ? `Configured CLI reports mini_program_tooling ${capability.toolingVersion}. `
    : '';
  const message =
    'MiniProgram CLI 0.3.42 or newer is required for Firebase Hosting static delivery publish. ' +
    'Run `dart pub global activate mini_program_tooling 0.3.42` or use the local tooling package.';
  output.appendLine(message);
  if (versionDetail) {
    output.appendLine(versionDetail.trim());
  }
  if (capability.detail) {
    output.appendLine(capability.detail);
  }
  vscode.window.showWarningMessage(message);
  return false;
}

export function firebaseHostingPublishCliAccepted(
  capability: PublisherApiCliCapability,
): boolean {
  if (!capability.supportsFirebaseHostingPublish) {
    return false;
  }
  return toolingVersionAtLeast(capability.toolingVersion, '0.3.42');
}

export function toolingVersionAtLeast(
  version: string | undefined,
  minimum: string,
): boolean {
  if (!version) {
    return false;
  }
  const currentParts = version
    .split(/[^0-9]+/)
    .filter(Boolean)
    .map((value) => Number.parseInt(value, 10));
  const minimumParts = minimum
    .split(/[^0-9]+/)
    .filter(Boolean)
    .map((value) => Number.parseInt(value, 10));
  const length = Math.max(currentParts.length, minimumParts.length);
  for (let index = 0; index < length; index += 1) {
    const current = currentParts[index] ?? 0;
    const target = minimumParts[index] ?? 0;
    if (current > target) {
      return true;
    }
    if (current < target) {
      return false;
    }
  }
  return true;
}
