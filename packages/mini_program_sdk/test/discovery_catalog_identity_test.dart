import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart'
    hide MiniProgramCachePolicy;

void main() {
  group('published catalog identity', () {
    test(
      'preserves URI resolution, entry order, and trace precedence',
      () async {
        late Uri requestedUri;
        final client = PublishedMiniProgramCatalogClient(
          apiBaseUri: Uri.parse('https://catalog.example.com/api'),
          queryParameters: const <String, String>{
            'hostApp': 'identity_host',
            'locale': 'en-US',
          },
          client: MockClient((request) async {
            requestedUri = request.url;
            return http.Response(
              jsonEncode(<String, Object?>{
                'traceId': 'body-trace',
                'entries': <Object?>[
                  <String, Object?>{
                    'id': 'weather',
                    'title': 'Weather',
                    'description': 'Forecasts',
                    'entry': 'weather/home',
                    'resolvedVersion': '1.0.0',
                    'requiredCapabilities': <Object?>[
                      'secure_api',
                      'analytics',
                    ],
                    'selectionMode': 7,
                    'decisionReason': true,
                    'matchedRuleId': 'rule-1',
                  },
                  <String, Object?>{
                    'id': 'calculator',
                    'title': 'Calculator',
                    'description': 'Math',
                    'entry': 'calculator/home',
                    'resolvedVersion': '2.0.0',
                  },
                ],
              }),
              200,
              headers: const <String, String>{
                'x-backend-trace-id': 'header-trace',
              },
            );
          }),
        );

        final catalog = await client.listAvailableMiniPrograms();

        expect(
          requestedUri.toString(),
          'https://catalog.example.com/api/discovery/mini-programs.json'
          '?hostApp=identity_host&locale=en-US',
        );
        expect(catalog.traceId, 'body-trace');
        expect(catalog.entries.map((entry) => entry.id), <String>[
          'weather',
          'calculator',
        ]);
        expect(catalog.entries.first.requiredCapabilities, <CapabilityId>[
          CapabilityIds.secureApi,
          CapabilityIds.analytics,
        ]);
        expect(catalog.entries.first.selectionMode, '7');
        expect(catalog.entries.first.decisionReason, 'true');
        expect(catalog.entries.last.requiredCapabilities, isEmpty);
      },
    );

    test('uses response trace header when the body omits traceId', () async {
      final client = PublishedMiniProgramCatalogClient(
        apiBaseUri: Uri.parse('https://catalog.example.com/'),
        client: MockClient(
          (request) async => http.Response(
            '{"entries":[]}',
            200,
            headers: const <String, String>{
              'x-backend-trace-id': 'header-trace',
            },
          ),
        ),
      );

      final catalog = await client.listAvailableMiniPrograms();

      expect(catalog.entries, isEmpty);
      expect(catalog.traceId, 'header-trace');
    });

    test('preserves nested backend errors and details', () async {
      final client = PublishedMiniProgramCatalogClient(
        apiBaseUri: Uri.parse('https://catalog.example.com/'),
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, Object?>{
              'responseType': 'mini_program_catalog_error',
              'traceId': 'body-trace',
              'error': <String, Object?>{
                'code': 'catalog_denied',
                'message': 'Catalog access denied.',
                'details': <String, Object?>{
                  'tenantId': 'tenant-a',
                  'retryable': false,
                },
              },
            }),
            403,
            headers: const <String, String>{
              'x-backend-trace-id': 'header-trace',
            },
          ),
        ),
      );

      await expectLater(
        client.listAvailableMiniPrograms,
        throwsA(
          isA<MiniProgramSourceException>()
              .having((error) => error.errorCode, 'errorCode', 'catalog_denied')
              .having(
                (error) => error.message,
                'message',
                'Catalog access denied.',
              )
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.details, 'details', <String, dynamic>{
                'uri':
                    'https://catalog.example.com/discovery/mini-programs.json',
                'resourceLabel': 'mini_program_catalog',
                'statusCode': 403,
                'responseType': 'mini_program_catalog_error',
                'traceId': 'body-trace',
                'tenantId': 'tenant-a',
                'retryable': false,
              }),
        ),
      );
    });

    test('preserves malformed success and error response behavior', () async {
      final successClient = PublishedMiniProgramCatalogClient(
        apiBaseUri: Uri.parse('https://catalog.example.com/'),
        client: MockClient((request) async => http.Response('[]', 200)),
      );
      await expectLater(
        successClient.listAvailableMiniPrograms,
        throwsA(isA<FormatException>()),
      );

      final errorClient = PublishedMiniProgramCatalogClient(
        apiBaseUri: Uri.parse('https://catalog.example.com/'),
        client: MockClient((request) async => http.Response('<html>', 502)),
      );
      await expectLater(
        errorClient.listAvailableMiniPrograms,
        throwsA(
          isA<MiniProgramSourceException>()
              .having((error) => error.errorCode, 'errorCode', isNull)
              .having((error) => error.message, 'message', contains('HTTP 502'))
              .having((error) => error.details, 'details', <String, dynamic>{
                'uri':
                    'https://catalog.example.com/discovery/mini-programs.json',
                'resourceLabel': 'mini_program_catalog',
                'statusCode': 502,
              }),
        ),
      );
    });
  });

  group('discovery availability identity', () {
    test(
      'reads cache before source and mutates cache only for remote',
      () async {
        final events = <String>[];
        final remoteCache = _RecordingManifestCache(events: events);
        final resolver = MiniProgramDiscoveryResolver(
          now: () => DateTime.utc(2026, 7, 16, 10),
        );

        final remote = await resolver.resolve(
          miniProgramId: 'weather',
          source: _RecordingSource(
            events: events,
            manifest: _cacheableManifest,
          ),
          manifestCache: remoteCache,
          screenCache: _RecordingScreenCache(events: events),
          sourceKind: MiniProgramDiscoverySourceKind.remote,
        );

        expect(events, <String>[
          'manifest.read',
          'source.loadManifest',
          'manifest.write',
        ]);
        expect(remote.status, MiniProgramDiscoveryStatus.live);
        expect(remoteCache.written?.cachedAt, DateTime.utc(2026, 7, 16, 10));

        events.clear();
        final bundledCache = _RecordingManifestCache(events: events);
        final bundled = await resolver.resolve(
          miniProgramId: 'weather',
          source: _RecordingSource(
            events: events,
            manifest: _cacheableManifest,
          ),
          manifestCache: bundledCache,
          screenCache: _RecordingScreenCache(events: events),
          sourceKind: MiniProgramDiscoverySourceKind.bundled,
        );

        expect(events, <String>['manifest.read', 'source.loadManifest']);
        expect(bundled.status, MiniProgramDiscoveryStatus.cached);
        expect(bundledCache.written, isNull);
        expect(bundledCache.removedIds, isEmpty);
      },
    );

    test('remote no-cache manifest removes an existing cached entry', () async {
      final events = <String>[];
      final cache = _RecordingManifestCache(events: events);
      final result =
          await MiniProgramDiscoveryResolver(
            now: () => DateTime.utc(2026, 7, 16, 10),
          ).resolve(
            miniProgramId: 'weather',
            source: _RecordingSource(
              events: events,
              manifest: _noCacheManifest,
            ),
            manifestCache: cache,
            screenCache: _RecordingScreenCache(events: events),
            sourceKind: MiniProgramDiscoverySourceKind.remote,
          );

      expect(result.status, MiniProgramDiscoveryStatus.live);
      expect(events, <String>[
        'manifest.read',
        'source.loadManifest',
        'manifest.remove',
      ]);
      expect(cache.removedIds, <String>['weather']);
    });

    test(
      'offline fallback is inclusive at both stale-age boundaries',
      () async {
        final now = DateTime.utc(2026, 7, 16, 12);
        final events = <String>[];
        final cachedManifest = CachedManifestEntry(
          miniProgramId: 'weather',
          manifest: _cacheableManifest,
          cachedAt: now.subtract(const Duration(hours: 1)),
        );
        final cachedScreen = CachedScreenEntry(
          miniProgramId: 'weather',
          version: '1.0.0',
          screenId: 'weather/home',
          screenJson: const <String, dynamic>{'type': 'text', 'data': 'Cached'},
          cachedAt: now.subtract(const Duration(hours: 1)),
        );

        final result = await MiniProgramDiscoveryResolver(now: () => now)
            .resolve(
              miniProgramId: 'weather',
              source: _RecordingSource(
                events: events,
                exception: const MiniProgramSourceException(
                  message: 'Offline.',
                  errorCode: MiniProgramErrorCodes.backendUnreachable,
                  details: <String, dynamic>{'traceId': 'offline-trace'},
                ),
              ),
              manifestCache: _RecordingManifestCache(
                events: events,
                entry: cachedManifest,
              ),
              screenCache: _RecordingScreenCache(
                events: events,
                entry: cachedScreen,
              ),
              sourceKind: MiniProgramDiscoverySourceKind.remote,
            );

        expect(events, <String>[
          'manifest.read',
          'source.loadManifest',
          'screen.read',
        ]);
        expect(result.status, MiniProgramDiscoveryStatus.staleButAllowed);
        expect(result.canOpen, isTrue);
        expect(result.badgeLabel, 'Offline');
        expect(result.manifestCachedAt, cachedManifest.cachedAt);
        expect(result.entryScreenCachedAt, cachedScreen.cachedAt);
        expect(result.details, <String, dynamic>{
          'offlineFallback': true,
          'traceId': 'offline-trace',
        });
      },
    );

    test('non-retryable failures do not read the screen cache', () async {
      final now = DateTime.utc(2026, 7, 16, 12);
      final events = <String>[];
      final result = await MiniProgramDiscoveryResolver(now: () => now).resolve(
        miniProgramId: 'weather',
        source: _RecordingSource(
          events: events,
          exception: const MiniProgramSourceException(
            message: 'Manifest rejected.',
            errorCode: 'manifest_rejected',
            details: <String, dynamic>{'reason': 'policy'},
          ),
        ),
        manifestCache: _RecordingManifestCache(
          events: events,
          entry: CachedManifestEntry(
            miniProgramId: 'weather',
            manifest: _cacheableManifest,
            cachedAt: now,
          ),
        ),
        screenCache: _RecordingScreenCache(events: events),
        sourceKind: MiniProgramDiscoverySourceKind.remote,
      );

      expect(events, <String>['manifest.read', 'source.loadManifest']);
      expect(result.status, MiniProgramDiscoveryStatus.unavailable);
      expect(result.message, 'Manifest rejected.');
      expect(result.details, <String, dynamic>{
        'manifestCacheExpired': false,
        'reason': 'policy',
      });
    });

    test(
      'expired cache and unknown failures preserve unavailable metadata',
      () async {
        final now = DateTime.utc(2026, 7, 16, 12);
        final events = <String>[];
        final cachedAt = now.subtract(const Duration(hours: 2));
        final result = await MiniProgramDiscoveryResolver(now: () => now)
            .resolve(
              miniProgramId: 'weather',
              source: _RecordingSource(
                events: events,
                exception: StateError('unexpected'),
              ),
              manifestCache: _RecordingManifestCache(
                events: events,
                entry: CachedManifestEntry(
                  miniProgramId: 'weather',
                  manifest: _cacheableManifest,
                  cachedAt: cachedAt,
                ),
              ),
              screenCache: _RecordingScreenCache(events: events),
              sourceKind: MiniProgramDiscoverySourceKind.remote,
            );

        expect(result.status, MiniProgramDiscoveryStatus.unavailable);
        expect(result.errorCode, isNull);
        expect(result.manifest, same(_cacheableManifest));
        expect(result.manifestCachedAt, cachedAt);
        expect(
          result.message,
          'Mini-program availability could not be determined.',
        );
        expect(result.details, <String, dynamic>{'manifestCacheExpired': true});
        expect(result.badgeLabel, 'Unavailable');
        expect(result.canOpen, isFalse);
      },
    );
  });
}

const MiniProgramManifest _cacheableManifest = MiniProgramManifest(
  id: 'weather',
  version: '1.0.0',
  entry: 'weather/home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=0.5.13 <1.0.0'),
  requiredCapabilities: <CapabilityId>[],
  cachePolicy: MiniProgramCachePolicy(
    manifest: MiniProgramCacheRule(
      mode: MiniProgramCacheMode.staleWhileError,
      maxStaleSeconds: 3600,
    ),
    entryScreen: MiniProgramCacheRule(
      mode: MiniProgramCacheMode.staleWhileError,
      maxStaleSeconds: 3600,
    ),
  ),
);

const MiniProgramManifest _noCacheManifest = MiniProgramManifest(
  id: 'weather',
  version: '1.0.0',
  entry: 'weather/home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=0.5.13 <1.0.0'),
  requiredCapabilities: <CapabilityId>[],
  cachePolicy: MiniProgramCachePolicy(
    manifest: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
    entryScreen: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
  ),
);

class _RecordingSource implements MiniProgramSource {
  const _RecordingSource({required this.events, this.manifest, this.exception});

  final List<String> events;
  final MiniProgramManifest? manifest;
  final Object? exception;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    events.add('source.loadManifest');
    final failure = exception;
    if (failure != null) {
      throw failure;
    }
    return manifest!;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{};
  }
}

class _RecordingManifestCache implements ManifestCache {
  _RecordingManifestCache({required this.events, this.entry});

  final List<String> events;
  final CachedManifestEntry? entry;
  CachedManifestEntry? written;
  final List<String> removedIds = <String>[];

  @override
  Future<CachedManifestEntry?> read(String miniProgramId) async {
    events.add('manifest.read');
    return entry;
  }

  @override
  Future<void> write(CachedManifestEntry entry) async {
    events.add('manifest.write');
    written = entry;
  }

  @override
  Future<void> remove(String miniProgramId) async {
    events.add('manifest.remove');
    removedIds.add(miniProgramId);
  }

  @override
  Future<void> clear() async {}
}

class _RecordingScreenCache implements ScreenCache {
  _RecordingScreenCache({required this.events, this.entry});

  final List<String> events;
  final CachedScreenEntry? entry;

  @override
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    events.add('screen.read');
    return entry;
  }

  @override
  Future<void> write(CachedScreenEntry entry) async {}

  @override
  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {}

  @override
  Future<void> clear() async {}
}
