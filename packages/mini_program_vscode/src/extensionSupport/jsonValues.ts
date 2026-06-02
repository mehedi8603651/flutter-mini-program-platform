import * as path from 'path';

import {
  DiagnosticScope,
} from '../diagnostics';

export function diagnosticCommandTitle(scope: DiagnosticScope): string {
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

export function parseJsonObject(rawOutput: string): Record<string, unknown> {
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

export function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

export function booleanValue(value: unknown): boolean | undefined {
  return typeof value === 'boolean' ? value : undefined;
}

export function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

export function recordValue(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

export function stringArrayValue(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

export function compactTimestamp(value: Date): string {
  return value
    .toISOString()
    .replace(/[-:]/g, '')
    .replace(/\.\d{3}Z$/, 'Z');
}

export function safeFileSegment(value: string): string {
  return value.replace(/[^A-Za-z0-9_.-]+/g, '_') || 'mini_program';
}

export function validateAppId(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return 'App ID is required.';
  }
  if (!/^[a-z][a-z0-9_]*$/.test(trimmed)) {
    return 'Use lowercase letters, numbers, and underscores, starting with a letter.';
  }
  return undefined;
}

export function validateEnvironmentName(value: string): string | undefined {
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

export function validateOptionalEnvironmentName(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }
  if (!/^[a-z][a-z0-9_-]*$/.test(trimmed)) {
    return 'Use lowercase letters, numbers, underscores, or hyphens, starting with a letter.';
  }
  return undefined;
}

export function validateOptionalSafeSegment(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }
  if (!/^[a-z0-9][a-z0-9-]{2,62}$/.test(trimmed)) {
    return 'Use a Firebase Hosting site id, such as lowercase letters, numbers, and hyphens.';
  }
  return undefined;
}

export function validateAbsoluteUrl(value: string): string | undefined {
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

export function validateOptionalAbsoluteUrl(value: string): string | undefined {
  return value.trim() ? validateAbsoluteUrl(value) : undefined;
}

export function validatePort(value: string): string | undefined {
  const parsed = Number.parseInt(value.trim(), 10);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    return 'Port must be 1-65535.';
  }
  return undefined;
}

export function validateRedemptionLimit(value: string): string | undefined {
  const parsed = Number.parseInt(value.trim(), 10);
  return Number.isInteger(parsed) && parsed >= 1 && parsed <= 500
    ? undefined
    : 'Limit must be between 1 and 500.';
}

export function validateOptionalIsoDateTime(value: string): string | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }
  const parsed = Date.parse(trimmed);
  return Number.isFinite(parsed)
    ? undefined
    : 'Use an ISO-8601 date/time, for example 2026-12-31T23:59:59Z.';
}

export function extractAccessKey(output: string): string | undefined {
  return /Access key(?: \(shown once\))?:\s*([A-Za-z0-9._-]{24,128})/.exec(output)?.[1];
}

export function validatePartnerPackageJson(decoded: unknown): string[] {
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

export function titleFromAppId(appId: string): string {
  return appId
    .split(/[._-]+/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export function resolveCreateOutputRoot(selectedFolder: string, appId: string): string {
  return path.basename(selectedFolder).toLowerCase() === appId.toLowerCase()
    ? selectedFolder
    : path.join(selectedFolder, appId);
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      return 'MiniProgram CLI was not found. Install it with `dart pub global activate mini_program_tooling` or set miniProgram.cliPath.';
    }
    return error.message;
  }
  return String(error);
}
