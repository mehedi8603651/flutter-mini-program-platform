import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const packageRoot = path.resolve(__dirname, '..', '..');
const packageJsonPath = path.join(packageRoot, 'package.json');
const extensionPath = path.join(packageRoot, 'src', 'extension.ts');

test('registers every contributed command exactly once', () => {
  const manifest = JSON.parse(readFileSync(packageJsonPath, 'utf8')) as {
    readonly contributes?: {
      readonly commands?: Array<{ readonly command?: string }>;
    };
  };
  const extensionSource = readFileSync(extensionPath, 'utf8');
  const registeredCommandIds = Array.from(
    extensionSource.matchAll(/registerCommand\('([^']+)'/g),
    (match) => match[1],
  );
  const contributedCommandIds = (manifest.contributes?.commands ?? [])
    .map((command) => command.command)
    .filter((commandId): commandId is string => Boolean(commandId));

  assert.deepEqual(
    [...new Set(registeredCommandIds)].sort(),
    [...registeredCommandIds].sort(),
    'extension.ts does not register duplicate commands',
  );
  assert.deepEqual(
    [...registeredCommandIds].sort(),
    [...contributedCommandIds].sort(),
    'extension.ts registers every command contributed by package.json',
  );
});
