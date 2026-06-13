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

  assert.equal(manifest.version, '0.3.1');
  const contributedCommands = [
    'miniProgramTools.publisherBackendSetup',
    'miniProgramTools.publisherBackendRun',
    'miniProgramTools.publisherBackendStatus',
    'miniProgramTools.publisherBackendStop',
    'miniProgramTools.copyPublisherBackendUrls',
    'miniProgramTools.copyMockBackendHostCommand',
    'miniProgramTools.publisherBackendContractInit',
    'miniProgramTools.publisherBackendContractValidate',
    'miniProgramTools.publisherBackendContractSmoke',
    'miniProgramTools.publisherBackendContractHandoff',
    'miniProgramTools.publishFirebaseHostingMiniProgram',
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
    'miniProgramTools.publisherBackendContractHandoff',
    'miniProgramTools.publishFirebaseHostingMiniProgram',
  ]) {
    assert.equal(titleMenuIds.has(commandId), true, `${commandId} is in sidebar`);
  }

  for (const commandId of [
    'miniProgramTools.publisherBackendAwsDeploy',
    'miniProgramTools.publisherBackendAwsOutputs',
    'miniProgramTools.publisherBackendFirebaseDeploy',
    'miniProgramTools.publisherBackendFirebaseHostCommand',
    'miniProgramTools.publisherBackendFirebaseHandoff',
    'miniProgramTools.publisherBackendFirebaseStarterUi',
    'miniProgramTools.publisherBackendFirebaseAuthStatus',
  ]) {
    assert.equal(commandIds.has(commandId), false, `${commandId} is removed`);
    assert.equal(titleMenuIds.has(commandId), false, `${commandId} is not in sidebar`);
  }
});
