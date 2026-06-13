import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  buildAccessKeyCreateArgs,
  buildAccessKeyListArgs,
  buildAccessKeyRevokeArgs,
  buildAccessKeyRotateArgs,
  buildBackendInitArgs,
  buildBackendStartArgs,
  buildBackendStatusArgs,
  buildBackendStopArgs,
  buildBuildArgs,
  buildCapabilitiesArgs,
  buildCloudDeployArgs,
  buildCloudAppInfoArgs,
  buildCloudOutputsArgs,
  buildCloudStatusArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedCloudConfigureArgs,
  buildEmbedInitArgs,
  buildEnvConfigureAwsArgs,
  buildEnvConfigureFirebaseArgs,
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
  buildPreviewArgs,
  buildPublisherBackendRunArgs,
  buildPublisherBackendContractHandoffArgs,
  buildPublisherBackendContractInitArgs,
  buildPublisherBackendContractSmokeArgs,
  buildPublisherBackendContractValidateArgs,
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
    'handoff',
    '--title',
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

test('builds workflow status command arguments', () => {
  assert.deepEqual(buildWorkflowStatusArgs({ workspacePath: 'D:/app' }), [
    'workflow',
    'status',
    '--workspace',
    'D:/app',
    '--json',
  ]);
  assert.deepEqual(
    buildWorkflowStatusArgs({
      workspacePath: 'D:/app',
      envName: 'my-aws-prod',
      remote: true,
    }),
    [
      'workflow',
      'status',
      '--workspace',
      'D:/app',
      '--json',
      '--env',
      'my-aws-prod',
      '--remote',
    ],
  );
});

test('builds doctor command arguments', () => {
  assert.deepEqual(buildDoctorArgs(), ['doctor', '--json']);
  assert.deepEqual(buildDoctorArgs({ json: false }), ['doctor']);
});

test('builds capabilities command arguments', () => {
  assert.deepEqual(buildCapabilitiesArgs(), ['capabilities', '--json']);
  assert.deepEqual(buildCapabilitiesArgs({ json: false }), ['capabilities']);
});

test('builds core workflow command arguments', () => {
  assert.deepEqual(
    buildCreateArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      outputRoot: 'D:/work/coupon_demo',
      screenFormat: 'mp',
    }),
    [
      'create',
      '--output-root',
      'D:/work/coupon_demo',
      '--screen-format',
      'mp',
      '--title',
      'Coupon Demo',
      'coupon_demo',
    ],
  );
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
  assert.deepEqual(
    buildBuildArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      mpBuildScript: 'D:/work/coupon_demo/tool/custom_build.dart',
    }),
    [
      'build',
      '--mp-build-script',
      'D:/work/coupon_demo/tool/custom_build.dart',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildValidateArgs({ miniProgramRoot: 'D:/work/coupon_demo' }),
    ['validate', '--mini-program-root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(
    buildPreviewArgs({
      deviceId: 'emulator-5554',
      miniProgramRoot: 'D:/work/coupon_demo',
      mpBuildScript: 'D:/work/coupon_demo/tool/custom_build.dart',
    }),
    [
      'preview',
      '-d',
      'emulator-5554',
      '--mp-build-script',
      'D:/work/coupon_demo/tool/custom_build.dart',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublishArgs({
      target: 'cloud',
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      mpBuildScript: 'D:/work/coupon_demo/tool/custom_build.dart',
    }),
    [
      'publish',
      '--target',
      'cloud',
      '--env',
      'my-aws-prod',
      '--mp-build-script',
      'D:/work/coupon_demo/tool/custom_build.dart',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(buildPublishArgs({ target: 'local' }), [
    'publish',
    '--target',
    'local',
  ]);
  assert.deepEqual(
    buildPublishArgs({
      target: 'static',
      outputPath: 'D:/public_mini_program',
      miniProgramRoot: 'D:/work/coupon_demo',
      clean: true,
    }),
    [
      'publish',
      '--target',
      'static',
      '--output',
      'D:/public_mini_program',
      '--clean',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublishArgs({
      target: 'firebase-hosting',
      envName: 'my-firebase-prod',
      outputPath: 'D:/work/coupon_demo/backend/firebase_hosting/public',
      siteId: 'coupon-hosting',
      miniProgramRoot: 'D:/work/coupon_demo',
      clean: true,
      dryRun: true,
      json: true,
    }),
    [
      'publish',
      '--target',
      'firebase-hosting',
      '--env',
      'my-firebase-prod',
      '--output',
      'D:/work/coupon_demo/backend/firebase_hosting/public',
      '--site',
      'coupon-hosting',
      '--clean',
      '--dry-run',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
});

test('builds host app command arguments', () => {
  assert.deepEqual(buildEmbedInitArgs({ projectRoot: 'D:/host' }), [
    'embed',
    'init',
    '--project-root',
    'D:/host',
  ]);
  assert.deepEqual(buildEmbedInitArgs({ projectRoot: 'D:/host', force: true }), [
    'embed',
    'init',
    '--project-root',
    'D:/host',
    '--force',
  ]);
  assert.deepEqual(
    buildEmbedInitArgs({
      projectRoot: 'D:/host',
      force: true,
    }),
    [
      'embed',
      'init',
      '--project-root',
      'D:/host',
      '--force',
    ],
  );
  assert.deepEqual(
    buildEmbedCloudConfigureArgs({
      projectRoot: 'D:/host',
      envName: 'my-aws-prod',
    }),
    [
      'embed',
      'cloud',
      'configure',
      '--project-root',
      'D:/host',
      '--env',
      'my-aws-prod',
    ],
  );
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
      apiBaseUrl: 'https://api.example.com/prod/api',
      backendBaseUrl: 'https://publisher.example.com/api',
      accessKey: 'mpk_live_secret',
      projectRoot: 'D:/host',
      force: true,
    }),
    [
      'host',
      'endpoint',
      'add',
      'coupon_demo',
      '--api-base-url',
      'https://api.example.com/prod/api',
      '--title',
      'Coupon Demo',
      '--backend-base-url',
      'https://publisher.example.com/api',
      '--access-key',
      'mpk_live_secret',
      '--project-root',
      'D:/host',
      '--force',
    ],
  );
  assert.deepEqual(
    buildHostEndpointAddArgs({
      appId: 'public_coupon',
      apiBaseUrl: 'https://user.github.io/repo/public_mini_program',
      public: true,
      projectRoot: 'D:/host',
    }),
    [
      'host',
      'endpoint',
      'add',
      'public_coupon',
      '--api-base-url',
      'https://user.github.io/repo/public_mini_program',
      '--public',
      '--project-root',
      'D:/host',
    ],
  );
  assert.deepEqual(
    buildHostEndpointAddArgs({
      appId: 'coupon_app',
      title: 'Coupon App',
      apiBaseUrl: 'https://cdn.example.com/public_mini_program',
      public: true,
      backendLocalMock: true,
      backendLocalMockPort: '9091',
      projectRoot: 'D:/host',
    }),
    [
      'host',
      'endpoint',
      'add',
      'coupon_app',
      '--api-base-url',
      'https://cdn.example.com/public_mini_program',
      '--title',
      'Coupon App',
      '--backend-local-mock',
      '--backend-local-mock-port',
      '9091',
      '--public',
      '--project-root',
      'D:/host',
    ],
  );
  assert.deepEqual(
    buildHostRunArgs({
      deviceId: 'emulator-5554',
      projectRoot: 'D:/host',
      envName: 'my-aws-prod',
    }),
    [
      'host',
      'run',
      '-d',
      'emulator-5554',
      '--project-root',
      'D:/host',
      '--env',
      'my-aws-prod',
    ],
  );
});

test('builds environment and cloud command arguments', () => {
  assert.deepEqual(
    buildEnvInitArgs({
      rootPath: 'D:/work/coupon_demo',
      useEnvironment: 'my-aws-prod',
    }),
    [
      'env',
      'init',
      '--root',
      'D:/work/coupon_demo',
      '--use',
      'my-aws-prod',
    ],
  );
  assert.deepEqual(
    buildEnvConfigureAwsArgs({
      environmentName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
      bucket: 'my-bucket',
      region: 'ap-south-1',
      awsProfile: 'my-aws',
      apiBaseUrl: 'https://api.example.com/prod/api',
      stackName: 'mini-program-cloud-prod',
      stageName: 'prod',
      requireAccessKeys: true,
    }),
    [
      'env',
      'configure',
      'my-aws-prod',
      '--provider',
      'aws',
      '--bucket',
      'my-bucket',
      '--region',
      'ap-south-1',
      '--root',
      'D:/work/coupon_demo',
      '--aws-profile',
      'my-aws',
      '--api-base-url',
      'https://api.example.com/prod/api',
      '--stack-name',
      'mini-program-cloud-prod',
      '--stage-name',
      'prod',
      '--require-access-keys',
    ],
  );
  assert.deepEqual(
    buildEnvConfigureFirebaseArgs({
      environmentName: 'my-firebase-prod',
      rootPath: 'D:/work/coupon_demo',
      projectId: 'miniprogram-backend-test',
    }),
    [
      'env',
      'configure',
      'my-firebase-prod',
      '--provider',
      'firebase',
      '--project-id',
      'miniprogram-backend-test',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildEnvUseArgs({
      environmentName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
    }),
    ['env', 'use', 'my-aws-prod', '--root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(buildEnvStatusArgs({ rootPath: 'D:/work/coupon_demo' }), [
    'env',
    'status',
    '--json',
    '--root',
    'D:/work/coupon_demo',
  ]);
  assert.deepEqual(
    buildCloudDeployArgs({
      envName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
    }),
    ['cloud', 'deploy', '--env', 'my-aws-prod', '--root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(
    buildCloudStatusArgs({
      envName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
    }),
    [
      'cloud',
      'status',
      '--json',
      '--env',
      'my-aws-prod',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildCloudOutputsArgs({
      envName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
      format: 'dart-define',
    }),
    [
      'cloud',
      'outputs',
      '--format',
      'dart-define',
      '--env',
      'my-aws-prod',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildCloudAppInfoArgs({
      appId: 'coupon_demo',
      envName: 'my-aws-prod',
      rootPath: 'D:/work/coupon_demo',
    }),
    [
      'cloud',
      'app',
      'info',
      'coupon_demo',
      '--env',
      'my-aws-prod',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
});

test('builds artifact host command arguments', () => {
  assert.deepEqual(buildBackendInitArgs(), ['artifact-host', 'init']);
  assert.deepEqual(
    buildBackendInitArgs({ backendRoot: 'D:/backend', force: true }),
    ['artifact-host', 'init', '--root', 'D:/backend', '--force'],
  );
  assert.deepEqual(
    buildBackendStartArgs({ backendRoot: 'D:/backend', port: 8081 }),
    ['artifact-host', 'start', '--root', 'D:/backend', '--port', '8081'],
  );
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
    buildPublisherBackendRunArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      port: 9091,
    }),
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
    buildPublisherBackendStatusArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-api',
      'status',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendStopArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-api',
      'stop',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(buildPublisherBackendUrlsArgs({ port: 9091 }), [
    'publisher-api',
    'urls',
    '--port',
    '9091',
  ]);
  assert.deepEqual(
    buildPublisherBackendContractInitArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      backendBaseUrl: ' https://api.publisher.example/ ',
      public: true,
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
      '--public',
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
      accessKey: ' mpk_live_secret ',
      authToken: ' user_token ',
      timeoutSeconds: 45,
      json: true,
    }),
    [
      'publisher-api',
      'contract',
      'smoke',
      '--access-key',
      'mpk_live_secret',
      '--auth-token',
      'user_token',
      '--timeout-seconds',
      '45',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendContractHandoffArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      deliveryUrl: ' https://cdn.example.com/coupon_demo ',
      title: 'Coupon Demo',
      accessKey: ' mpk_live_secret ',
      outputPath: 'D:/work/coupon_demo.company-a.partner.json',
      json: true,
    }),
    [
      'publisher-api',
      'contract',
      'handoff',
      '--delivery-url',
      'https://cdn.example.com/coupon_demo',
      '--title',
      'Coupon Demo',
      '--access-key',
      'mpk_live_secret',
      '--output',
      'D:/work/coupon_demo.company-a.partner.json',
      '--json',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      template: 'mock',
    }),
    [
      'publisher-api',
      'scaffold',
      '--template',
      'mock',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
});

test('builds access-key command arguments', () => {
  assert.deepEqual(
    buildAccessKeyCreateArgs({
      appId: 'coupon_demo',
      keyId: 'host-a',
      envName: 'my-aws-prod',
    }),
    [
      'access-key',
      'create',
      'coupon_demo',
      '--key-id',
      'host-a',
      '--env',
      'my-aws-prod',
    ],
  );
  assert.deepEqual(
    buildAccessKeyListArgs({
      appId: 'coupon_demo',
      envName: 'my-aws-prod',
      json: true,
    }),
    [
      'access-key',
      'list',
      'coupon_demo',
      '--json',
      '--env',
      'my-aws-prod',
    ],
  );
  assert.deepEqual(
    buildAccessKeyRevokeArgs({
      appId: 'coupon_demo',
      keyId: 'host-a',
      envName: 'my-aws-prod',
    }),
    [
      'access-key',
      'revoke',
      'coupon_demo',
      '--key-id',
      'host-a',
      '--env',
      'my-aws-prod',
    ],
  );
  assert.deepEqual(
    buildAccessKeyRotateArgs({
      appId: 'coupon_demo',
      keyId: 'host-a',
      newKeyId: 'host-a-2026-05',
      envName: 'my-aws-prod',
    }),
    [
      'access-key',
      'rotate',
      'coupon_demo',
      '--key-id',
      'host-a',
      '--new-key-id',
      'host-a-2026-05',
      '--env',
      'my-aws-prod',
    ],
  );
});

test('builds partner package command arguments', () => {
  assert.deepEqual(
    buildPartnerPackageArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      accessKey: 'mpk_live_secret',
      envName: 'my-aws-prod',
      outputPath: 'D:/work/coupon_demo.partner.json',
      rootPath: 'D:/work/coupon_demo',
    }),
    [
      'partner',
      'package',
      'coupon_demo',
      '--access-key',
      'mpk_live_secret',
      '--title',
      'Coupon Demo',
      '--env',
      'my-aws-prod',
      '--output',
      'D:/work/coupon_demo.partner.json',
      '--root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPartnerPackageArgs({
      appId: 'gcp_rewards',
      accessKey: 'mpk_live_secret',
      apiBaseUrl: 'https://api.example.com/api',
      backendBaseUrl: 'https://publisher.example.com/api',
    }),
    [
      'partner',
      'package',
      'gcp_rewards',
      '--access-key',
      'mpk_live_secret',
      '--api-base-url',
      'https://api.example.com/api',
      '--backend-base-url',
      'https://publisher.example.com/api',
    ],
  );
  assert.deepEqual(
    buildPartnerPackageArgs({
      appId: 'public_coupon',
      public: true,
      apiBaseUrl: 'https://user.github.io/repo/public_mini_program',
      outputPath: 'D:/work/public_coupon.partner.json',
    }),
    [
      'partner',
      'package',
      'public_coupon',
      '--public',
      '--api-base-url',
      'https://user.github.io/repo/public_mini_program',
      '--output',
      'D:/work/public_coupon.partner.json',
    ],
  );
});

test('redacts access keys in command output', () => {
  const commandLine = formatRedactedCommandLine('miniprogram', [
    'host',
    'endpoint',
    'add',
    'coupon_demo',
    '--access-key',
    'mpk_live_secret_should_not_print',
  ]);

  assert.match(commandLine, /--access-key "?<redacted>"?/);
  assert.doesNotMatch(commandLine, /secret_should_not_print/);

  const hiddenKeyCommandLine = formatRedactedCommandLine('miniprogram', [
    'access-key',
    'create',
    'coupon_demo',
    '--key',
    'mpk_live_hidden_should_not_print',
  ]);
  assert.match(hiddenKeyCommandLine, /--key "?<redacted>"?/);
  assert.doesNotMatch(hiddenKeyCommandLine, /hidden_should_not_print/);

  const partnerPackageCommandLine = formatRedactedCommandLine('miniprogram', [
    'partner',
    'package',
    'coupon_demo',
    '--access-key',
    'mpk_live_partner_should_not_print',
  ]);
  assert.match(partnerPackageCommandLine, /--access-key "?<redacted>"?/);
  assert.doesNotMatch(partnerPackageCommandLine, /partner_should_not_print/);

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
