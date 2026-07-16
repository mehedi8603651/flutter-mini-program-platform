import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('load result and errors preserve public JSON and details', () {
    const result = MiniProgramDataResourceLoadResult(
      id: 'places',
      asset: 'data/places.json',
      fromCache: true,
      bytes: 128,
    );
    const error = MiniProgramDataException(
      code: 'data_failed',
      message: 'Data failed.',
      details: <String, dynamic>{'asset': 'data/places.json'},
    );

    expect(result.toJson().keys, <String>['id', 'asset', 'fromCache', 'bytes']);
    expect(error.toString(), 'Data failed.');
    expect(error.details, <String, dynamic>{'asset': 'data/places.json'});
  });

  test('loading preserves source failure mapping and passthrough', () async {
    final manager = MiniProgramDataResourceManager();

    await expectLater(
      _load(
        manager,
        source: const _FailingSource(
          MiniProgramSourceException(
            message: 'Missing.',
            statusCode: 404,
            details: <String, dynamic>{'origin': 'cdn'},
          ),
        ),
      ),
      throwsA(
        isA<MiniProgramDataException>()
            .having(
              (error) => error.code,
              'code',
              MiniProgramErrorCodes.dataResourceNotFound,
            )
            .having((error) => error.details, 'details', <String, dynamic>{
              'asset': 'data/places.json',
            }),
      ),
    );
    await expectLater(
      _load(
        manager,
        source: const _FailingSource(
          MiniProgramSourceException(
            message: 'Assets disabled.',
            errorCode: MiniProgramErrorCodes.dataAssetUnavailable,
            details: <String, dynamic>{'reason': 'unsupported'},
          ),
        ),
      ),
      throwsA(
        isA<MiniProgramDataException>()
            .having(
              (error) => error.code,
              'code',
              MiniProgramErrorCodes.dataAssetUnavailable,
            )
            .having((error) => error.details, 'details', <String, dynamic>{
              'reason': 'unsupported',
            }),
      ),
    );
    await expectLater(
      _load(
        manager,
        source: const _FailingSource(
          MiniProgramSourceException(
            message: 'Transport failed.',
            errorCode: 'transport_failed',
            statusCode: 503,
          ),
        ),
      ),
      throwsA(
        isA<MiniProgramSourceException>().having(
          (error) => error.errorCode,
          'errorCode',
          'transport_failed',
        ),
      ),
    );
  });

  test(
    'cache is read before source availability and force refresh bypasses it',
    () async {
      final cache = MiniProgramCacheManager.inMemory();
      final firstSource = _JsonSource(_locations('Dhaka'));
      final manager = MiniProgramDataResourceManager();
      await _load(manager, source: firstSource, cacheManager: cache);

      final restored = await _load(
        MiniProgramDataResourceManager(),
        source: null,
        cacheManager: cache,
      );
      final refreshedSource = _JsonSource(_locations('Chattogram'));
      final refreshed = await _load(
        manager,
        source: refreshedSource,
        cacheManager: cache,
        forceRefresh: true,
      );

      expect(restored.fromCache, isTrue);
      expect(refreshed.fromCache, isFalse);
      expect(firstSource.calls, 1);
      expect(refreshedSource.calls, 1);
    },
  );

  test('resource replacement invalidates an existing search index', () async {
    final manager = MiniProgramDataResourceManager();
    final cache = MiniProgramCacheManager.inMemory();
    await _load(
      manager,
      source: _JsonSource(_locations('Dhaka')),
      cacheManager: cache,
    );
    expect((await _search(manager, 'Dhaka'))!['matchCount'], 1);

    await _load(
      manager,
      source: _JsonSource(_locations('Chattogram')),
      cacheManager: cache,
      forceRefresh: true,
    );

    expect((await _search(manager, 'Dhaka'))!['matchCount'], 0);
    final result = await _search(manager, 'Chattogram');
    expect(result!['matchCount'], 1);
    expect(((result['items'] as List).single as Map)['name'], 'Chattogram');
  });

  test(
    'search preserves exact, prefix, contains, and source tie order',
    () async {
      final manager = MiniProgramDataResourceManager();
      await _load(
        manager,
        source: _JsonSource(<String, dynamic>{
          'locations': <Object?>[
            <String, dynamic>{'name': 'Old Dhaka'},
            <String, dynamic>{'name': 'Dhaka North'},
            <String, dynamic>{'name': 'Adhaka'},
            <String, dynamic>{'name': 'Dhaka'},
          ],
        }),
      );

      final result = await _search(manager, 'dhaka', limit: 3);
      final names = (result!['items'] as List)
          .map((item) => (item as Map)['name'])
          .toList();

      expect(names, <Object?>['Dhaka', 'Old Dhaka', 'Dhaka North']);
      expect(result['matchCount'], 4);
      expect(result['truncated'], isTrue);
      expect(result.keys, <String>[
        'query',
        'items',
        'matchCount',
        'truncated',
      ]);
    },
  );

  test(
    'search supports nested paths and primitive searchable fields',
    () async {
      final manager = MiniProgramDataResourceManager();
      await _load(
        manager,
        source: _JsonSource(<String, dynamic>{
          'payload': <String, dynamic>{
            'items': <Object?>[
              <String, dynamic>{
                'meta': <String, dynamic>{'code': 120, 'active': true},
              },
            ],
          },
        }),
      );

      final result = await manager.search(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        query: '120 true',
        fields: const <String>['meta.code', 'meta.active'],
        itemsPath: 'payload.items',
        minQueryLength: 1,
        limit: 10,
        targetState: 'location.results',
      );

      expect(result!['matchCount'], 1);
    },
  );

  test(
    'short query returns idle data before requiring a loaded resource',
    () async {
      final manager = MiniProgramDataResourceManager();

      final result = await manager.search(
        appId: 'weather',
        version: '9.9.9',
        resourceId: 'missing',
        query: ' a ',
        fields: const <String>['name'],
        itemsPath: null,
        minQueryLength: 2,
        limit: 10,
        targetState: 'location.results',
      );

      expect(result, <String, dynamic>{
        'query': 'a',
        'items': <Object?>[],
        'matchCount': 0,
        'truncated': false,
      });
    },
  );

  test('search length validation uses the untrimmed query', () async {
    final manager = MiniProgramDataResourceManager();

    await expectLater(
      manager.search(
        appId: 'weather',
        version: '1.0.0',
        resourceId: 'places',
        query: ' ${'a' * 255} ',
        fields: const <String>['name'],
        itemsPath: null,
        minQueryLength: 2,
        limit: 10,
        targetState: 'location.results',
      ),
      throwsA(
        isA<MiniProgramDataException>().having(
          (error) => error.code,
          'code',
          MiniProgramErrorCodes.dataInvalidQuery,
        ),
      ),
    );
  });

  test('newer search suppresses an older search for the same target', () async {
    final manager = MiniProgramDataResourceManager();
    await _load(
      manager,
      source: _JsonSource(<String, dynamic>{
        'locations': <Object?>[
          <String, dynamic>{'name': 'Dhaka'},
          <String, dynamic>{'name': 'Chattogram'},
        ],
      }),
    );

    final older = _search(manager, 'Dhaka');
    final newer = _search(manager, 'Chattogram');

    expect(await older, isNull);
    expect((await newer)!['matchCount'], 1);
  });

  test('different search targets do not suppress each other', () async {
    final manager = MiniProgramDataResourceManager();
    await _load(
      manager,
      source: _JsonSource(<String, dynamic>{
        'locations': <Object?>[
          <String, dynamic>{'name': 'Dhaka'},
          <String, dynamic>{'name': 'Chattogram'},
        ],
      }),
    );

    final first = _search(manager, 'Dhaka', targetState: 'location.primary');
    final second = _search(
      manager,
      'Chattogram',
      targetState: 'location.secondary',
    );

    expect((await first)!['matchCount'], 1);
    expect((await second)!['matchCount'], 1);
  });

  test(
    'clear suppresses pending searches and removes loaded resources',
    () async {
      final manager = MiniProgramDataResourceManager();
      await _load(
        manager,
        source: _JsonSource(<String, dynamic>{
          'locations': <Object?>[
            <String, dynamic>{'name': 'Dhaka'},
          ],
        }),
      );

      final pending = _search(manager, 'Dhaka');
      manager.clear();

      expect(await pending, isNull);
      await expectLater(
        _search(manager, 'Dhaka'),
        throwsA(
          isA<MiniProgramDataException>().having(
            (error) => error.code,
            'code',
            MiniProgramErrorCodes.dataResourceNotFound,
          ),
        ),
      );
    },
  );

  test('loaded resources remain isolated by app and version', () async {
    final manager = MiniProgramDataResourceManager();
    await _load(
      manager,
      source: _JsonSource(_locations('Dhaka')),
      appId: 'weather',
      version: '1.0.0',
    );

    expect((await _search(manager, 'Dhaka'))!['matchCount'], 1);
    await expectLater(
      _search(manager, 'Dhaka', version: '2.0.0'),
      throwsA(isA<MiniProgramDataException>()),
    );
    await expectLater(
      _search(manager, 'Dhaka', appId: 'travel'),
      throwsA(isA<MiniProgramDataException>()),
    );
  });

  test('data resource public APIs remain available from the SDK barrel', () {
    expect(miniProgramJsonAssetMaxBytes, 2 * 1024 * 1024);
    expect(miniProgramJsonAssetMaxDepth, 32);
    expect(miniProgramJsonAssetMaxMembers, 50000);
    expect(miniProgramJsonAssetPathMaxLength, 256);
    expect(MiniProgramDataResourceManager(), isNotNull);
    expect(
      const MiniProgramDataException(code: 'code', message: 'message'),
      isNotNull,
    );
  });
}

Future<MiniProgramDataResourceLoadResult> _load(
  MiniProgramDataResourceManager manager, {
  required MiniProgramJsonAssetSource? source,
  MiniProgramCacheManager? cacheManager,
  bool forceRefresh = false,
  String appId = 'weather',
  String version = '1.0.0',
}) {
  return manager.load(
    appId: appId,
    version: version,
    resourceId: 'places',
    assetPath: 'data/places.json',
    ttl: const Duration(days: 30),
    forceRefresh: forceRefresh,
    source: source,
    cacheManager: cacheManager ?? MiniProgramCacheManager.inMemory(),
    cachePolicy: const MiniProgramCachePolicy(),
  );
}

Future<Map<String, dynamic>?> _search(
  MiniProgramDataResourceManager manager,
  String query, {
  int limit = 10,
  String targetState = 'location.results',
  String appId = 'weather',
  String version = '1.0.0',
}) {
  return manager.search(
    appId: appId,
    version: version,
    resourceId: 'places',
    query: query,
    fields: const <String>['name'],
    itemsPath: 'locations',
    minQueryLength: 2,
    limit: limit,
    targetState: targetState,
  );
}

Map<String, dynamic> _locations(String name) => <String, dynamic>{
  'locations': <Object?>[
    <String, dynamic>{'name': name},
  ],
};

class _JsonSource implements MiniProgramJsonAssetSource {
  _JsonSource(this.value);

  final Object? value;
  int calls = 0;

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async {
    calls++;
    return utf8.encode(jsonEncode(value));
  }
}

class _FailingSource implements MiniProgramJsonAssetSource {
  const _FailingSource(this.error);

  final MiniProgramSourceException error;

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async {
    throw error;
  }
}
