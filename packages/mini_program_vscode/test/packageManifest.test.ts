import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const packageJsonPath = path.resolve(__dirname, '..', '..', 'package.json');

test('package manifest exposes cloud publisher backend commands', () => {
  const manifest = JSON.parse(readFileSync(packageJsonPath, 'utf8')) as {
    readonly version: string;
    readonly contributes?: {
      readonly commands?: Array<{ readonly command?: string }>;
      readonly menus?: {
        readonly 'view/title'?: Array<{ readonly command?: string }>;
      };
    };
  };
  const commandIds = new Set(
    (manifest.contributes?.commands ?? []).map((command) => command.command),
  );
  const titleMenuIds = new Set(
    (manifest.contributes?.menus?.['view/title'] ?? []).map(
      (entry) => entry.command,
    ),
  );

  assert.equal(manifest.version, '0.1.32');
  for (const commandId of [
    'miniProgramTools.publisherBackendAwsOutputs',
    'miniProgramTools.publisherBackendAwsSmoke',
    'miniProgramTools.publisherBackendAwsSmokeWrite',
    'miniProgramTools.publisherBackendAwsSeed',
    'miniProgramTools.publisherBackendAwsDataStatus',
    'miniProgramTools.publisherBackendAwsDataExport',
    'miniProgramTools.publisherBackendAwsDataImportDryRun',
    'miniProgramTools.publisherBackendAwsDataRedemptions',
    'miniProgramTools.publisherBackendAwsDestroy',
    'miniProgramTools.configureFirebaseEnvironment',
    'miniProgramTools.publisherBackendFirebaseDeploy',
    'miniProgramTools.publisherBackendFirebaseStatus',
    'miniProgramTools.publisherBackendFirebaseOutputs',
    'miniProgramTools.publisherBackendFirebaseHostCommand',
    'miniProgramTools.publisherBackendFirebaseHandoff',
    'miniProgramTools.publishFirebaseHostingMiniProgram',
    'miniProgramTools.publisherBackendFirebaseSmoke',
    'miniProgramTools.publisherBackendFirebaseSmokeWrite',
    'miniProgramTools.publisherBackendFirebaseSeed',
    'miniProgramTools.publisherBackendFirebaseDataStatus',
    'miniProgramTools.publisherBackendFirebaseDataExport',
    'miniProgramTools.publisherBackendFirebaseDataImportDryRun',
    'miniProgramTools.publisherBackendFirebaseDataRedemptions',
    'miniProgramTools.publisherBackendFirebaseDestroy',
  ]) {
    assert.equal(commandIds.has(commandId), true, `${commandId} is contributed`);
    if (commandId !== 'miniProgramTools.configureFirebaseEnvironment') {
      assert.equal(titleMenuIds.has(commandId), true, `${commandId} is in sidebar`);
    }
  }
});
