import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  buildBackendInitArgs,
  buildBackendStartArgs,
  buildBackendStatusArgs,
  buildBackendStopArgs,
  buildBuildArgs,
  buildCapabilitiesArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedInitArgs,
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
  buildPreviewArgs,
  buildPublisherBackendContractInitArgs,
  buildPublisherBackendContractSmokeArgs,
  buildPublisherBackendContractValidateArgs,
  buildPublisherBackendRunArgs,
  buildPublisherBackendScaffoldArgs,
  buildPublisherBackendStatusArgs,
  buildPublisherBackendStopArgs,
  buildPublisherBackendUrlsArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  defaultCliPath,
  formatRedactedCommandLine,
  resolveCliPath,
  resolveCliInvocation,
  runCli,
} from '../src/cli';

test('CLI path falls back to miniprogram', () => {
  assert.equal(resolveCliPath(undefined), defaultCliPath);
  assert.equal(resolveCliPath(''), defaultCliPath);
  assert.equal(resolveCliPath('   '), defaultCliPath);
  assert.equal(resolveCliPath('D:/tools/miniprogram.bat'), 'D:/tools/miniprogram.bat');
});

test('runCli preserves arguments with spaces', async () => {
  const tempDir = mkdtempSync(path.join(tmpdir(), 'miniprogram-vscode-cli-'));
  const scriptPath = path.join(tempDir, 'argv.js');
  writeFileSync(
    scriptPath,
    "console.log(JSON.stringify(process.argv.slice(2)));\n",
    'utf8',
  );

  const result = await runCli(
    process.execPath,
    [scriptPath, 'Publisher API Live 20260524062333', 'd:\\backend_smoke_host'],
    { timeoutMs: 30000 },
  );

  assert.equal(result.exitCode, 0);
  assert.deepEqual(JSON.parse(result.stdout.trim()), [
    'Publisher API Live 20260524062333',
    'd:\\backend_smoke_host',
  ]);
});

test('default Windows CLI invocation bypasses batch-file quoting', () => {
  const invocation = resolveCliInvocation('miniprogram', [
    'publisher-api',
    'contract',
    'smoke',
    '--auth-token',
    'Publisher API Live 20260524062333',
  ]);

  if (process.platform === 'win32') {
    if (invocation.command.toLowerCase().endsWith('cmd.exe')) {
      assert.equal(invocation.shell, false);
      assert.deepEqual(invocation.args.slice(0, 3), ['/d', '/c', 'call']);
      assert.match(String(invocation.args[3]), /miniprogram\.(bat|cmd|exe)$/i);
      assert.equal(invocation.args.at(-1), 'Publisher API Live 20260524062333');
    } else {
      assert.equal(invocation.command.includes('miniprogram'), true);
      assert.equal(invocation.shell, true);
    }
  } else {
    assert.equal(invocation.command, 'miniprogram');
    assert.equal(invocation.shell, false);
    assert.equal(invocation.args.at(-1), 'Publisher API Live 20260524062333');
  }
});

test('builds status, doctor, and capabilities command arguments', () => {
  assert.deepEqual(buildWorkflowStatusArgs({ workspacePath: 'D:/app' }), [
    'workflow',
    'status',
    '--workspace',
    'D:/app',
    '--json',
  ]);
  assert.deepEqual(
    buildWorkflowStatusArgs({ workspacePath: 'D:/app', remote: true }),
    ['workflow', 'status', '--workspace', 'D:/app', '--json', '--remote'],
  );
  assert.deepEqual(buildDoctorArgs(), ['doctor', '--json']);
  assert.deepEqual(buildDoctorArgs({ json: false }), ['doctor']);
  assert.deepEqual(buildCapabilitiesArgs(), ['capabilities', '--json']);
  assert.deepEqual(buildCapabilitiesArgs({ json: false }), ['capabilities']);
});

test('builds core mini-program command arguments', () => {
  assert.deepEqual(
    buildCreateArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      outputRoot: 'D:/work/coupon_demo',
      backendTemplate: 'mock',
      screenFormat: 'mp',
      force: true,
    }),
    [
      'create',
      '--output-root',
      'D:/work/coupon_demo',
      '--screen-format',
      'mp',
      '--title',
      'Coupon Demo',
      '--with-backend',
      'mock',
      '--force',
      'coupon_demo',
    ],
  );
  assert.deepEqual(buildBuildArgs({ miniProgramRoot: 'D:/work/coupon_demo' }), [
    'build',
    '--mini-program-root',
    'D:/work/coupon_demo',
  ]);
  assert.deepEqual(buildValidateArgs({ miniProgramRoot: 'D:/work/coupon_demo' }), [
    'validate',
    '--mini-program-root',
    'D:/work/coupon_demo',
  ]);
  assert.deepEqual(
    buildPreviewArgs({
      deviceId: 'chrome',
      miniProgramRoot: 'D:/work/coupon_demo',
      mpBuildScript: 'D:/work/coupon_demo/tool/custom_build.dart',
    }),
    [
      'preview',
      '-d',
      'chrome',
      '--mp-build-script',
      'D:/work/coupon_demo/tool/custom_build.dart',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublishArgs({
      target: 'static',
      outputPath: 'D:/public_mini_program',
      miniProgramRoot: 'D:/work/coupon_demo',
      clean: true,
      json: true,
    }),
    [
      'publish',
      '--target',
      'static',
      '--output',
      'D:/public_mini_program',
      '--clean',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(buildPublishArgs({ target: 'local' }), [
    'publish',
    '--target',
    'local',
  ]);
});

test('builds host app command arguments', () => {
  assert.deepEqual(buildEmbedInitArgs({ projectRoot: 'D:/host', force: true }), [
    'embed',
    'init',
    '--project-root',
    'D:/host',
    '--force',
  ]);
  assert.deepEqual(
    buildHostEndpointImportArgs({
      partnerPackagePath: 'D:/coupon.partner.json',
      projectRoot: 'D:/host',
      force: true,
    }),
    [
      'host',
      'endpoint',
      'import',
      'D:/coupon.partner.json',
      '--project-root',
      'D:/host',
      '--force',
    ],
  );
  assert.deepEqual(
    buildHostEndpointAddArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      apiBaseUrl: 'https://cdn.example.com/coupon_demo',
      backendBaseUrl: 'https://publisher.example.com/api',
      projectRoot: 'D:/host',
      force: true,
    }),
    [
      'host',
      'endpoint',
      'add',
      'coupon_demo',
      '--artifact-base-url',
      'https://cdn.example.com/coupon_demo',
      '--title',
      'Coupon Demo',
      '--backend-base-url',
      'https://publisher.example.com/api',
      '--project-root',
      'D:/host',
      '--force',
    ],
  );
  assert.deepEqual(
    buildHostEndpointAddArgs({
      appId: 'coupon_app',
      apiBaseUrl: 'https://cdn.example.com/public_mini_program',
      backendLocalMock: true,
      backendLocalMockPort: '9091',
      projectRoot: 'D:/host',
    }),
    [
      'host',
      'endpoint',
      'add',
      'coupon_app',
      '--artifact-base-url',
      'https://cdn.example.com/public_mini_program',
      '--backend-local-mock',
      '--backend-local-mock-port',
      '9091',
      '--project-root',
      'D:/host',
    ],
  );
  assert.deepEqual(
    buildHostRunArgs({ deviceId: 'chrome', projectRoot: 'D:/host' }),
    ['host', 'run', '-d', 'chrome', '--project-root', 'D:/host'],
  );
});

test('builds local environment command arguments', () => {
  assert.deepEqual(
    buildEnvInitArgs({ rootPath: 'D:/work/coupon_demo', useEnvironment: 'local-dev' }),
    ['env', 'init', '--root', 'D:/work/coupon_demo', '--use', 'local-dev'],
  );
  assert.deepEqual(
    buildEnvUseArgs({ environmentName: 'local-dev', rootPath: 'D:/work/coupon_demo' }),
    ['env', 'use', 'local-dev', '--root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(buildEnvStatusArgs({ rootPath: 'D:/work/coupon_demo' }), [
    'env',
    'status',
    '--json',
    '--root',
    'D:/work/coupon_demo',
  ]);
});

test('builds artifact host and Publisher API command arguments', () => {
  assert.deepEqual(buildBackendInitArgs({ backendRoot: 'D:/backend', force: true }), [
    'artifact-host',
    'init',
    '--root',
    'D:/backend',
    '--force',
  ]);
  assert.deepEqual(buildBackendStartArgs({ backendRoot: 'D:/backend', port: 8081 }), [
    'artifact-host',
    'start',
    '--root',
    'D:/backend',
    '--port',
    '8081',
  ]);
  assert.deepEqual(buildBackendStopArgs({ backendRoot: 'D:/backend' }), [
    'artifact-host',
    'stop',
    '--root',
    'D:/backend',
  ]);
  assert.deepEqual(buildBackendStatusArgs({ backendRoot: 'D:/backend' }), [
    'artifact-host',
    'status',
    '--json',
    '--root',
    'D:/backend',
  ]);
  assert.deepEqual(
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      force: true,
    }),
    [
      'publisher-api',
      'scaffold',
      '--template',
      'mock',
      '--mini-program-root',
      'D:/work/coupon_demo',
      '--force',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendRunArgs({ miniProgramRoot: 'D:/work/coupon_demo', port: 9091 }),
    [
      'publisher-api',
      'run',
      '--mini-program-root',
      'D:/work/coupon_demo',
      '--port',
      '9091',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendStatusArgs({ miniProgramRoot: 'D:/work/coupon_demo' }),
    [
      'publisher-api',
      'status',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendStopArgs({ miniProgramRoot: 'D:/work/coupon_demo' }),
    ['publisher-api', 'stop', '--mini-program-root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(buildPublisherBackendUrlsArgs({ port: 9091 }), [
    'publisher-api',
    'urls',
    '--port',
    '9091',
  ]);
});

test('builds Publisher API contract command arguments', () => {
  assert.deepEqual(
    buildPublisherBackendContractInitArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      backendBaseUrl: ' https://api.publisher.example/ ',
      healthEndpoint: ' health ',
      allowLocalHttp: true,
      json: true,
    }),
    [
      'publisher-api',
      'contract',
      'init',
      '--backend-base-url',
      'https://api.publisher.example/',
      '--health-endpoint',
      'health',
      '--allow-local-http',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendContractValidateArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      contractPath: 'D:/work/coupon_demo/publisher_backend.json',
      allowLocalHttp: true,
    }),
    [
      'publisher-api',
      'contract',
      'validate',
      '--contract',
      'D:/work/coupon_demo/publisher_backend.json',
      '--allow-local-http',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendContractSmokeArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      authToken: ' user_token ',
      timeoutSeconds: 45,
      json: true,
    }),
    [
      'publisher-api',
      'contract',
      'smoke',
      '--auth-token',
      'user_token',
      '--timeout-seconds',
      '45',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
});

test('builds partner package command arguments', () => {
  assert.deepEqual(
    buildPartnerPackageArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      apiBaseUrl: 'https://cdn.example.com/coupon_demo',
      outputPath: 'D:/work/coupon_demo.partner.json',
      rootPath: 'D:/work/coupon_demo',
    }),
    [
      'partner',
      'package',
      'coupon_demo',
      '--title',
      'Coupon Demo',
      '--artifact-base-url',
      'https://cdn.example.com/coupon_demo',
      '--output',
      'D:/work/coupon_demo.partner.json',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
});

test('redacts auth tokens in command output', () => {
  const smokeTokenCommandLine = formatRedactedCommandLine('miniprogram', [
    'publisher-api',
    'contract',
    'smoke',
    '--auth-token',
    'id_token_should_not_print',
  ]);
  assert.match(smokeTokenCommandLine, /--auth-token "?<redacted>"?/);
  assert.doesNotMatch(smokeTokenCommandLine, /id_token_should_not_print/);
});
