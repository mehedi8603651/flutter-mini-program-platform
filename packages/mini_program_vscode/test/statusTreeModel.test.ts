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
        },
        {
          appId: 'rewards',
          accessMode: 'public',
          hasAccessKey: false,
          backendConfigured: false,
        },
      ],
    },
    environment: {
      configured: true,
      selectedEnvironment: 'my-aws-prod',
      provider: 'aws',
      apiBaseUrl: 'https://api.example.com/api',
      requireAccessKeys: true,
    },
    backend: { configured: true, statusChecked: true, healthy: true },
    remote: { checked: false },
    nextActions: [],
  };

  const text = flattenStatusSections(buildStatusTreeSections(report));
  assert.match(text, /Host app/);
  assert.match(text, /Endpoint count: 2/);
  assert.match(text, /Endpoint app IDs: coupon_demo, rewards/);
  assert.match(text, /Endpoint modes: coupon_demo:protected, rewards:public/);
  assert.match(text, /Publisher backends: coupon_demo:backend, rewards:none/);
  assert.match(text, /Routing: endpoint map active/);
  assert.match(text, /Backend fallback/);
  assert.match(text, /Access keys required: yes/);
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
