export interface WorkflowStatusReport {
  readonly schemaVersion: number;
  readonly command: string;
  readonly generatedAtUtc?: string;
  readonly workspace?: Record<string, unknown>;
  readonly environment?: Record<string, unknown>;
  readonly miniProgram?: Record<string, unknown>;
  readonly hostApp?: Record<string, unknown>;
  readonly backend?: Record<string, unknown>;
  readonly remote?: Record<string, unknown>;
  readonly ready?: boolean;
  readonly severity?: string;
  readonly nextActions?: unknown[];
  readonly [key: string]: unknown;
}

export function parseWorkflowStatusJson(rawOutput: string): WorkflowStatusReport {
  const jsonText = extractJsonObject(rawOutput);
  const decoded: unknown = JSON.parse(jsonText);
  if (!isRecord(decoded)) {
    throw new Error('Workflow status did not return a JSON object.');
  }
  if (decoded.schemaVersion !== 1) {
    throw new Error('Unsupported workflow status schema version.');
  }
  if (decoded.command !== 'workflow status') {
    throw new Error('Unexpected workflow status command payload.');
  }
  return decoded as WorkflowStatusReport;
}

export function asRecord(value: unknown): Record<string, unknown> {
  return isRecord(value) ? value : {};
}

export function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

export function asBoolean(value: unknown, fallback = false): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

export function asNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' ? value : fallback;
}

export function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function extractJsonObject(rawOutput: string): string {
  const trimmed = rawOutput.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    return trimmed;
  }
  const start = trimmed.indexOf('{');
  const end = trimmed.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new Error('Workflow status output did not contain JSON.');
  }
  return trimmed.slice(start, end + 1);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
