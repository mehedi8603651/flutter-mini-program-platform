import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import * as path from 'node:path';
import test from 'node:test';

import {
  buildDiagnosticsReport,
  formatDiagnosticsReport,
} from '../src/diagnostics';
import { WorkflowStatusReport } from '../src/workflowStatus';

test('unknown workspace reports actionable warning', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-unknown-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'unknown', path: workspacePath },
        environment: { configured: false },
        backend: { configured: false },
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.equal(report.summary.warning > 0, true);
    assert.match(text, /Workspace is not recognized/);
    assert.match(text, /Open a mini-program root/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('mini-program missing build suggests static artifact build flow', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-mini-');
  try {
    await writeFile(
      path.join(workspacePath, 'manifest.json'),
      JSON.stringify({ id: 'coupon_demo', version: '1.0.0', entry: 'coupon_home' }),
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'miniProgram',
      workflowReport: miniProgramReport(workspacePath, {
        build: {
          exists: false,
          screenCount: 0,
          screensDirectory: path.join(workspacePath, 'mp', '.build', 'screens'),
        },
        validation: { status: 'not_run' },
        partnerPackages: [],
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Build output is missing/);
    assert.match(text, /Run MiniProgram: Build/);
    assert.match(text, /Run MiniProgram: Validate/);
    assert.match(text, /after publishing static artifacts/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('mini-program runtime API usage suggests optional middle-server URL', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-backend-query-');
  try {
    await writeFile(
      path.join(workspacePath, 'manifest.json'),
      JSON.stringify({ id: 'coupon_demo', version: '1.0.0', entry: 'coupon_home' }),
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'miniProgram',
      workflowReport: miniProgramReport(workspacePath, {
        build: { exists: true, screenCount: 1 },
        validation: { status: 'ok' },
        partnerPackages: [{ appId: 'coupon_demo' }],
        backendUsage: {
          usesPublisherBackend: true,
          usesBackendBuilder: true,
          usesBackendQueryAction: true,
          usesBackendState: true,
          requestIds: ['home'],
        },
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Mini-program source uses backend query\/state helpers/);
    assert.match(text, /Request IDs: home/);
    assert.match(text, /middleServerApiUrl\/Publisher API URL/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app reports static artifact endpoints and optional runtime API modes', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-host-launcher-');
  try {
    await mkdir(path.join(workspacePath, 'lib', 'mini_program'), { recursive: true });
    await writeFile(
      path.join(workspacePath, 'pubspec.yaml'),
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.5.0\n',
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'main.dart'),
      "import 'package:mini_program_sdk/mini_program_sdk.dart';\nvoid main() { MiniProgramScope; }\n",
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      `// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"profile":{"apiBaseUri":"https://cdn.example.com/profile","backendBaseUri":"https://publisher.example.com/api"}}
// END MINI_PROGRAM_ENDPOINTS_JSON
`,
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: hostReport(workspacePath, {
        endpointCount: 1,
        endpoints: [
          {
            appId: 'profile',
            apiBaseUri: 'https://cdn.example.com/profile',
            backendBaseUri: 'https://publisher.example.com/api',
            backendConfigured: true,
            backendMode: 'remote',
          },
        ],
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Endpoint entries include static artifact base URLs/);
    assert.match(text, /not opened from host UI: profile/);
    assert.match(text, /profile:remote/);
    assert.match(text, /Auth, payments, database access/);
    assert.doesNotMatch(text, /credential header/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app warns when local mock backend uses old SDK constraint', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-host-local-mock-');
  try {
    await mkdir(path.join(workspacePath, 'lib', 'mini_program'), { recursive: true });
    await writeFile(
      path.join(workspacePath, 'pubspec.yaml'),
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.3.4\n',
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'main.dart'),
      "import 'package:mini_program_sdk/mini_program_sdk.dart';\nvoid main() { MiniProgramScope; openAppMiniProgram(null, appId: 'coupon_app'); }\n",
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: hostReport(workspacePath, {
        endpointCount: 1,
        endpoints: [
          {
            appId: 'coupon_app',
            apiBaseUri: 'https://cdn.example.com/public_mini_program/',
            backendBaseUri: 'http://127.0.0.1:9090',
            backendConfigured: true,
            backendMode: 'local_mock',
          },
        ],
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /coupon_app:local_mock/);
    assert.match(text, /mini_program_sdk 0\.3\.5 or newer/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app checks reachable static artifact manifest and entry screen', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-host-public-');
  const server = createServer((request, response) => {
    if (request.url === '/public_mini_program/manifests/public_coupon/latest.json') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({
        id: 'public_coupon',
        version: '1.0.0',
        entry: 'public_coupon_home',
      }));
      return;
    }
    if (request.url === '/public_mini_program/screens/public_coupon/1.0.0/public_coupon_home.json') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ type: 'text', data: 'Public coupon' }));
      return;
    }
    response.writeHead(404);
    response.end('not found');
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address() as AddressInfo;
  const apiBaseUri = `http://127.0.0.1:${address.port}/public_mini_program/`;
  try {
    await mkdir(path.join(workspacePath, 'lib', 'mini_program'), { recursive: true });
    await writeFile(
      path.join(workspacePath, 'pubspec.yaml'),
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.5.0\n',
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'main.dart'),
      "import 'package:mini_program_sdk/mini_program_sdk.dart';\nvoid main() { MiniProgramScope; openAppMiniProgram(null, appId: 'public_coupon'); }\n",
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: hostReport(workspacePath, {
        endpointCount: 1,
        endpoints: [{ appId: 'public_coupon', apiBaseUri }],
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Static artifact endpoint uses public static files/);
    assert.match(text, /Public latest manifest is reachable/);
    assert.match(text, /Public entry screen JSON is reachable/);
    assert.doesNotMatch(text, /Incomplete endpoint entries/);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostic output redacts legacy access-key shaped secrets', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-secret-');
  try {
    const secret = 'mpk_live_super_secret_value_1234567890';
    const generated = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: hostReport(workspacePath, {
        endpointCount: 1,
        endpoints: [
          {
            appId: 'coupon_demo',
            apiBaseUri: 'https://cdn.example.com/coupon_demo',
          },
        ],
      }),
    });
    const text = formatDiagnosticsReport({
      ...generated,
      checks: [
        ...generated.checks,
        {
          id: 'secret.fixture',
          label: 'Secret fixture',
          severity: 'warning',
          summary: 'Secret should be redacted.',
          detail: secret,
        },
      ],
    });
    assert.doesNotMatch(text, new RegExp(secret));
    assert.match(text, /mpk_live_<redacted>/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics warn when CLI lacks current MVP support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-old-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsStaticPublish: false,
        supportsPublisherApiMock: false,
        supportsPublisherBackendContract: false,
        supportsCapabilityDiscovery: true,
        toolingVersion: '0.4.1',
        detail: 'Configured CLI does not expose current MVP commands.',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /CLI Publisher API commands/);
    assert.match(text, /missing static artifact publish or provider-neutral Publisher API commands/);
    assert.match(text, /Activate the local mini_program_tooling package or update miniProgram\.cliPath/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics accept CLI with static artifact and Publisher API support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-new-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsStaticPublish: true,
        supportsPublisherApiMock: true,
        supportsPublisherBackendContract: true,
        supportsCapabilityDiscovery: true,
        toolingVersion: '0.6.0',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(
      text,
      /Configured CLI supports static artifact publishing, Publisher API mock, runtime contract checks, and quiet capability discovery/,
    );
    assert.match(text, /Version: 0.6.0/);
    assert.doesNotMatch(text, /missing static artifact publish/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

async function tempWorkspace(prefix: string): Promise<string> {
  return mkdtemp(path.join(tmpdir(), prefix));
}

function miniProgramReport(
  workspacePath: string,
  miniProgram: Record<string, unknown>,
): WorkflowStatusReport {
  return {
    schemaVersion: 1,
    command: 'workflow status',
    workspace: { type: 'mini_program', path: workspacePath },
    miniProgram: {
      detected: true,
      appId: 'coupon_demo',
      version: '1.0.0',
      entry: 'coupon_home',
      ...miniProgram,
    },
    environment: { configured: false },
    backend: { configured: false },
  };
}

function hostReport(
  workspacePath: string,
  hostApp: Record<string, unknown>,
): WorkflowStatusReport {
  return {
    schemaVersion: 1,
    command: 'workflow status',
    workspace: { type: 'host_app', path: workspacePath },
    hostApp: {
      detected: true,
      runtimeSetupExists: true,
      launcherExists: true,
      endpointMapExists: true,
      endpointAppIds: [],
      endpoints: [],
      ...hostApp,
    },
    environment: { configured: false },
    backend: { configured: false },
  };
}
