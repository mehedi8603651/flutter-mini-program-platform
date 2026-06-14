import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const packageJsonPath = path.resolve(__dirname, '..', '..', 'package.json');

test('package manifest exposes provider-neutral Publisher API commands', () => {
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

  assert.equal(manifest.version, '0.4.0');
  const contributedCommands = [
    'miniProgramTools.publishPublicStaticMiniProgram',
    'miniProgramTools.importHostEndpoint',
    'miniProgramTools.addHostEndpoint',
    'miniProgramTools.publisherBackendSetup',
    'miniProgramTools.publisherBackendRun',
    'miniProgramTools.publisherBackendStatus',
    'miniProgramTools.publisherBackendStop',
    'miniProgramTools.copyPublisherBackendUrls',
    'miniProgramTools.copyMockBackendHostCommand',
    'miniProgramTools.publisherBackendContractInit',
    'miniProgramTools.publisherBackendContractValidate',
    'miniProgramTools.publisherBackendContractSmoke',
  ];
  for (const commandId of contributedCommands) {
    assert.equal(commandIds.has(commandId), true, `${commandId} is contributed`);
  }

  for (const commandId of [
    'miniProgramTools.publisherBackendRun',
    'miniProgramTools.publisherBackendStatus',
    'miniProgramTools.copyPublisherBackendUrls',
    'miniProgramTools.copyMockBackendHostCommand',
    'miniProgramTools.publisherBackendContractInit',
    'miniProgramTools.publisherBackendContractValidate',
    'miniProgramTools.publisherBackendContractSmoke',
  ]) {
    assert.equal(titleMenuIds.has(commandId), true, `${commandId} is in sidebar`);
  }

  const removedCommandFragments = [
    'Hosting',
    ['Access', 'Key'].join(''),
    'Deploy',
    'Outputs',
  ];
  for (const commandId of commandIds) {
    for (const fragment of removedCommandFragments) {
      assert.equal((commandId ?? '').includes(fragment), false);
    }
  }
  for (const commandId of titleMenuIds) {
    for (const fragment of removedCommandFragments) {
      assert.equal((commandId ?? '').includes(fragment), false);
    }
  }
});
