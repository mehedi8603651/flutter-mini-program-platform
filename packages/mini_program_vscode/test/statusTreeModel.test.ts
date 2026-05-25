import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildStatusTreeSections,
  flattenStatusSections,
} from '../src/statusTreeModel';
import { WorkflowStatusReport } from '../src/workflowStatus';

test('renders mini-program and host status rows', () => {
  const report: WorkflowStatusReport = {
    schemaVersion: 1,
    command: 'workflow status',
    workspace: { type: 'host_app', path: 'D:/host' },
    ready: true,
    severity: 'ok',
    hostApp: {
      detected: true,
      runtimeSetupExists: true,
      endpointMapExists: true,
      endpointCount: 2,
      endpointAppIds: ['coupon_demo', 'rewards'],
      endpoints: [
        {
          appId: 'coupon_demo',
          accessMode: 'protected',
          hasAccessKey: true,
          backendConfigured: true,
          backendMode: 'remote',
        },
        {
          appId: 'rewards',
          accessMode: 'public',
          hasAccessKey: false,
          backendConfigured: false,
          backendMode: 'none',
        },
      ],
    },
    miniProgram: {
      detected: true,
      appId: 'coupon_demo',
      version: '1.0.0',
      build: { exists: true, screenCount: 1 },
      validation: { status: 'ok' },
      partnerPackages: [],
      backendUsage: {
        usesPublisherBackend: true,
        usesBackendState: true,
      },
      publisherBackendStarter: {
        detected: true,
        template: 'aws-lambda',
        aws: {
          detected: true,
          environmentName: 'my-aws-prod',
          stackName: 'publisher-stack',
          region: 'ap-south-1',
          backendBaseUrl: 'https://api.example.com/prod/',
          healthUrl: 'https://api.example.com/prod/health',
          functionName: 'publisher-function',
        },
        firebase: {
          detected: true,
          environmentName: 'my-firebase-prod',
          projectId: 'miniprogram-backend-test',
          region: 'us-central1',
          backendBaseUrl: 'https://us-central1-miniprogram-backend-test.cloudfunctions.net/publisherBackend/',
          healthUrl: 'https://us-central1-miniprogram-backend-test.cloudfunctions.net/publisherBackend/health',
          functionName: 'publisherBackend',
          storageMode: 'firestore',
        },
      },
    },
    environment: {
      configured: true,
      selectedEnvironment: 'my-aws-prod',
      provider: 'aws',
      apiBaseUrl: 'https://api.example.com/api',
      requireAccessKeys: true,
    },
    backend: { configured: true, statusChecked: true, healthy: true },
    remote: {
      checked: true,
      provider: 'firebase',
      errors: [],
      firebase: {
        status: { healthy: true },
        dataStatus: {
          available: true,
          appRecordCount: 4,
          redemptionCount: 2,
        },
      },
    },
    nextActions: [],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.match(text, /Host app/);
  assert.match(text, /Backend usage: query\/state/);
  assert.match(text, /AWS env: my-aws-prod/);
  assert.match(text, /AWS stack: publisher-stack/);
  assert.match(text, /AWS region: ap-south-1/);
  assert.match(text, /AWS health: https:\/\/api.example.com\/prod\/health/);
  assert.match(text, /AWS function: publisher-function/);
  assert.match(text, /Firebase env: my-firebase-prod/);
  assert.match(text, /Firebase project: miniprogram-backend-test/);
  assert.match(text, /Firebase region: us-central1/);
  assert.match(text, /Firebase health: https:\/\/us-central1-miniprogram-backend-test\.cloudfunctions\.net\/publisherBackend\/health/);
  assert.match(text, /Firebase function: publisherBackend/);
  assert.match(text, /Firebase storage: firestore/);
  assert.match(text, /Endpoint count: 2/);
  assert.match(text, /Endpoint app IDs: coupon_demo, rewards/);
  assert.match(text, /Endpoint modes: coupon_demo:protected, rewards:public/);
  assert.match(text, /Publisher backends: coupon_demo:remote, rewards:none/);
  assert.match(text, /Routing: endpoint map active/);
  assert.match(text, /Backend fallback/);
  assert.match(text, /Access keys required: yes/);
  assert.match(text, /Provider: firebase/);
  assert.match(text, /Firebase healthy: yes/);
  assert.match(text, /Firestore available: yes/);
  assert.match(text, /Firestore app records: 4/);
  assert.match(text, /Firestore redemptions: 2/);
});

test('renders Firebase host endpoint readiness diagnostics', () => {
  const report: WorkflowStatusReport = {
    schemaVersion: 1,
    command: 'workflow status',
    workspace: { type: 'mini_program', path: 'D:/coupon' },
    ready: true,
    severity: 'ok',
    miniProgram: {
      detected: true,
      appId: 'coupon_demo',
      version: '1.0.0',
      build: { exists: true, screenCount: 1 },
      validation: { status: 'ok' },
      partnerPackages: [],
      backendUsage: { usesPublisherBackend: true },
      publisherBackendStarter: { detected: true, template: 'firebase-functions' },
    },
    environment: { configured: true, provider: 'firebase' },
    backend: { configured: false },
    remote: { checked: false },
    nextActions: [],
  };

  const text = flattenStatusSections(
    buildStatusTreeSections(report, {
      firebaseHostEndpoint: {
        ready: false,
        miniProgramId: 'coupon_demo',
        hostProjectRootPath: 'D:/host',
        hostEndpointMapPath: 'D:/host/lib/mini_program/mini_program_endpoints.dart',
        deliveryApiBaseUrl: 'https://cdn.example.com/coupon_demo',
        backendBaseUrl: 'https://firebase.example.com/publisherBackend',
        accessMode: 'public',
        hostEndpointBackendMode: 'remote',
        hostEndpointIssues: ['Delivery URL differs'],
        hostingManifestReachable: true,
        hostingCorsReady: false,
        hostingManifestUrl:
          'https://coupon-demo.web.app/manifests/coupon_demo/latest.json',
        hostingDeliveryIssue: 'Missing Access-Control-Allow-Origin header.',
      },
    }),
  );

  assert.match(text, /Firebase host endpoint/);
  assert.match(text, /Ready: no/);
  assert.match(text, /App ID: coupon_demo/);
  assert.match(text, /Host app: D:\/host/);
  assert.match(text, /Delivery URL: https:\/\/cdn\.example\.com\/coupon_demo/);
  assert.match(text, /Backend mode: remote/);
  assert.match(text, /Hosting manifest: yes/);
  assert.match(text, /Hosting CORS: no/);
  assert.match(text, /Missing Access-Control-Allow-Origin header/);
  assert.match(text, /Issues: Delivery URL differs/);
});

test('does not render raw access-key secrets', () => {
  const secretA = 'mpk_live_secret_a_1234567890';
  const secretB = 'mpk_live_secret_b_1234567890';
  const report: WorkflowStatusReport = {
    schemaVersion: 1,
    command: 'workflow status',
    workspace: { type: 'mini_program', path: 'D:/coupon' },
    ready: false,
    severity: 'warning',
    miniProgram: {
      detected: true,
      appId: 'coupon_demo',
      version: '1.0.0',
      build: { exists: true, screenCount: 1 },
      validation: { status: 'ok' },
      partnerPackages: [
        {
          appId: 'coupon_demo',
          hasAccessKey: true,
          accessKey: secretA,
        },
      ],
    },
    hostApp: {
      detected: true,
      endpointCount: 1,
      endpointAppIds: ['coupon_demo'],
      endpoints: [{ appId: 'coupon_demo', accessKey: secretB }],
    },
    environment: { configured: true },
    backend: { configured: false },
    remote: {
      checked: true,
      accessKeys: {
        activeCount: 1,
        keys: [{ id: 'host-a', sha256: 'sha256_should_not_render' }],
      },
    },
    nextActions: ['Run `miniprogram build`.'],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.doesNotMatch(text, new RegExp(secretA));
  assert.doesNotMatch(text, new RegExp(secretB));
  assert.doesNotMatch(text, /sha256_should_not_render/);
  assert.match(text, /Active access keys: 1/);
});
