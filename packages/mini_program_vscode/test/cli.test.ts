import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildBuildArgs,
  buildCreateArgs,
  buildPreviewArgs,
  buildPublishArgs,
  buildValidateArgs,
  buildWorkflowStatusArgs,
  defaultCliPath,
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
  assert.deepEqual(buildBuildArgs(), ['build']);
  assert.deepEqual(buildValidateArgs(), ['validate']);
  assert.deepEqual(buildPreviewArgs({ deviceId: 'emulator-5554' }), [
    'preview',
    '-d',
    'emulator-5554',
  ]);
  assert.deepEqual(
    buildPublishArgs({ target: 'cloud', envName: 'my-aws-prod' }),
    ['publish', '--target', 'cloud', '--env', 'my-aws-prod'],
  );
  assert.deepEqual(buildPublishArgs({ target: 'local' }), [
    'publish',
    '--target',
    'local',
  ]);
});
