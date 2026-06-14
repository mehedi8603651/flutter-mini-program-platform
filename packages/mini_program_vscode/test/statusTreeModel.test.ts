import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildStatusTreeSections,
  flattenStatusSections,
} from '../src/statusTreeModel';
import { WorkflowStatusReport } from '../src/workflowStatus';

test('renders mini-program and host status rows for static artifacts', () => {
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
          apiBaseUri: 'https://cdn.example.com/coupon_demo',
          backendConfigured: true,
          backendMode: 'remote',
        },
        {
          appId: 'rewards',
          apiBaseUri: 'https://cdn.example.com/rewards',
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
      selectedEnvironment: 'local-dev',
      apiBaseUrl: 'https://cdn.example.com/coupon_demo',
    },
    backend: { configured: true, statusChecked: true, healthy: true },
    nextActions: [],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.match(text, /Host app/);
  assert.match(text, /Screen format: mp/);
  assert.match(text, /Schema version: 1/);
  assert.match(text, /Source root: D:\/coupon\/mp/);
  assert.match(text, /Output root: D:\/coupon\/mp\/\.build/);
  assert.match(text, /Entry ready: yes/);
  assert.match(text, /Publisher API usage: query\/state/);
  assert.match(text, /Publisher API mock: mock/);
  assert.match(text, /Publisher routes: GET \/health, GET \/coupons\/list, GET \/coupons\/page/);
  assert.match(text, /Endpoint count: 2/);
  assert.match(text, /Endpoint app IDs: coupon_demo, rewards/);
  assert.match(text, /Static artifacts: coupon_demo:static, rewards:static/);
  assert.match(text, /Runtime Publisher APIs: coupon_demo:remote, rewards:none/);
  assert.match(text, /Routing: endpoint map active/);
  assert.match(text, /Artifact host fallback/);
  assert.match(text, /Artifact base URL: https:\/\/cdn\.example\.com\/coupon_demo/);
  assert.doesNotMatch(text, /Provider:|credential|mpk_live/);
});

test('does not render raw unrelated secret-shaped fields', () => {
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
          credential: secretA,
        },
      ],
    },
    hostApp: {
      detected: true,
      endpointCount: 1,
      endpointAppIds: ['coupon_demo'],
      endpoints: [{ appId: 'coupon_demo', apiBaseUri: 'https://cdn.example.com', credential: secretB }],
    },
    environment: { configured: true },
    backend: { configured: false },
    nextActions: ['Run `miniprogram build`.'],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.doesNotMatch(text, new RegExp(secretA));
  assert.doesNotMatch(text, new RegExp(secretB));
  assert.doesNotMatch(text, /sha256_should_not_render/);
  assert.match(text, /Static artifacts: coupon_demo:static/);
});
