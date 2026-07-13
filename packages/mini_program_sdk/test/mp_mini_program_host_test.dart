import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_contracts/mini_program_contracts.dart'
    as contracts;
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets(
    'MiniProgramHost opens static Mp artifacts without runtime middle-server API config',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MiniProgramHost(
            miniProgramId: 'mp_test',
            sdkVersion: '1.0.0',
            source: const _MpSource(),
            hostBridge: const _HostBridge(),
            capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mp-only host screen'), findsOneWidget);
    },
  );

  testWidgets('MiniProgramPage wraps loaded Mp content in a light scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiniProgramRuntimeScope(
          runtime: MiniProgramRuntime(
            sdkVersion: '1.0.0',
            source: const _MpSource(),
            hostBridge: const _HostBridge(),
            capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
            cacheBundle: MiniProgramCacheBundle.inMemory(),
          ),
          child: const MiniProgramPage(
            miniProgramId: 'mp_test',
            title: 'Area Search',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Area Search'), findsOneWidget);
    expect(find.text('Mp-only host screen'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFF8FAFC));
  });

  testWidgets('MiniProgramPage can hide host chrome for immersive apps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiniProgramRuntimeScope(
          runtime: MiniProgramRuntime(
            sdkVersion: '1.0.0',
            source: const _MpSource(),
            hostBridge: const _HostBridge(),
            capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
            cacheBundle: MiniProgramCacheBundle.inMemory(),
          ),
          child: const MiniProgramPage(
            miniProgramId: 'mp_test',
            title: 'Hidden title',
            showAppBar: false,
            backgroundColor: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hidden title'), findsNothing);
    expect(find.text('Mp-only host screen'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.appBar, isNull);
    expect(scaffold.backgroundColor, Colors.black);
  });

  testWidgets('Mp router passes params and returns pop results', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProgramHost(
          miniProgramId: 'mp_router_test',
          sdkVersion: '1.0.0',
          source: const _RouterMpSource(),
          hostBridge: const _HostBridge(),
          capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saved: '), findsOneWidget);

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('Product: p1'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Saved: true'), findsOneWidget);
  });

  testWidgets('router.replace remounts lifecycle nodes on the same screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProgramHost(
          miniProgramId: 'same_screen_replace',
          sdkVersion: '1.0.0',
          source: const _SameScreenReplaceSource(),
          hostBridge: const _HostBridge(),
          capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('10'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('9'), findsOneWidget);

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('10'), findsOneWidget);
    expect(find.text('9'), findsNothing);
  });

  testWidgets(
    'MiniProgramHost updates cache metadata and clears memory on close',
    (tester) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      const source = _CachePolicyMpSource();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MiniProgramHost(
            miniProgramId: 'mp_cache_test',
            sdkVersion: '1.0.0',
            source: source,
            hostBridge: const _HostBridge(),
            capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
            cacheManager: cacheManager,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(cacheManager.getMetadata('mp_cache_test'), isNotNull);

      await cacheManager
          .forApp('mp_cache_test')
          .set('runtime_value', true, bucket: MiniProgramCacheBucket.memory);
      expect(
        await cacheManager.has(
          appId: 'mp_cache_test',
          key: 'runtime_value',
          bucket: MiniProgramCacheBucket.memory,
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(
        await cacheManager.has(
          appId: 'mp_cache_test',
          key: 'runtime_value',
          bucket: MiniProgramCacheBucket.memory,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'stale cached content remains visible after offline notice dismisses',
    (tester) async {
      const manifest = MiniProgramManifest(
        id: 'offline_mp',
        version: '1.0.0',
        entry: 'offline_home',
        contractVersion: '1.0.0',
        sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
        requiredCapabilities: <CapabilityId>[],
        screenFormat: MiniProgramScreenFormats.mp,
        screenSchemaVersion: 1,
        cachePolicy: contracts.MiniProgramCachePolicy(
          manifest: contracts.MiniProgramCacheRule(
            mode: contracts.MiniProgramCacheMode.staleWhileError,
            maxStaleSeconds: 3600,
          ),
          entryScreen: contracts.MiniProgramCacheRule(
            mode: contracts.MiniProgramCacheMode.staleWhileError,
            maxStaleSeconds: 3600,
          ),
        ),
      );
      const screen = <String, dynamic>{
        'schemaVersion': 1,
        'screenId': 'offline_home',
        'root': <String, dynamic>{
          'type': 'text',
          'props': <String, dynamic>{'data': 'Offline cached content'},
          'children': <Object?>[],
        },
      };
      final manifestCache = InMemoryManifestCache();
      final screenCache = InMemoryScreenCache();
      final cachedAt = DateTime.now();
      await manifestCache.write(
        CachedManifestEntry(
          miniProgramId: manifest.id,
          manifest: manifest,
          cachedAt: cachedAt,
        ),
      );
      await screenCache.write(
        CachedScreenEntry(
          miniProgramId: manifest.id,
          version: manifest.version,
          screenId: manifest.entry,
          screenJson: screen,
          cachedAt: cachedAt,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MiniProgramHost(
                miniProgramId: manifest.id,
                sdkVersion: '1.0.0',
                source: const _OfflineMpSource(),
                hostBridge: const _HostBridge(),
                capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
                manifestCache: manifestCache,
                screenCache: screenCache,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final content = find.text('Offline cached content');
      final notice = find.text(
        'Showing cached content while the backend is unavailable.',
      );
      expect(content, findsOneWidget);
      expect(notice, findsOneWidget);
      expect(tester.getSize(content).width, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));

      expect(notice, findsNothing);
      expect(content, findsOneWidget);
      expect(tester.getSize(content).width, greaterThan(0));
    },
  );
}

class _MpSource implements MiniProgramSource {
  const _MpSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'mp_test',
      version: '1.0.0',
      entry: 'mp_test_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <CapabilityId>[],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{
      'schemaVersion': 1,
      'screenId': 'mp_test_home',
      'root': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Mp-only host screen'},
        'children': <Object?>[],
      },
    };
  }
}

class _RouterMpSource implements MiniProgramSource {
  const _RouterMpSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'mp_router_test',
      version: '1.0.0',
      entry: 'mp_router_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <CapabilityId>[],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    if (screenId == 'mp_router_detail') {
      return const <String, dynamic>{
        'schemaVersion': 1,
        'screenId': 'mp_router_detail',
        'root': <String, dynamic>{
          'type': 'column',
          'props': <String, dynamic>{},
          'children': <Object?>[
            <String, dynamic>{
              'type': 'text',
              'props': <String, dynamic>{
                'data': 'Product: {{route.productId}}',
              },
              'children': <Object?>[],
            },
            <String, dynamic>{
              'type': 'primaryButton',
              'props': <String, dynamic>{
                'label': 'Done',
                'action': <String, dynamic>{
                  'type': 'router.pop',
                  'props': <String, dynamic>{
                    'result': <String, dynamic>{'saved': true},
                  },
                },
              },
              'children': <Object?>[],
            },
          ],
        },
      };
    }
    return const <String, dynamic>{
      'schemaVersion': 1,
      'screenId': 'mp_router_home',
      'root': <String, dynamic>{
        'type': 'column',
        'props': <String, dynamic>{},
        'children': <Object?>[
          <String, dynamic>{
            'type': 'text',
            'props': <String, dynamic>{'data': 'Saved: {{route.result.saved}}'},
            'children': <Object?>[],
          },
          <String, dynamic>{
            'type': 'primaryButton',
            'props': <String, dynamic>{
              'label': 'Open detail',
              'action': <String, dynamic>{
                'type': 'router.push',
                'props': <String, dynamic>{
                  'screenId': 'mp_router_detail',
                  'params': <String, dynamic>{'productId': 'p1'},
                },
              },
            },
            'children': <Object?>[],
          },
        ],
      },
    };
  }
}

class _SameScreenReplaceSource implements MiniProgramSource {
  const _SameScreenReplaceSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'same_screen_replace',
      version: '1.0.0',
      entry: 'same_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <CapabilityId>[],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{
      'schemaVersion': 1,
      'screenId': 'same_home',
      'root': <String, dynamic>{
        'type': 'countdown',
        'props': <String, dynamic>{
          'durationMs': 10000,
          'running': true,
          'remainingState': 'same.remaining',
        },
        'children': <Object?>[
          <String, dynamic>{
            'type': 'column',
            'props': <String, dynamic>{},
            'children': <Object?>[
              <String, dynamic>{
                'type': 'text',
                'props': <String, dynamic>{'data': '{{state.same.remaining}}'},
                'children': <Object?>[],
              },
              <String, dynamic>{
                'type': 'primaryButton',
                'props': <String, dynamic>{
                  'label': 'Next question',
                  'action': <String, dynamic>{
                    'type': 'router.replace',
                    'props': <String, dynamic>{'screenId': 'same_home'},
                  },
                },
                'children': <Object?>[],
              },
            ],
          },
        ],
      },
    };
  }
}

class _CachePolicyMpSource
    implements MiniProgramSource, MiniProgramCachePolicyProvider {
  const _CachePolicyMpSource();

  @override
  MiniProgramCachePolicy cachePolicyFor(String miniProgramId) {
    return const MiniProgramCachePolicy(
      memoryTtl: Duration(minutes: 5),
      clearMemoryOnExit: true,
    );
  }

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'mp_cache_test',
      version: '1.0.0',
      entry: 'mp_cache_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <CapabilityId>[],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{
      'schemaVersion': 1,
      'screenId': 'mp_cache_home',
      'root': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Cache policy host screen'},
        'children': <Object?>[],
      },
    };
  }
}

class _OfflineMpSource implements MiniProgramSource {
  const _OfflineMpSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) {
    throw const MiniProgramSourceException(
      message: 'Backend unavailable.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    throw const MiniProgramSourceException(
      message: 'Backend unavailable.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
    );
  }
}

class _HostBridge implements HostBridge {
  const _HostBridge();

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => HostActionResult.success(actionName: ActionNames.callSecureApi);

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => HostActionResult.success(actionName: ActionNames.openNativeScreen);

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success(actionName: ActionNames.trackEvent);
}
