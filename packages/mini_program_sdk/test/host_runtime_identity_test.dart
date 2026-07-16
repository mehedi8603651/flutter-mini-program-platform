import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets('builder-only updates do not reload the mini-program', (
    tester,
  ) async {
    final source = _CountingSource();
    final capabilities = CapabilityRegistry(const <CapabilityId>[]);

    await tester.pumpWidget(
      _hostApp(
        appId: 'stable_app',
        source: source,
        capabilities: capabilities,
        loadingBuilder: (_) => const Text('Loading A'),
        errorBuilder: (_, failure) => Text('Error A: ${failure.message}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Content for stable_app'), findsOneWidget);
    expect(source.manifestLoads, 1);
    expect(source.screenLoads, 1);

    await tester.pumpWidget(
      _hostApp(
        appId: 'stable_app',
        source: source,
        capabilities: capabilities,
        loadingBuilder: (_) => const Text('Loading B'),
        errorBuilder: (_, failure) => Text('Error B: ${failure.message}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Content for stable_app'), findsOneWidget);
    expect(source.manifestLoads, 1);
    expect(source.screenLoads, 1);
  });

  testWidgets('a superseded asynchronous load cannot replace the active app', (
    tester,
  ) async {
    final source = _ControlledSource();
    final capabilities = CapabilityRegistry(const <CapabilityId>[]);

    await tester.pumpWidget(
      _hostApp(appId: 'slow_app', source: source, capabilities: capabilities),
    );
    await tester.pump();
    expect(source.requestedManifests, contains('slow_app'));

    await tester.pumpWidget(
      _hostApp(appId: 'fast_app', source: source, capabilities: capabilities),
    );
    await tester.pump();
    expect(source.requestedManifests, contains('fast_app'));

    source.completeManifest('fast_app');
    await tester.pumpAndSettle();
    expect(find.text('Content for fast_app'), findsOneWidget);
    expect(find.text('Content for slow_app'), findsNothing);

    source.completeManifest('slow_app');
    await tester.pumpAndSettle();
    expect(find.text('Content for fast_app'), findsOneWidget);
    expect(find.text('Content for slow_app'), findsNothing);
  });

  testWidgets(
    'disposal closes the active cache once and preserves host connector ownership',
    (tester) async {
      final source = _CountingSource();
      final cacheManager = _CountingCacheManager();
      final connector = _HostOwnedConnector();

      await tester.pumpWidget(
        _hostApp(
          appId: 'owned_resources',
          source: source,
          capabilities: CapabilityRegistry(const <CapabilityId>[]),
          cacheManager: cacheManager,
          backendConnector: connector,
        ),
      );
      await tester.pumpAndSettle();

      expect(cacheManager.openCalls, 1);
      expect(cacheManager.closeCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(cacheManager.closeCalls, 1);
      expect(connector.disposeCalls, 0);
    },
  );
}

Widget _hostApp({
  required String appId,
  required MiniProgramSource source,
  required CapabilityRegistry capabilities,
  MiniProgramCacheManager? cacheManager,
  MiniProgramBackendConnector? backendConnector,
  WidgetBuilder? loadingBuilder,
  MiniProgramErrorBuilder? errorBuilder,
}) {
  return MaterialApp(
    home: MiniProgramHost(
      miniProgramId: appId,
      sdkVersion: '1.0.0',
      source: source,
      hostBridge: const _HostBridge(),
      capabilityRegistry: capabilities,
      cacheManager: cacheManager,
      backendConnector: backendConnector,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    ),
  );
}

MiniProgramManifest _manifest(String appId) {
  return MiniProgramManifest(
    id: appId,
    version: '1.0.0',
    entry: '${appId}_home',
    contractVersion: '1.0.0',
    sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: const <CapabilityId>[],
    screenFormat: MiniProgramScreenFormats.mp,
    screenSchemaVersion: 1,
  );
}

Map<String, dynamic> _screen(String appId) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'screenId': '${appId}_home',
    'root': <String, dynamic>{
      'type': 'text',
      'props': <String, dynamic>{'data': 'Content for $appId'},
      'children': <Object?>[],
    },
  };
}

class _CountingSource implements MiniProgramSource {
  int manifestLoads = 0;
  int screenLoads = 0;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    manifestLoads += 1;
    return _manifest(miniProgramId);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    screenLoads += 1;
    return _screen(miniProgramId);
  }
}

class _ControlledSource implements MiniProgramSource {
  final Map<String, Completer<MiniProgramManifest>> _manifestCompleters =
      <String, Completer<MiniProgramManifest>>{};
  final List<String> requestedManifests = <String>[];

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) {
    requestedManifests.add(miniProgramId);
    return _manifestCompleters
        .putIfAbsent(miniProgramId, Completer<MiniProgramManifest>.new)
        .future;
  }

  void completeManifest(String appId) {
    _manifestCompleters[appId]!.complete(_manifest(appId));
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _screen(miniProgramId);
  }
}

class _CountingCacheManager extends MiniProgramCacheManager {
  _CountingCacheManager() : super(store: MiniProgramMemoryCacheStore());

  int openCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> openApp(String appId, {MiniProgramCachePolicy? policy}) async {
    openCalls += 1;
    await super.openApp(appId, policy: policy);
  }

  @override
  Future<void> closeApp(String appId, {MiniProgramCachePolicy? policy}) async {
    closeCalls += 1;
    await super.closeApp(appId, policy: policy);
  }
}

class _HostOwnedConnector implements DisposableMiniProgramBackendConnector {
  int disposeCalls = 0;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return MiniProgramBackendResult.success(
      requestId: request.requestId,
      endpoint: request.endpoint,
      method: request.method,
    );
  }

  @override
  void dispose() {
    disposeCalls += 1;
  }
}

class _HostBridge implements HostBridge {
  const _HostBridge();

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return HostActionResult.success(actionName: ActionNames.trackEvent);
  }
}
