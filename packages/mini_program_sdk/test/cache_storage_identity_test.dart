import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('delivery file caches preserve encoded names and JSON shapes', () async {
    await _withTempDirectory((root) async {
      final manifestDirectory = Directory(p.join(root.path, 'manifests'));
      final screenDirectory = Directory(p.join(root.path, 'screens'));
      final assetDirectory = Directory(p.join(root.path, 'assets'));
      final cachedAt = DateTime.utc(2026, 7, 16, 12, 30);

      await FileManifestCache(directory: manifestDirectory).write(
        CachedManifestEntry(
          miniProgramId: 'weather',
          manifest: _manifest,
          cachedAt: cachedAt,
        ),
      );
      await FileScreenCache(directory: screenDirectory).write(
        CachedScreenEntry(
          miniProgramId: 'weather',
          version: '1.0.0',
          screenId: 'weather/home',
          screenJson: const <String, dynamic>{'type': 'text', 'data': 'Sunny'},
          cachedAt: cachedAt,
        ),
      );
      await FileAssetCache(directory: assetDirectory).write(
        sourceUri: 'https://cdn.example.com/weather/icon',
        bytes: const <int>[1, 2, 3],
        cachedAt: cachedAt,
        contentType: 'image/png',
      );

      final manifestFile = File(
        p.join(manifestDirectory.path, '${_encoded('weather')}.json'),
      );
      final screenKey = buildScreenCacheKey(
        miniProgramId: 'weather',
        version: '1.0.0',
        screenId: 'weather/home',
      );
      final screenFile = File(
        p.join(screenDirectory.path, '${_encoded(screenKey)}.json'),
      );
      final assetKey = _encoded('https://cdn.example.com/weather/icon');
      final metadataFile = File(
        p.join(assetDirectory.path, '$assetKey.asset.json'),
      );
      final assetFile = File(p.join(assetDirectory.path, '$assetKey.png'));

      expect(await manifestFile.exists(), isTrue);
      expect(await screenFile.exists(), isTrue);
      expect(await metadataFile.exists(), isTrue);
      expect(await assetFile.readAsBytes(), const <int>[1, 2, 3]);

      final manifestJson =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final screenJson =
          jsonDecode(await screenFile.readAsString()) as Map<String, dynamic>;
      final assetJson =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;

      expect(manifestJson.keys, <String>[
        'miniProgramId',
        'manifest',
        'cachedAt',
      ]);
      expect(screenJson.keys, <String>[
        'miniProgramId',
        'version',
        'screenId',
        'screenJson',
        'cachedAt',
      ]);
      expect(assetJson.keys, <String>[
        'sourceUri',
        'filePath',
        'cachedAt',
        'contentType',
      ]);
      expect(manifestJson['cachedAt'], '2026-07-16T12:30:00.000Z');
      expect(screenJson['cachedAt'], '2026-07-16T12:30:00.000Z');
      expect(assetJson['contentType'], 'image/png');
    });
  });

  test(
    'file and preferences stores preserve the same schema-v1 entry',
    () async {
      await _withTempDirectory((directory) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final clock = _FixedClock(DateTime.utc(2026, 7, 16, 10));
        const policy = MiniProgramCachePolicy(dataTtl: Duration(days: 2));
        final fileManager = MiniProgramCacheManager(
          store: FileMiniProgramCacheStore(
            directory: directory,
            clock: clock.now,
          ),
          clock: clock.now,
        );
        final preferencesManager = MiniProgramCacheManager(
          store: SharedPreferencesMiniProgramCacheStore(
            keyPrefix: 'phase8',
            clock: clock.now,
          ),
          clock: clock.now,
        );

        for (final manager in <MiniProgramCacheManager>[
          fileManager,
          preferencesManager,
        ]) {
          await manager.set(
            appId: 'weather',
            key: 'forecast',
            value: const <String, Object?>{'temperature': 31},
            sizeBytes: 64,
            policy: policy,
          );
        }

        final namespacedKey = MiniProgramCacheManager.namespacedKey(
          appId: 'weather',
          bucket: MiniProgramCacheBucket.data,
          key: 'forecast',
        );
        final file = File(
          p.join(directory.path, '${_encoded(namespacedKey)}.json'),
        );
        final fileJson =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final preferences = await SharedPreferences.getInstance();
        final preferencesKey = 'phase8/${_encoded(namespacedKey)}';
        final preferencesJson =
            jsonDecode(preferences.getString(preferencesKey)!)
                as Map<String, dynamic>;

        expect(fileJson, preferencesJson);
        expect(fileJson.keys, <String>[
          'schemaVersion',
          'appId',
          'bucket',
          'key',
          'value',
          'createdAt',
          'updatedAt',
          'lastAccessedAt',
          'expiresAt',
          'sizeBytes',
          'priority',
        ]);
        expect(fileJson['schemaVersion'], 1);
        expect(fileJson['appId'], 'weather');
        expect(fileJson['bucket'], 'data');
        expect(fileJson['key'], 'forecast');
        expect(fileJson['createdAt'], '2026-07-16T10:00:00.000Z');
        expect(fileJson['expiresAt'], '2026-07-18T10:00:00.000Z');
      });
    },
  );

  test('stores load pre-refactor schema-v1 persisted entries', () async {
    await _withTempDirectory((directory) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final namespacedKey = MiniProgramCacheManager.namespacedKey(
        appId: 'legacy',
        bucket: MiniProgramCacheBucket.state,
        key: 'selected_tab',
      );
      final persisted = <String, Object?>{
        'schemaVersion': 1,
        'appId': 'legacy',
        'bucket': 'state',
        'key': 'selected_tab',
        'value': 'history',
        'createdAt': '2026-07-16T10:00:00.000Z',
        'updatedAt': '2026-07-16T10:00:00.000Z',
        'lastAccessedAt': '2026-07-16T10:00:00.000Z',
        'expiresAt': '2026-08-16T10:00:00.000Z',
        'sizeBytes': 7,
        'priority': 'normal',
      };
      await directory.create(recursive: true);
      await File(
        p.join(directory.path, '${_encoded(namespacedKey)}.json'),
      ).writeAsString(jsonEncode(persisted));
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'legacy_cache/${_encoded(namespacedKey)}',
        jsonEncode(persisted),
      );
      final clock = _FixedClock(DateTime.utc(2026, 7, 16, 12));

      for (final store in <MiniProgramCacheStore>[
        FileMiniProgramCacheStore(directory: directory, clock: clock.now),
        SharedPreferencesMiniProgramCacheStore(
          keyPrefix: 'legacy_cache',
          clock: clock.now,
        ),
      ]) {
        final manager = MiniProgramCacheManager(store: store, clock: clock.now);
        expect(
          await manager.get<String>(
            appId: 'legacy',
            key: 'selected_tab',
            bucket: MiniProgramCacheBucket.state,
          ),
          'history',
        );
      }
    });
  });

  test('delivery file stores remove malformed cached data', () async {
    await _withTempDirectory((root) async {
      final manifestDirectory = Directory(p.join(root.path, 'manifests'));
      final screenDirectory = Directory(p.join(root.path, 'screens'));
      final assetDirectory = Directory(p.join(root.path, 'assets'));
      await manifestDirectory.create(recursive: true);
      await screenDirectory.create(recursive: true);
      await assetDirectory.create(recursive: true);

      final manifestFile = File(
        p.join(manifestDirectory.path, '${_encoded('weather')}.json'),
      );
      final screenKey = buildScreenCacheKey(
        miniProgramId: 'weather',
        version: '1.0.0',
        screenId: 'weather/home',
      );
      final screenFile = File(
        p.join(screenDirectory.path, '${_encoded(screenKey)}.json'),
      );
      const sourceUri = 'https://cdn.example.com/weather.png';
      final assetPrefix = _encoded(sourceUri);
      final metadataFile = File(
        p.join(assetDirectory.path, '$assetPrefix.asset.json'),
      );
      final assetFile = File(p.join(assetDirectory.path, '$assetPrefix.png'));
      await manifestFile.writeAsString('{');
      await screenFile.writeAsString('[]');
      await metadataFile.writeAsString('{');
      await assetFile.writeAsBytes(const <int>[1]);

      expect(
        await FileManifestCache(directory: manifestDirectory).read('weather'),
        isNull,
      );
      expect(
        await FileScreenCache(directory: screenDirectory).read(
          miniProgramId: 'weather',
          version: '1.0.0',
          screenId: 'weather/home',
        ),
        isNull,
      );
      expect(
        await FileAssetCache(directory: assetDirectory).read(sourceUri),
        isNull,
      );
      expect(await manifestFile.exists(), isFalse);
      expect(await screenFile.exists(), isFalse);
      expect(await metadataFile.exists(), isFalse);
      expect(await assetFile.exists(), isFalse);
    });
  });

  test('cache bundle factories retain their storage composition', () async {
    final inMemory = MiniProgramCacheBundle.inMemory();
    expect(inMemory.manifestCache, isA<InMemoryManifestCache>());
    expect(inMemory.screenCache, isA<InMemoryScreenCache>());
    expect(inMemory.assetCache, same(NoOpAssetCache.shared));
    expect(inMemory.runtimeCache.store, isA<MiniProgramMemoryCacheStore>());

    await _withTempDirectory((directory) async {
      final fileBacked = MiniProgramCacheBundle.fileBacked(
        rootDirectory: directory,
      );
      expect(fileBacked.manifestCache, isA<FileManifestCache>());
      expect(fileBacked.screenCache, isA<FileScreenCache>());
      expect(fileBacked.assetCache, isA<FileAssetCache>());
      expect(fileBacked.runtimeCache.store, isA<FileMiniProgramCacheStore>());
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final webPersistent = MiniProgramCacheBundle.webPersistent();
    expect(webPersistent.manifestCache, isA<InMemoryManifestCache>());
    expect(webPersistent.screenCache, isA<InMemoryScreenCache>());
    expect(webPersistent.assetCache, same(NoOpAssetCache.shared));
    expect(
      webPersistent.runtimeCache.store,
      isA<SharedPreferencesMiniProgramCacheStore>(),
    );
  });

  test('cache APIs remain available from the SDK public barrel', () {
    expect(CachedManifestEntry, isNotNull);
    expect(CachedScreenEntry, isNotNull);
    expect(CachedAssetEntry, isNotNull);
    expect(ManifestCache, isNotNull);
    expect(ScreenCache, isNotNull);
    expect(AssetCache, isNotNull);
    expect(FileManifestCache, isNotNull);
    expect(FileScreenCache, isNotNull);
    expect(FileAssetCache, isNotNull);
    expect(FileMiniProgramCacheStore, isNotNull);
    expect(SharedPreferencesMiniProgramCacheStore, isNotNull);
    expect(
      buildScreenCacheKey(miniProgramId: 'app', version: '1', screenId: 'home'),
      'app::1::home',
    );
  });
}

const MiniProgramManifest _manifest = MiniProgramManifest(
  id: 'weather',
  version: '1.0.0',
  entry: 'weather/home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
  requiredCapabilities: <CapabilityId>[],
);

String _encoded(String value) => base64Url.encode(utf8.encode(value));

Future<void> _withTempDirectory(
  Future<void> Function(Directory directory) run,
) async {
  final directory = await Directory.systemTemp.createTemp(
    'mini_program_phase8_cache_test_',
  );
  try {
    await run(directory);
  } finally {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class _FixedClock {
  const _FixedClock(this.value);

  final DateTime value;

  DateTime now() => value;
}
