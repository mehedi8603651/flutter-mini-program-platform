import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart'
    hide MiniProgramCachePolicy;

void main() {
  group('asset resolution identity', () {
    test(
      'disabled screen caching returns a shallow clone without work',
      () async {
        final nestedBody = <String, dynamic>{
          'type': 'image',
          'src': 'https://cdn.example.com/banner.png',
        };
        final screen = <String, dynamic>{
          'type': 'scaffold',
          'body': nestedBody,
        };
        var requestCount = 0;
        final cache = _RecordingAssetCache();
        final resolver = AssetResolver(
          client: MockClient((request) async {
            requestCount++;
            return http.Response.bytes(const <int>[1], 200);
          }),
        );

        final result = await resolver.resolveEntryScreenAssets(
          manifest: _noCacheManifest,
          screenJson: screen,
          assetCache: cache,
          logger: _RecordingLogger(),
        );

        expect(result.screenJson, equals(screen));
        expect(result.screenJson, isNot(same(screen)));
        expect(result.screenJson['body'], same(nestedBody));
        expect(result.resolvedAssetCount, 0);
        expect(result.failedAssetCount, 0);
        expect(requestCount, 0);
        expect(cache.reads, isEmpty);
        expect(cache.writes, isEmpty);
      },
    );

    test(
      'recursively rewrites eligible images in deterministic traversal order',
      () async {
        final requestedUris = <String>[];
        final cache = _RecordingAssetCache();
        final resolver = AssetResolver(
          client: MockClient((request) async {
            requestedUris.add(request.url.toString());
            return http.Response.bytes(
              <int>[requestedUris.length],
              200,
              headers: <String, String>{
                'content-type': requestedUris.length == 1
                    ? 'image/png'
                    : 'image/jpeg',
              },
            );
          }),
        );
        final screen = <String, dynamic>{
          'type': 'column',
          'children': <Object?>[
            <String, dynamic>{
              'type': 'image',
              'src': 'https://cdn.example.com/first.png',
            },
            <String, dynamic>{
              'type': 'container',
              'child': <String, dynamic>{
                'type': 'image',
                'src': 'http://cdn.example.com/second.JPEG',
                'imageType': 'network',
              },
            },
            <String, dynamic>{
              'type': 'image',
              'src': 'https://cdn.example.com/already-file.png',
              'imageType': 'file',
            },
            <String, dynamic>{
              'type': 'image',
              'src': 'assets/local.png',
              'imageType': 'network',
            },
            <String, dynamic>{
              'type': 'text',
              'src': 'https://cdn.example.com/not-an-image.png',
            },
          ],
        };

        final result = await resolver.resolveScreenAssets(
          manifest: _cacheableManifest,
          screenId: 'weather/details',
          screenJson: screen,
          assetCache: cache,
          logger: _RecordingLogger(),
        );

        expect(requestedUris, <String>[
          'https://cdn.example.com/first.png',
          'http://cdn.example.com/second.JPEG',
        ]);
        expect(cache.writes.map((write) => write.sourceUri), requestedUris);
        expect(
          cache.writes.map((write) => write.suggestedFileExtension),
          <String?>['.png', '.jpg'],
        );
        expect(cache.writes.map((write) => write.contentType), <String?>[
          'image/png',
          'image/jpeg',
        ]);
        expect(result.downloadedAssetCount, 2);
        expect(result.cachedAssetCount, 0);
        expect(result.failedAssetCount, 0);
        expect(result.resolvedAssetCount, 2);

        final children = result.screenJson['children'] as List<dynamic>;
        expect((children[0] as Map)['imageType'], 'file');
        expect((children[0] as Map)['src'], '/cache/1.png');
        expect(((children[1] as Map)['child'] as Map)['src'], '/cache/2.jpg');
        expect((children[2] as Map)['imageType'], 'file');
        expect((children[3] as Map)['src'], 'assets/local.png');
        expect(
          (children[4] as Map)['src'],
          'https://cdn.example.com/not-an-image.png',
        );
      },
    );

    test(
      'fresh cache short-circuits the network and preserves properties',
      () async {
        const sourceUri = 'https://cdn.example.com/banner.webp';
        final cache = _RecordingAssetCache(
          readsByUri: <String, List<CachedAssetEntry?>>{
            sourceUri: <CachedAssetEntry?>[
              CachedAssetEntry(
                sourceUri: sourceUri,
                filePath: '/cache/banner.webp',
                cachedAt: DateTime.now(),
                contentType: 'image/webp',
              ),
            ],
          },
        );
        var requestCount = 0;
        final resolver = AssetResolver(
          client: MockClient((request) async {
            requestCount++;
            return http.Response.bytes(const <int>[1], 200);
          }),
        );

        final result = await resolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest,
          screenJson: const <String, dynamic>{
            'type': 'image',
            'src': sourceUri,
            'width': 140,
            'semanticLabel': 'Forecast',
          },
          assetCache: cache,
          logger: _RecordingLogger(),
        );

        expect(requestCount, 0);
        expect(cache.reads, <String>[sourceUri]);
        expect(cache.writes, isEmpty);
        expect(result.screenJson, <String, dynamic>{
          'type': 'image',
          'src': '/cache/banner.webp',
          'width': 140,
          'semanticLabel': 'Forecast',
          'imageType': 'file',
        });
        expect(result.cachedAssetCount, 1);
      },
    );

    test(
      'download failure performs a second cache read before failing',
      () async {
        const sourceUri = 'https://cdn.example.com/offline.svg';
        final cache = _RecordingAssetCache(
          readsByUri: <String, List<CachedAssetEntry?>>{
            sourceUri: <CachedAssetEntry?>[
              null,
              CachedAssetEntry(
                sourceUri: sourceUri,
                filePath: '/cache/offline.svg',
                cachedAt: DateTime.now(),
                contentType: 'image/svg+xml',
              ),
            ],
          },
        );
        final logger = _RecordingLogger();
        final resolver = AssetResolver(
          client: MockClient((request) async {
            throw http.ClientException('offline', request.url);
          }),
        );

        final result = await resolver.resolveScreenAssets(
          manifest: _cacheableManifest,
          screenId: 'weather/details',
          screenJson: const <String, dynamic>{
            'type': 'image',
            'src': sourceUri,
            'imageType': 'network',
          },
          assetCache: cache,
          logger: logger,
        );

        expect(cache.reads, <String>[sourceUri, sourceUri]);
        expect(result.cachedAssetCount, 1);
        expect(result.failedAssetCount, 0);
        expect(result.screenJson['src'], '/cache/offline.svg');
        expect(logger.events.map((event) => event.level), <String>[
          'warn',
          'error',
        ]);
        expect(logger.events.first.context, <String, Object?>{
          'miniProgramId': 'weather',
          'screenId': 'weather/details',
          'assetUrl': sourceUri,
        });
        expect(logger.events.map((event) => event.message), <String>[
          'Failed to download image asset for mini-program screen.',
          'Asset resolution failure details.',
        ]);
      },
    );

    test(
      'timeout and unsuccessful responses preserve network images',
      () async {
        final timeoutLogger = _RecordingLogger();
        final timeoutCache = _RecordingAssetCache();
        final timeoutResolver = AssetResolver(
          client: MockClient((request) async {
            throw TimeoutException('timeout');
          }),
        );
        final timeoutResult = await timeoutResolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest,
          screenJson: _networkImage('https://cdn.example.com/timeout.gif'),
          assetCache: timeoutCache,
          logger: timeoutLogger,
        );

        expect(timeoutResult.failedAssetCount, 1);
        expect(timeoutResult.screenJson['imageType'], 'network');
        expect(timeoutCache.reads, hasLength(2));
        expect(timeoutLogger.events.map((event) => event.message), <String>[
          'Timed out while resolving image asset for mini-program screen.',
          'Asset resolution timeout details.',
        ]);

        final responseLogger = _RecordingLogger();
        final responseCache = _RecordingAssetCache();
        final responseResolver = AssetResolver(
          client: MockClient((request) async => http.Response('', 503)),
        );
        final responseResult = await responseResolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest,
          screenJson: _networkImage('https://cdn.example.com/unavailable.png'),
          assetCache: responseCache,
          logger: responseLogger,
        );

        expect(responseResult.failedAssetCount, 1);
        expect(responseResult.screenJson['imageType'], 'network');
        expect(responseCache.reads, hasLength(2));
        expect(responseCache.writes, isEmpty);
        expect(responseLogger.events, isEmpty);
      },
    );
  });
}

Map<String, dynamic> _networkImage(String sourceUri) => <String, dynamic>{
  'type': 'image',
  'src': sourceUri,
  'imageType': 'network',
};

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

class _RecordingAssetCache implements AssetCache {
  _RecordingAssetCache({
    Map<String, List<CachedAssetEntry?>> readsByUri =
        const <String, List<CachedAssetEntry?>>{},
  }) : _readsByUri = readsByUri.map(
         (key, value) => MapEntry(key, List<CachedAssetEntry?>.from(value)),
       );

  final Map<String, List<CachedAssetEntry?>> _readsByUri;
  final List<String> reads = <String>[];
  final List<_AssetWrite> writes = <_AssetWrite>[];

  @override
  Future<CachedAssetEntry?> read(String sourceUri) async {
    reads.add(sourceUri);
    final entries = _readsByUri[sourceUri];
    if (entries == null || entries.isEmpty) {
      return null;
    }
    return entries.removeAt(0);
  }

  @override
  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  }) async {
    writes.add(
      _AssetWrite(
        sourceUri: sourceUri,
        bytes: List<int>.from(bytes),
        cachedAt: cachedAt,
        contentType: contentType,
        suggestedFileExtension: suggestedFileExtension,
      ),
    );
    return CachedAssetEntry(
      sourceUri: sourceUri,
      filePath: '/cache/${writes.length}${suggestedFileExtension ?? '.bin'}',
      cachedAt: cachedAt,
      contentType: contentType,
    );
  }

  @override
  Future<void> remove(String sourceUri) async {}

  @override
  Future<void> clear() async {}
}

class _AssetWrite {
  const _AssetWrite({
    required this.sourceUri,
    required this.bytes,
    required this.cachedAt,
    required this.contentType,
    required this.suggestedFileExtension,
  });

  final String sourceUri;
  final List<int> bytes;
  final DateTime cachedAt;
  final String? contentType;
  final String? suggestedFileExtension;
}

class _RecordingLogger implements SdkLogger {
  final List<_LogEvent> events = <_LogEvent>[];

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    events.add(_LogEvent('info', message, context));
  }

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {
    events.add(_LogEvent('warn', message, context));
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    events.add(_LogEvent('error', message, context));
  }
}

class _LogEvent {
  const _LogEvent(this.level, this.message, this.context);

  final String level;
  final String message;
  final Map<String, Object?> context;
}
