import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildBuildArgs,
  buildCreateArgs,
  buildEmbedCloudConfigureArgs,
  buildEmbedInitArgs,
  buildHostEndpointAddArgs,
  buildHostEndpointImportArgs,
  buildHostRunArgs,
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

test('builds core workflow command arguments', () => {
  assert.deepEqual(
    buildCreateArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      outputRoot: 'D:/work/coupon_demo',
    }),
    [
      'create',
      'coupon_demo',
      '--output-root',
      'D:/work/coupon_demo',
      '--title',
      'Coupon Demo',
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
});
