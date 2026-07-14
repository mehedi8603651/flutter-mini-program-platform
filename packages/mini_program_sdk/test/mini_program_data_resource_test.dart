import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgramDataResourceManager', () {
    test('persists resources and isolates cache entries by version', () async {
      final cache = MiniProgramCacheManager.inMemory();
      final source = _JsonAssetSource(<String, Object?>{
        'data/places.json': <String, Object?>{
          'locations': <Object?>[
            <String, Object?>{'name': 'Dhaka'},
          ],
        },
      });
      final manager = MiniProgramDataResourceManager();
      final first = await manager.load(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        assetPath: 'data/places.json',
        ttl: const Duration(days: 30),
        forceRefresh: false,
        source: source,
        cacheManager: cache,
        cachePolicy: const MiniProgramCachePolicy(),
      );
      expect(first.fromCache, isFalse);
      expect(source.loadCount, 1);

      final restored = await MiniProgramDataResourceManager().load(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        assetPath: 'data/places.json',
        ttl: const Duration(days: 30),
        forceRefresh: false,
        source: null,
        cacheManager: cache,
        cachePolicy: const MiniProgramCachePolicy(),
      );
      expect(restored.fromCache, isTrue);

      await expectLater(
        MiniProgramDataResourceManager().load(
          appId: 'weather',
          version: '2.0.0',
          resourceId: 'places',
          assetPath: 'data/places.json',
          ttl: const Duration(days: 30),
          forceRefresh: false,
          source: null,
          cacheManager: cache,
          cachePolicy: const MiniProgramCachePolicy(),
        ),
        throwsA(
          isA<MiniProgramDataException>().having(
            (error) => error.code,
            'code',
            MiniProgramErrorCodes.dataAssetUnavailable,
          ),
        ),
      );
    });

    test('force refresh bypasses a valid persistent value', () async {
      final cache = MiniProgramCacheManager.inMemory();
      final source = _JsonAssetSource(<String, Object?>{
        'data/places.json': <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ],
      });
      final manager = MiniProgramDataResourceManager();
      for (final forceRefresh in <bool>[false, true]) {
        await manager.load(
          appId: 'weather',
          version: '1.0.0',
          resourceId: 'places',
          assetPath: 'data/places.json',
          ttl: const Duration(days: 30),
          forceRefresh: forceRefresh,
          source: source,
          cacheManager: cache,
          cachePolicy: const MiniProgramCachePolicy(),
        );
      }
      expect(source.loadCount, 2);
    });

    test('ranks text deterministically and normalizes diacritics', () async {
      final manager = MiniProgramDataResourceManager();
      await manager.load(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        assetPath: 'data/places.json',
        ttl: const Duration(days: 30),
        forceRefresh: false,
        source: _JsonAssetSource(<String, Object?>{
          'data/places.json': <String, Object?>{
            'locations': <Object?>[
              <String, Object?>{'name': 'Old Dhaka'},
              <String, Object?>{'name': 'Dhaka North'},
              <String, Object?>{'name': 'Dhaka'},
              <String, Object?>{'name': 'Cafe Road', 'district': 'Café'},
            ],
          },
        }),
        cacheManager: MiniProgramCacheManager.inMemory(),
        cachePolicy: const MiniProgramCachePolicy(),
      );

      final result = await manager.search(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        query: 'dhaka',
        fields: const <String>['name', 'district'],
        itemsPath: 'locations',
        minQueryLength: 2,
        limit: 3,
        targetState: 'location.results',
      );
      final items = result!['items'] as List;
      expect((items.first as Map)['name'], 'Dhaka');
      expect(result['matchCount'], 3);
      expect(result['truncated'], isFalse);

      final accentResult = await manager.search(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        query: 'cafe',
        fields: const <String>['name', 'district'],
        itemsPath: 'locations',
        minQueryLength: 2,
        limit: 10,
        targetState: 'location.results',
      );
      expect(accentResult!['matchCount'], 1);
    });

    test('rejects disabled cache, malformed JSON, and unsafe paths', () async {
      final manager = MiniProgramDataResourceManager();
      final source = _RawAssetSource(<int>[0x7b]);
      await expectLater(
        manager.load(
          appId: 'weather',
          version: '1.0.0',
          resourceId: 'places',
          assetPath: 'data/places.json',
          ttl: const Duration(days: 1),
          forceRefresh: false,
          source: source,
          cacheManager: MiniProgramCacheManager.inMemory(),
          cachePolicy: const MiniProgramCachePolicy(
            allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
              MiniProgramCacheBucket.state,
            },
          ),
        ),
        throwsA(
          isA<MiniProgramDataException>().having(
            (error) => error.code,
            'code',
            'cache_bucket_disabled',
          ),
        ),
      );

      await expectLater(
        manager.load(
          appId: 'weather',
          version: '1.0.0',
          resourceId: 'places',
          assetPath: 'data/places.json',
          ttl: const Duration(days: 1),
          forceRefresh: true,
          source: source,
          cacheManager: MiniProgramCacheManager.inMemory(),
          cachePolicy: const MiniProgramCachePolicy(),
        ),
        throwsA(
          isA<MiniProgramDataException>().having(
            (error) => error.code,
            'code',
            MiniProgramErrorCodes.dataInvalidJson,
          ),
        ),
      );

      await expectLater(
        manager.load(
          appId: 'weather',
          version: '1.0.0',
          resourceId: 'places',
          assetPath: '../places.json',
          ttl: const Duration(days: 1),
          forceRefresh: true,
          source: source,
          cacheManager: MiniProgramCacheManager.inMemory(),
          cachePolicy: const MiniProgramCachePolicy(),
        ),
        throwsA(isA<MiniProgramDataException>()),
      );
    });
  });
}

class _JsonAssetSource implements MiniProgramJsonAssetSource {
  _JsonAssetSource(this.assets);

  final Map<String, Object?> assets;
  int loadCount = 0;

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async {
    loadCount += 1;
    return utf8.encode(jsonEncode(assets[assetPath]));
  }
}

class _RawAssetSource implements MiniProgramJsonAssetSource {
  _RawAssetSource(this.bytes);

  final List<int> bytes;

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async => bytes;
}
