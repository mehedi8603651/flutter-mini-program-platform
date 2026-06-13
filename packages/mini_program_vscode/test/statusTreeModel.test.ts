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
      screenFormat: 'mp',
      screenSchemaVersion: 1,
      sourceRootPath: 'D:/coupon/mp',
      outputRootPath: 'D:/coupon/mp/.build',
      build: {
        exists: true,
        screenCount: 1,
        entryScreenPath: 'D:/coupon/mp/.build/screens/coupon_demo_home.json',
        entryScreenExists: true,
      },
      validation: { status: 'ok' },
      partnerPackages: [],
      backendUsage: {
        usesPublisherBackend: true,
        usesBackendState: true,
      },
      publisherBackendStarter: {
        detected: true,
        template: 'mock',
        expectedRoutes: [
          'GET /health',
          'GET /coupons/list',
          'GET /coupons/page',
        ],
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
      provider: 'aws',
      errors: [],
    },
    nextActions: [],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.match(text, /Host app/);
  assert.doesNotMatch(text, /Legacy Stac adapter/);
  assert.doesNotMatch(text, /Legacy dependency/);
  assert.doesNotMatch(text, /Legacy renderer/);
  assert.match(text, /Screen format: mp/);
  assert.match(text, /Schema version: 1/);
  assert.match(text, /Source root: D:\/coupon\/mp/);
  assert.match(text, /Output root: D:\/coupon\/mp\/\.build/);
  assert.match(text, /Entry ready: yes/);
  assert.match(text, /Publisher API usage: query\/state/);
  assert.match(text, /Publisher API mock: mock/);
  assert.match(text, /Publisher routes: GET \/health, GET \/coupons\/list, GET \/coupons\/page/);
  assert.match(text, /Paged route: yes/);
  assert.doesNotMatch(text, /AWS backend/);
  assert.doesNotMatch(text, /Firebase business backend/);
  assert.match(text, /Endpoint count: 2/);
  assert.match(text, /Endpoint app IDs: coupon_demo, rewards/);
  assert.match(text, /Endpoint modes: coupon_demo:protected, rewards:public/);
  assert.match(text, /Publisher APIs: coupon_demo:remote, rewards:none/);
  assert.match(text, /Routing: endpoint map active/);
  assert.match(text, /Artifact host fallback/);
  assert.match(text, /Access keys required: yes/);
  assert.match(text, /Provider: aws/);
  assert.doesNotMatch(text, /Firestore/);
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
      publisherBackendStarter: { detected: true, template: 'mock' },
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
        hostAuthControllerReady: false,
        hostRuntimeSetupPath: 'D:/host/lib/mini_program/mini_program_runtime_setup.dart',
        hostAuthControllerConfigured: false,
        hostSecureAuthControllerConfigured: false,
        hostDisposeAuthControllerConfigured: false,
        hostAuthIssues: ['Host runtime setup does not configure MiniProgramAuthController.'],
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
  assert.match(text, /Host auth ready: no/);
  assert.match(text, /Host auth configured: no/);
  assert.match(text, /Host auth issues: Host runtime setup does not configure MiniProgramAuthController/);
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
