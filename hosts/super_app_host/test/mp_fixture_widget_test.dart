import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:super_app_host/app/super_app_host_app.dart';
import 'package:super_app_host/bridge/host_bridge_impl.dart';
import 'package:super_app_host/capabilities/supported_capabilities.dart';
import 'package:super_app_host/mini_programs/local_mini_program_catalog.dart';
import 'package:super_app_host/mini_programs/mini_program_entry_page.dart';
import 'package:super_app_host/services/secure_api_service.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 100,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var index = 0; index < maxSteps; index += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }

  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText())
      .whereType<String>()
      .toList();
  throw TestFailure(
    'Timed out waiting for finder: $finder\nVisible text: $visibleTexts',
  );
}

void main() {
  testWidgets('opens the bundled Mp profile fixture and navigates internally', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.mpProfileCenter,
          sdkVersion: superAppHostSdkVersion,
          source: const _TrackedAssetMiniProgramSource(),
          hostBridge: HostBridgeImpl(
            navigatorKey: navigatorKey,
            secureApiService: _RecordingSecureApiService(),
          ),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          cacheBundle: MiniProgramCacheBundle.inMemory(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Portable Mp profile'));

    await tester.scrollUntilVisible(find.text('Open Mp profile details'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Mp profile details'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('Mp profile details'));

    expect(
      find.text(
        'Internal Mp navigation kept this flow inside the mini-program stack.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Back to Mp profile home'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to Mp profile home'));
    await tester.pumpAndSettle();

    expect(find.text('Portable Mp profile'), findsOneWidget);
  });

  testWidgets('opens the bundled Mp rewards fixture with backend and paging', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: MiniProgramEntryPage(
          program: LocalMiniProgramCatalog.mpRewardsCenter,
          sdkVersion: superAppHostSdkVersion,
          source: const _TrackedAssetMiniProgramSource(),
          hostBridge: HostBridgeImpl(
            navigatorKey: navigatorKey,
            secureApiService: _RecordingSecureApiService(),
          ),
          capabilityRegistry: superAppCapabilityRegistry,
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          backendConnector: const _FixtureRewardsBackendConnector(),
          authController: MiniProgramAuthController.inMemory(),
          disposeAuthController: true,
          cacheBundle: MiniProgramCacheBundle.inMemory(),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Sign in to unlock Mp rewards.'));
    await _pumpUntilFound(tester, find.text('Mp rewards from fixture backend'));
    await _pumpUntilFound(tester, find.text('Fixture reward 1'));

    expect(find.text('Sign in with email'), findsOneWidget);
    expect(
      find.text('Backend builder rendered this bundled host response.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Load more rewards'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more rewards'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('Fixture reward 2'));

    expect(find.text('Fixture reward 1'), findsOneWidget);
    expect(find.text('Fixture reward 2'), findsOneWidget);
    expect(find.text('No more Mp rewards.'), findsOneWidget);
  });
}

class _TrackedAssetMiniProgramSource implements MiniProgramSource {
  const _TrackedAssetMiniProgramSource();

  static const String _basePath = 'assets/mini_programs';

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    final json = await _readJson('$_basePath/$miniProgramId/manifest.json');
    return MiniProgramManifest.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    return _readJson('$_basePath/$miniProgramId/screens/$screenId.json');
  }

  Future<Map<String, dynamic>> _readJson(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is Map<String, dynamic>) {
      return Future<Map<String, dynamic>>.value(decoded);
    }
    if (decoded is Map) {
      return Future<Map<String, dynamic>>.value(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    throw StateError('Expected JSON object at $path.');
  }
}

class _RecordingSecureApiService implements SecureApiService {
  @override
  Future<HostActionResult> call(CallSecureApiActionPayload payload) async {
    return HostActionResult.success(
      actionName: ActionNames.callSecureApi,
      data: <String, dynamic>{'status': 'recorded'},
    );
  }
}

class _FixtureRewardsBackendConnector implements MiniProgramBackendConnector {
  const _FixtureRewardsBackendConnector();

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    final endpoint = request.endpoint;
    if (endpoint == 'home/bootstrap') {
      return MiniProgramBackendResult.success(
        requestId: request.requestId,
        endpoint: endpoint,
        method: request.method,
        data: const <String, dynamic>{
          'title': 'Mp rewards from fixture backend',
          'message': 'Backend builder rendered this bundled host response.',
          'user': <String, dynamic>{'name': 'Fixture Member'},
        },
      );
    }

    if (endpoint.startsWith('coupons/page')) {
      final hasCursor = endpoint.contains('cursor=fixture-reward-1');
      return MiniProgramBackendResult.success(
        requestId: request.requestId,
        endpoint: endpoint,
        method: request.method,
        data: hasCursor
            ? const <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'fixture-reward-2',
                    'title': 'Fixture reward 2',
                    'description': 'Second page appended through Mp Load more.',
                    'sortIndex': 2,
                  },
                ],
                'nextCursor': null,
                'hasMore': false,
              }
            : const <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'fixture-reward-1',
                    'title': 'Fixture reward 1',
                    'description':
                        'First page loaded from a host test backend.',
                    'sortIndex': 1,
                  },
                ],
                'nextCursor': 'fixture-reward-1',
                'hasMore': true,
              },
      );
    }

    return MiniProgramBackendResult.failed(
      requestId: request.requestId,
      endpoint: endpoint,
      method: request.method,
      message: 'Unexpected fixture backend endpoint: $endpoint',
      errorCode: 'unexpected_fixture_endpoint',
    );
  }
}
