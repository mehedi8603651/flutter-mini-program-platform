import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildDemoHostButtonSnippet,
  buildCleanupCommandTemplate,
  buildHostCommandTemplate,
  buildPublisherCommandTemplate,
  buildRegistryFile,
  dartFieldNameFromAppId,
  endpointLaunchUsageMissing,
  parseEndpointAppIds,
  parseRegistryEntries,
  upsertRegistryEntry,
} from '../src/hostIntegration';

test('parses generated endpoint appIds from static artifact endpoint source', () => {
  const source = `// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"coupon_demo":{"apiBaseUri":"https://cdn.example.com/coupon_demo"}}
// END MINI_PROGRAM_ENDPOINTS_JSON

Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {
  return <String, MiniProgramEndpoint>{
    "coupon_demo": MiniProgramEndpoint.public(
      apiBaseUri: Uri.parse("https://cdn.example.com/coupon_demo"),
    ),
  };
}
`;

  assert.deepEqual(parseEndpointAppIds(source), ['coupon_demo']);
});

test('parses public endpoint appIds from Dart source', () => {
  const source = `Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {
  return <String, MiniProgramEndpoint>{
    "public_coupon": MiniProgramEndpoint.public(
      apiBaseUri: Uri.parse("https://user.github.io/repo/public_mini_program"),
    ),
  };
}
`;

  assert.deepEqual(parseEndpointAppIds(source), ['public_coupon']);
});

test('builds and upserts registry entries', () => {
  const source = buildRegistryFile([
    { appId: 'coupon_demo', title: 'Coupon Demo' },
  ]);
  assert.match(source, /class MiniProgramInfo/);
  assert.match(source, /static const couponDemo/);
  assert.match(source, /static const values/);
  assert.match(source, /static const byAppId/);

  const updated = upsertRegistryEntry(source, {
    appId: 'profile',
    title: 'Profile',
  });
  assert.deepEqual(parseRegistryEntries(updated), [
    { appId: 'coupon_demo', title: 'Coupon Demo' },
    { appId: 'profile', title: 'Profile' },
  ]);
});

test('builds registry and inline demo button snippets', () => {
  assert.equal(dartFieldNameFromAppId('coupon_demo'), 'couponDemo');
  const registrySnippet = buildDemoHostButtonSnippet(
    { appId: 'coupon_demo', title: 'Coupon Demo' },
    { useRegistry: true },
  );
  assert.match(registrySnippet, /MiniPrograms\.couponDemo\.appId/);
  assert.doesNotMatch(registrySnippet, /mpk_live_/);

  const inlineSnippet = buildDemoHostButtonSnippet(
    { appId: 'profile', title: 'Profile' },
    { useRegistry: false },
  );
  assert.match(inlineSnippet, /appId: 'profile'/);
  assert.match(inlineSnippet, /Open Profile MiniProgram/);
});

test('detects endpoints that have no likely launcher usage', () => {
  const missing = endpointLaunchUsageMissing(
    [
      {
        path: 'lib/main.dart',
        source: "openAppMiniProgram(context, appId: 'profile');",
      },
      {
        path: 'lib/mini_program/mini_program_registry.dart',
        source: "static const couponDemo = MiniProgramInfo(appId: 'coupon_demo', title: 'Coupon Demo');",
      },
    ],
    ['profile', 'coupon_demo'],
  );
  assert.deepEqual(missing, ['coupon_demo']);
});

test('builds copyable workflow command templates', () => {
  const publisher = buildPublisherCommandTemplate({
    appId: 'coupon_demo',
    title: 'Coupon Demo',
    artifactBaseUrl: 'https://cdn.example.com/coupon_demo',
  });
  assert.match(publisher, /miniprogram build/);
  assert.match(publisher, /publish --target static/);
  assert.match(publisher, /partner package coupon_demo/);
  assert.match(publisher, /--artifact-base-url "https:\/\/cdn\.example\.com\/coupon_demo"/);
  assert.doesNotMatch(publisher, /credential header/);

  const host = buildHostCommandTemplate({
    projectRoot: 'D:\\host_app',
    deviceId: 'chrome',
  });
  assert.match(host, /embed init --project-root "D:\\host_app"/);
  assert.match(host, /host endpoint import/);
  assert.match(host, /host run -d chrome/);
  assert.match(host, /flutter build apk --release/);
});

test('builds local-only cleanup command templates', () => {
  const commands = buildCleanupCommandTemplate({
    workspacePath: 'D:\\work\\coupon_demo',
  });
  assert.match(commands, /Remove-Item -Recurse -Force "D:\\work\\coupon_demo"/);
  assert.doesNotMatch(commands, /credential header|mpk_live/);

  assert.equal(
    buildCleanupCommandTemplate({}),
    'No provider cleanup commands are needed for public static artifacts.',
  );
});
