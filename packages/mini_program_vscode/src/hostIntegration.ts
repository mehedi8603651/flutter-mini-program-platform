export interface MiniProgramRegistryEntry {
  readonly appId: string;
  readonly title: string;
}

export function parseEndpointAppIds(source: string): string[] {
  const fromJson = parseEndpointAppIdsFromGeneratedJson(source);
  if (fromJson.length > 0) {
    return fromJson;
  }

  return unique(
    [...source.matchAll(/["']([a-z][a-z0-9_]*)["']\s*:\s*MiniProgramEndpoint\s*\(/g)]
      .map((match) => match[1])
      .filter(Boolean),
  );
}

export function parseRegistryEntries(source: string): MiniProgramRegistryEntry[] {
  const entries: MiniProgramRegistryEntry[] = [];
  const pattern =
    /static\s+const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*MiniProgramInfo\s*\(\s*appId:\s*['"]([^'"]+)['"]\s*,\s*title:\s*['"]([^'"]+)['"]\s*,?\s*\)/gs;
  for (const match of source.matchAll(pattern)) {
    entries.push({ appId: match[2], title: match[3] });
  }
  return entries;
}

export function buildRegistryFile(
  entries: readonly MiniProgramRegistryEntry[] = [],
): string {
  const normalizedEntries = normalizeEntries(entries);
  const entrySource = normalizedEntries
    .map((entry) => registryEntrySource(entry))
    .join('\n\n');

  return `class MiniProgramInfo {
  const MiniProgramInfo({
    required this.appId,
    required this.title,
  });

  final String appId;
  final String title;
}

class MiniPrograms {
  const MiniPrograms._();
${entrySource ? `\n${indentBlock(entrySource, 2)}\n` : ''}
}
`;
}

export function upsertRegistryEntry(
  source: string | undefined,
  entry: MiniProgramRegistryEntry,
): string {
  const existing = source?.trim() ? parseRegistryEntries(source) : [];
  const entries = normalizeEntries([
    ...existing.filter((item) => item.appId !== entry.appId),
    entry,
  ]);
  return buildRegistryFile(entries);
}

export function dartFieldNameFromAppId(appId: string): string {
  const parts = appId
    .split(/[^A-Za-z0-9]+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const fallback = 'miniProgram';
  if (parts.length === 0) {
    return fallback;
  }
  const [first, ...rest] = parts;
  const fieldName = [
    first.toLowerCase(),
    ...rest.map((part) => part.charAt(0).toUpperCase() + part.slice(1)),
  ].join('');
  return /^[A-Za-z_$]/.test(fieldName) ? fieldName : fallback;
}

export function titleFromAppId(appId: string): string {
  return appId
    .split(/[._-]+/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export function buildDemoHostButtonSnippet(
  entry: MiniProgramRegistryEntry,
  options: { readonly useRegistry: boolean },
): string {
  const label = escapeDartSingleQuotedString(`Open ${entry.title} MiniProgram`);
  if (options.useRegistry) {
    const fieldName = dartFieldNameFromAppId(entry.appId);
    return `FilledButton(
  onPressed: () {
    openAppMiniProgram(
      context,
      appId: MiniPrograms.${fieldName}.appId,
      title: MiniPrograms.${fieldName}.title,
    );
  },
  child: const Text('${label}'),
)`;
  }
  return `FilledButton(
  onPressed: () {
    openAppMiniProgram(
      context,
      appId: '${escapeDartSingleQuotedString(entry.appId)}',
      title: '${escapeDartSingleQuotedString(entry.title)}',
    );
  },
  child: const Text('${label}'),
)`;
}

export function endpointLaunchUsageMissing(
  dartSources: readonly { readonly path: string; readonly source: string }[],
  appIds: readonly string[],
): string[] {
  return appIds.filter((appId) => {
    const fieldName = dartFieldNameFromAppId(appId);
    return !dartSources.some(({ path, source }) => {
      const normalizedPath = path.replace(/\\/g, '/');
      if (
        normalizedPath.endsWith('/mini_program_endpoints.dart') ||
        normalizedPath.endsWith('/mini_program_registry.dart')
      ) {
        return false;
      }
      return (
        source.includes(`appId: '${appId}'`) ||
        source.includes(`appId: "${appId}"`) ||
        source.includes(`MiniPrograms.${fieldName}`)
      );
    });
  });
}

export function buildPublisherCommandTemplate(options: {
  readonly appId?: string;
  readonly title?: string;
  readonly envName?: string;
}): string {
  const appId = options.appId || '<appId>';
  const title = options.title || titleFromAppId(appId);
  const envName = options.envName || 'my-aws-prod';
  return [
    'miniprogram build',
    'miniprogram validate',
    `miniprogram publish --target cloud --env ${envName}`,
    `miniprogram access-key create ${appId} --key-id host-a --env ${envName}`,
    `miniprogram partner package ${appId} --title "${title}" --access-key <ACCESS_KEY> --env ${envName} --output ${appId}.partner.json`,
  ].join('\n');
}

export function buildHostCommandTemplate(options: {
  readonly projectRoot: string;
  readonly deviceId?: string;
}): string {
  const projectRoot = options.projectRoot;
  const deviceId = options.deviceId || 'emulator-5554';
  return [
    `miniprogram embed init --project-root "${projectRoot}"`,
    `miniprogram host endpoint import "<path-to-partner-json>" --project-root "${projectRoot}"`,
    `miniprogram host run -d ${deviceId} --project-root "${projectRoot}"`,
    'flutter build apk --release',
  ].join('\n');
}

function parseEndpointAppIdsFromGeneratedJson(source: string): string[] {
  const match = /BEGIN MINI_PROGRAM_ENDPOINTS_JSON\s*[\r\n]+\/\/\s*(\{.*?\})\s*[\r\n]+\/\/\s*END MINI_PROGRAM_ENDPOINTS_JSON/s.exec(source);
  if (!match) {
    return [];
  }
  try {
    const decoded = JSON.parse(match[1]) as Record<string, unknown>;
    return unique(Object.keys(decoded));
  } catch {
    return [];
  }
}

function normalizeEntries(
  entries: readonly MiniProgramRegistryEntry[],
): MiniProgramRegistryEntry[] {
  const byAppId = new Map<string, MiniProgramRegistryEntry>();
  for (const entry of entries) {
    if (entry.appId.trim()) {
      byAppId.set(entry.appId.trim(), {
        appId: entry.appId.trim(),
        title: entry.title.trim() || titleFromAppId(entry.appId.trim()),
      });
    }
  }
  return [...byAppId.values()].sort((left, right) =>
    left.appId.localeCompare(right.appId),
  );
}

function registryEntrySource(entry: MiniProgramRegistryEntry): string {
  return `static const ${dartFieldNameFromAppId(entry.appId)} = MiniProgramInfo(
  appId: '${escapeDartSingleQuotedString(entry.appId)}',
  title: '${escapeDartSingleQuotedString(entry.title)}',
);`;
}

function indentBlock(source: string, spaces: number): string {
  const prefix = ' '.repeat(spaces);
  return source
    .split('\n')
    .map((line) => line ? `${prefix}${line}` : line)
    .join('\n');
}

function escapeDartSingleQuotedString(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function unique(values: readonly string[]): string[] {
  return [...new Set(values)];
}
