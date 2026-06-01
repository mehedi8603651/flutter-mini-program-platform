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
        remote: { checked: false },
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

test('mini-program missing build suggests build', async () => {
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
          screensDirectory: path.join(workspacePath, 'stac', '.build', 'screens'),
        },
        validation: { status: 'not_run' },
        partnerPackages: [],
      }),
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Build output is missing/);
    assert.match(text, /Run MiniProgram: Build/);
    assert.match(text, /Run MiniProgram: Validate/);
    assert.match(text, /Run MiniProgram: Create Partner Package/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('mini-program backend query usage suggests backend base URL', async () => {
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
    assert.match(text, /--backend-base-url/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app missing endpoint, scope, and internet permission suggests fixes', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-host-');
  try {
    await mkdir(path.join(workspacePath, 'lib'), { recursive: true });
    await writeFile(
      path.join(workspacePath, 'pubspec.yaml'),
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.2.0\n',
    );
    await writeFile(path.join(workspacePath, 'lib', 'main.dart'), 'void main() {}\n');

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'host_app', path: workspacePath },
        hostApp: {
          detected: true,
          runtimeSetupExists: false,
          launcherExists: false,
          endpointMapExists: false,
          endpointCount: 0,
          endpoints: [],
        },
        environment: { configured: false },
        backend: { configured: false },
        remote: { checked: false },
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Endpoint map is missing/);
    assert.match(text, /MiniProgram: Import Host Endpoint/);
    assert.match(text, /MiniProgramScope was not found/);
    assert.match(text, /android.permission.INTERNET/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app warns when endpoint has no likely launcher usage', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-host-launcher-');
  try {
    await mkdir(path.join(workspacePath, 'lib', 'mini_program'), { recursive: true });
    await writeFile(
      path.join(workspacePath, 'pubspec.yaml'),
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.3.1\n',
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'main.dart'),
      "import 'package:mini_program_sdk/mini_program_sdk.dart';\nvoid main() { MiniProgramScope; }\n",
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      `// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"profile":{"apiBaseUri":"https://api.example.com/api","accessKey":"mpk_live_secret"}}
// END MINI_PROGRAM_ENDPOINTS_JSON
`,
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'host_app', path: workspacePath },
        hostApp: {
          detected: true,
          runtimeSetupExists: true,
          launcherExists: true,
          endpointMapExists: true,
          endpointCount: 1,
          endpoints: [
            {
              appId: 'profile',
              apiBaseUri: 'https://api.example.com/api',
              backendBaseUri: 'https://publisher.example.com/api',
              backendConfigured: true,
              backendMode: 'remote',
              accessMode: 'protected',
              hasAccessKey: true,
            },
          ],
        },
        environment: { configured: false },
        backend: { configured: false },
        remote: { checked: false },
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /not opened from host UI: profile/);
    assert.match(text, /MiniProgram: Copy Demo Host Button/);
    assert.match(text, /Endpoint routing is active/);
    assert.match(text, /profile:remote/);
    assert.match(text, /default backend URL is only a fallback/);
    assert.match(text, /delivery access only/);
    assert.doesNotMatch(text, /mpk_live_secret/);
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
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'host_app', path: workspacePath },
        hostApp: {
          detected: true,
          runtimeSetupExists: true,
          launcherExists: true,
          endpointMapExists: true,
          endpointCount: 1,
          endpoints: [
            {
              appId: 'coupon_app',
              apiBaseUri: 'https://cdn.example.com/public_mini_program/',
              accessMode: 'public',
              hasAccessKey: false,
              backendBaseUri: 'http://127.0.0.1:9090',
              backendConfigured: true,
              backendMode: 'local_mock',
            },
          ],
        },
        environment: { configured: false },
        backend: { configured: false },
        remote: { checked: false },
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /coupon_app:local_mock/);
    assert.match(text, /mini_program_sdk 0\.3\.5 or newer/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('host app accepts public endpoint metadata without access key', async () => {
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
      'name: host_app\ndependencies:\n  mini_program_sdk: ^0.3.1\n',
    );
    await writeFile(
      path.join(workspacePath, 'lib', 'main.dart'),
      "import 'package:mini_program_sdk/mini_program_sdk.dart';\nvoid main() { MiniProgramScope; openAppMiniProgram(null, appId: 'public_coupon'); }\n",
    );

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'host_app', path: workspacePath },
        hostApp: {
          detected: true,
          runtimeSetupExists: true,
          launcherExists: true,
          endpointMapExists: true,
          endpointCount: 1,
          endpoints: [
            {
              appId: 'public_coupon',
              apiBaseUri,
              accessMode: 'public',
              hasAccessKey: false,
            },
          ],
        },
        environment: { configured: false },
        backend: { configured: false },
        remote: { checked: false },
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /public_coupon:public/);
    assert.match(text, /Public latest manifest is reachable/);
    assert.match(text, /Public entry screen JSON is reachable/);
    assert.match(text, /does not require a MiniProgram access key/);
    assert.doesNotMatch(text, /Incomplete endpoint entries/);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('remote diagnostics surfaces cloud and access-key errors', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cloud-');
  try {
    const localReport: WorkflowStatusReport = {
      schemaVersion: 1,
      command: 'workflow status',
      workspace: { type: 'mini_program', path: workspacePath },
      environment: {
        configured: true,
        selectedEnvironment: 'my-aws-prod',
        provider: 'aws',
        apiBaseUrl: 'https://api.example.com/prod/api',
        requireAccessKeys: true,
      },
      backend: { configured: true },
      remote: { checked: false },
    };
    const remoteReport: WorkflowStatusReport = {
      ...localReport,
      remote: {
        checked: true,
        cloudStatus: { healthy: false, stackStatus: 'ROLLBACK_COMPLETE' },
        app: {},
        accessKeys: { activeCount: 0 },
        errors: ['Cloud app info failed.'],
      },
    };

    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'cloudDelivery',
      workflowReport: localReport,
      remoteWorkflowReport: remoteReport,
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /Cloud stack is not healthy/);
    assert.match(text, /0 active access key/);
    assert.match(text, /Cloud app info failed/);
    assert.match(text, /Run MiniProgram: Create Access Key/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostic output redacts access-key secrets', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-secret-');
  try {
    const secret = 'mpk_live_super_secret_value_1234567890';
    const generated = await buildDiagnosticsReport({
      workspacePath,
      scope: 'hostApp',
      workflowReport: {
        schemaVersion: 1,
        command: 'workflow status',
        workspace: { type: 'host_app', path: workspacePath },
        hostApp: {
          detected: true,
          endpointCount: 1,
          endpoints: [
            {
              appId: 'coupon_demo',
              apiBaseUri: 'https://api.example.com/api',
              hasAccessKey: true,
              accessKey: secret,
            },
          ],
        },
        environment: { configured: false },
        backend: { configured: false },
        remote: { checked: false },
      },
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

test('diagnostics warn when CLI lacks AWS write smoke support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-old-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsWriteSmoke: false,
        supportsDataManagement: false,
        detail: 'Configured CLI does not list --include-write.',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /CLI publisher backend commands/);
    assert.match(text, /lacks the 0.3.42 CORS\/version metadata fix|missing mini_program_tooling 0.3.48/);
    assert.match(text, /dart pub global activate mini_program_tooling 0.3.48/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics warn when CLI lacks AWS data management support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-027-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsWriteSmoke: true,
        supportsDataManagement: false,
        detail: 'Configured CLI does not expose AWS DynamoDB data export.',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /lacks the 0.3.42 CORS\/version metadata fix|missing mini_program_tooling 0.3.48/);
    assert.match(text, /dart pub global activate mini_program_tooling 0.3.48/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics warn when CLI lacks Firebase write smoke support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-firebase-write-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsWriteSmoke: true,
        supportsDataManagement: true,
        supportsFirebaseOperations: true,
        supportsFirebaseHostCommand: true,
        supportsFirebaseHandoff: true,
        supportsFirebaseStarterUi: true,
        supportsFirebaseAuthStatus: true,
        supportsFirebaseHostAuthDiagnostics: true,
        supportsFirebaseHostingPublish: true,
        supportsFirebaseWriteSmoke: false,
        supportsFirebaseFirestoreData: true,
        supportsFirebaseDataManagement: true,
        supportsCapabilityDiscovery: true,
        toolingVersion: '0.3.34',
        detail: 'Configured CLI capabilities do not include Firebase write smoke.',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /lacks the 0.3.42 CORS\/version metadata fix|missing mini_program_tooling 0.3.48/);
    assert.match(text, /Firebase write smoke/);
    assert.match(text, /dart pub global activate mini_program_tooling 0.3.48/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics warn when CLI lacks quiet capability discovery', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-028-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsWriteSmoke: true,
        supportsDataManagement: true,
        supportsFirebaseOperations: true,
        supportsFirebaseHostCommand: true,
        supportsFirebaseHandoff: true,
        supportsFirebaseStarterUi: true,
        supportsFirebaseAuthStatus: true,
        supportsFirebaseHostAuthDiagnostics: true,
        supportsFirebaseHostingPublish: true,
        supportsFirebaseWriteSmoke: true,
        supportsFirebaseFirestoreData: true,
        supportsFirebaseDataManagement: true,
        supportsCapabilityDiscovery: false,
        toolingVersion: '0.3.42',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(text, /lacks 0.3.29 quiet capability discovery/);
    assert.match(text, /dart pub global activate mini_program_tooling 0.3.48/);
  } finally {
    await rm(workspacePath, { recursive: true, force: true });
  }
});

test('diagnostics accept CLI with AWS data management support', async () => {
  const workspacePath = await tempWorkspace('mini-program-diag-cli-new-');
  try {
    const report = await buildDiagnosticsReport({
      workspacePath,
      scope: 'workspace',
      cliCapabilities: {
        checked: true,
        supportsWriteSmoke: true,
        supportsDataManagement: true,
        supportsFirebaseOperations: true,
        supportsFirebaseHostCommand: true,
        supportsFirebaseHandoff: true,
        supportsFirebaseStarterUi: true,
        supportsFirebaseAuthStatus: true,
        supportsFirebaseHostAuthDiagnostics: true,
        supportsFirebaseHostingPublish: true,
        supportsFirebaseWriteSmoke: true,
        supportsFirebaseFirestoreData: true,
        supportsFirebaseDataManagement: true,
        supportsCapabilityDiscovery: true,
        toolingVersion: '0.3.48',
      },
    });

    const text = formatDiagnosticsReport(report);
    assert.match(
      text,
      /Configured CLI supports AWS DynamoDB, Firebase Firestore, Firebase host integration, Firebase handoff, Firebase starter UI, Firebase auth diagnostics, Firebase write smoke, Firebase Hosting CORS publish, and quiet capability discovery/,
    );
    assert.match(text, /Version: 0.3.48/);
    assert.doesNotMatch(text, /mini_program_tooling 0.3.48/);
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
    remote: { checked: false },
  };
}
