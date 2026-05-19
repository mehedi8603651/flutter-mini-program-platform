import assert from 'node:assert/strict';
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
  buildCloudDeployArgs,
  buildCloudAppInfoArgs,
  buildCloudOutputsArgs,
  buildCloudStatusArgs,
  buildCreateArgs,
  buildDoctorArgs,
  buildEmbedCloudConfigureArgs,
  buildEmbedInitArgs,
  buildEnvConfigureAwsArgs,
  buildEnvInitArgs,
  buildEnvStatusArgs,
  buildEnvUseArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
  buildPartnerPackageArgs,
  buildPreviewArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  defaultCliPath,
  formatRedactedCommandLine,
  resolveCliPath,
} from '../src/cli';

test('CLI path falls back to miniprogram', () => {
  assert.equal(resolveCliPath(undefined), defaultCliPath);
  assert.equal(resolveCliPath(''), defaultCliPath);
  assert.equal(resolveCliPath('   '), defaultCliPath);
  assert.equal(resolveCliPath('D:/tools/miniprogram.bat'), 'D:/tools/miniprogram.bat');
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

test('builds core workflow command arguments', () => {
  assert.deepEqual(
    buildCreateArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      outputRoot: 'D:/work/coupon_demo',
    }),
    [
      'create',
      '--output-root',
      'D:/work/coupon_demo',
      '--title',
      'Coupon Demo',
      'coupon_demo',
    ],
  );
  assert.deepEqual(buildBuildArgs({ miniProgramRoot: 'D:/work/coupon_demo' }), [
    'build',
    '--mini-program-root',
    'D:/work/coupon_demo',
  ]);
  assert.deepEqual(
    buildValidateArgs({ miniProgramRoot: 'D:/work/coupon_demo' }),
    ['validate', '--mini-program-root', 'D:/work/coupon_demo'],
  );
  assert.deepEqual(
    buildPreviewArgs({
      deviceId: 'emulator-5554',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'preview',
      '-d',
      'emulator-5554',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublishArgs({
      target: 'cloud',
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publish',
      '--target',
      'cloud',
      '--env',
      'my-aws-prod',
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
      apiBaseUrl: 'https://api.example.com/prod/api',
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

test('builds backend command arguments', () => {
  assert.deepEqual(buildBackendInitArgs(), ['backend', 'init']);
  assert.deepEqual(
    buildBackendInitArgs({ backendRoot: 'D:/backend', force: true }),
    ['backend', 'init', '--root', 'D:/backend', '--force'],
  );
  assert.deepEqual(
    buildBackendStartArgs({ backendRoot: 'D:/backend', port: 8081 }),
    ['backend', 'start', '--root', 'D:/backend', '--port', '8081'],
  );
  assert.deepEqual(buildBackendStopArgs({ backendRoot: 'D:/backend' }), [
    'backend',
    'stop',
    '--root',
    'D:/backend',
  ]);
  assert.deepEqual(buildBackendStatusArgs({ backendRoot: 'D:/backend' }), [
    'backend',
    'status',
    '--json',
    '--root',
    'D:/backend',
  ]);
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
    }),
    [
      'partner',
      'package',
      'gcp_rewards',
      '--access-key',
      'mpk_live_secret',
      '--api-base-url',
      'https://api.example.com/api',
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
});
