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
  buildPublisherBackendAwsDeployArgs,
  buildPublisherBackendAwsDataExportArgs,
  buildPublisherBackendAwsDataImportArgs,
  buildPublisherBackendAwsDataRedemptionsArgs,
  buildPublisherBackendAwsDataStatusArgs,
  buildPublisherBackendAwsDestroyArgs,
  buildPublisherBackendAwsLogsArgs,
  buildPublisherBackendAwsOutputsArgs,
  buildPublisherBackendAwsSeedArgs,
  buildPublisherBackendAwsSmokeArgs,
  buildPublisherBackendAwsStatusArgs,
  buildPublisherBackendFirebaseDataExportArgs,
  buildPublisherBackendFirebaseDataImportArgs,
  buildPublisherBackendFirebaseDataRedemptionsArgs,
  buildPublisherBackendFirebaseDataStatusArgs,
  buildPublisherBackendFirebaseDeployArgs,
  buildPublisherBackendFirebaseDestroyArgs,
  buildPublisherBackendFirebaseHostCommandArgs,
  buildPublisherBackendFirebaseOutputsArgs,
  buildPublisherBackendFirebaseSeedArgs,
  buildPublisherBackendFirebaseSmokeArgs,
  buildPublisherBackendFirebaseStatusArgs,
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
    [scriptPath, 'Firebase Live 20260524062333', 'd:\\backend_smoke_host'],
    { timeoutMs: 30000 },
  );

  assert.equal(result.exitCode, 0);
  assert.deepEqual(JSON.parse(result.stdout.trim()), [
    'Firebase Live 20260524062333',
    'd:\\backend_smoke_host',
  ]);
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
  assert.deepEqual(
    buildCreateArgs({
      appId: 'coupon_demo',
      title: 'Coupon Demo',
      outputRoot: 'D:/work/coupon_demo',
      backendTemplate: 'mock',
    }),
    [
      'create',
      '--output-root',
      'D:/work/coupon_demo',
      '--title',
      'Coupon Demo',
      '--with-backend',
      'mock',
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
    buildEmbedInitArgs({ projectRoot: 'D:/host', withDemo: true }),
    ['embed', 'init', '--project-root', 'D:/host', '--with-demo'],
  );
  assert.deepEqual(
    buildEmbedInitArgs({ projectRoot: 'D:/host', withDemo: true, force: true }),
    ['embed', 'init', '--project-root', 'D:/host', '--with-demo', '--force'],
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
      region: 'us-central1',
      functionName: 'publisherBackend',
      functionUrl: 'https://us-central1-miniprogram-backend-test.cloudfunctions.net/publisherBackend/',
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
      '--region',
      'us-central1',
      '--function-name',
      'publisherBackend',
      '--function-url',
      'https://us-central1-miniprogram-backend-test.cloudfunctions.net/publisherBackend/',
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
  assert.deepEqual(
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      force: true,
    }),
    [
      'publisher-backend',
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
      'publisher-backend',
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
      'publisher-backend',
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
      'publisher-backend',
      'stop',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(buildPublisherBackendUrlsArgs({ port: 9091 }), [
    'publisher-backend',
    'urls',
    '--port',
    '9091',
  ]);
  assert.deepEqual(
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      template: 'aws-lambda',
      storageMode: 'dynamodb',
    }),
    [
      'publisher-backend',
      'scaffold',
      '--template',
      'aws-lambda',
      '--storage',
      'dynamodb',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendScaffoldArgs({
      miniProgramRoot: 'D:/work/coupon_demo',
      template: 'firebase-functions',
      storageMode: 'firestore',
    }),
    [
      'publisher-backend',
      'scaffold',
      '--template',
      'firebase-functions',
      '--storage',
      'firestore',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDeployArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      stackName: 'publisher-stack',
      stageName: 'dev',
      samS3Bucket: 'sam-bucket',
    }),
    [
      'publisher-backend',
      'aws',
      'deploy',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
      '--stack-name',
      'publisher-stack',
      '--stage-name',
      'dev',
      '--sam-s3-bucket',
      'sam-bucket',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsStatusArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'aws',
      'status',
      '--json',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsOutputsArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'aws',
      'outputs',
      '--json',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsSmokeArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsSmokeArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      includeWrite: true,
      writeCouponId: 'coupon-20',
      writeUserId: 'smoke-0-1-21',
    }),
    [
      'publisher-backend',
      'aws',
      'smoke',
      '--include-write',
      '--write-coupon-id',
      'coupon-20',
      '--write-user-id',
      'smoke-0-1-21',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsSeedArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'aws',
      'seed',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDataStatusArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'aws',
      'data',
      'status',
      '--json',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDataExportArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      output: 'D:/work/coupon_demo/backend/aws_lambda/exports/export.json',
      includeRedemptions: true,
    }),
    [
      'publisher-backend',
      'aws',
      'data',
      'export',
      '--include-redemptions',
      '--output',
      'D:/work/coupon_demo/backend/aws_lambda/exports/export.json',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDataImportArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      input: 'D:/work/coupon_demo/backend/aws_lambda/exports/export.json',
      includeRedemptions: true,
    }),
    [
      'publisher-backend',
      'aws',
      'data',
      'import',
      '--include-redemptions',
      '--dry-run',
      '--input',
      'D:/work/coupon_demo/backend/aws_lambda/exports/export.json',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDataRedemptionsArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      couponId: 'coupon-20',
      userId: 'smoke-user',
      limit: 25,
    }),
    [
      'publisher-backend',
      'aws',
      'data',
      'redemptions',
      '--coupon-id',
      'coupon-20',
      '--user-id',
      'smoke-user',
      '--limit',
      '25',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsLogsArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      since: '30m',
    }),
    [
      'publisher-backend',
      'aws',
      'logs',
      '--since',
      '30m',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendAwsDestroyArgs({
      envName: 'my-aws-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      yes: true,
      confirmDataLoss: true,
    }),
    [
      'publisher-backend',
      'aws',
      'destroy',
      '--yes',
      '--confirm-data-loss',
      '--env',
      'my-aws-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDeployArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'firebase',
      'deploy',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseStatusArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'firebase',
      'status',
      '--json',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseOutputsArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      json: false,
    }),
    [
      'publisher-backend',
      'firebase',
      'outputs',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseHostCommandArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      apiBaseUrl: 'https://cdn.example.com/coupon_demo',
      title: 'Coupon Demo',
      public: true,
      hostProjectRoot: 'D:/host_app',
    }),
    [
      'publisher-backend',
      'firebase',
      'host-command',
      '--api-base-url',
      'https://cdn.example.com/coupon_demo',
      '--json',
      '--title',
      'Coupon Demo',
      '--public',
      '--host-project-root',
      'D:/host_app',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseHostCommandArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      apiBaseUrl: 'https://cdn.example.com/coupon_demo',
      accessKey: 'mpk_live_secret',
      json: false,
    }),
    [
      'publisher-backend',
      'firebase',
      'host-command',
      '--api-base-url',
      'https://cdn.example.com/coupon_demo',
      '--access-key',
      'mpk_live_secret',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseSmokeArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseSmokeArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      includeWrite: true,
      writeCouponId: ' coupon-20 ',
      writeUserId: ' smoke-user ',
    }),
    [
      'publisher-backend',
      'firebase',
      'smoke',
      '--include-write',
      '--write-coupon-id',
      'coupon-20',
      '--write-user-id',
      'smoke-user',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseSeedArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'firebase',
      'seed',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDataStatusArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
    }),
    [
      'publisher-backend',
      'firebase',
      'data',
      'status',
      '--json',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDataExportArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      output: 'D:/work/coupon_demo/backend/firebase_functions/exports/data.json',
      includeRedemptions: true,
    }),
    [
      'publisher-backend',
      'firebase',
      'data',
      'export',
      '--include-redemptions',
      '--output',
      'D:/work/coupon_demo/backend/firebase_functions/exports/data.json',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDataImportArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      input: 'D:/work/coupon_demo/backend/firebase_functions/exports/data.json',
      dryRun: true,
      includeRedemptions: true,
    }),
    [
      'publisher-backend',
      'firebase',
      'data',
      'import',
      '--include-redemptions',
      '--dry-run',
      '--input',
      'D:/work/coupon_demo/backend/firebase_functions/exports/data.json',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDataRedemptionsArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      couponId: 'coupon-20',
      userId: 'smoke-user',
      limit: 25,
    }),
    [
      'publisher-backend',
      'firebase',
      'data',
      'redemptions',
      '--coupon-id',
      'coupon-20',
      '--user-id',
      'smoke-user',
      '--limit',
      '25',
      '--env',
      'my-firebase-prod',
      '--mini-program-root',
      'D:/work/coupon_demo',
    ],
  );
  assert.deepEqual(
    buildPublisherBackendFirebaseDestroyArgs({
      envName: 'my-firebase-prod',
      miniProgramRoot: 'D:/work/coupon_demo',
      yes: true,
      confirmDataLoss: true,
    }),
    [
      'publisher-backend',
      'firebase',
      'destroy',
      '--yes',
      '--confirm-data-loss',
      '--env',
      'my-firebase-prod',
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
});
