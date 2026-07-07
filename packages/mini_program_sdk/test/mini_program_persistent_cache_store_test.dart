import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FileMiniProgramCacheStore', () {
    test('persists data and state entries across store recreation', () async {
      await _withTempDirectory((directory) async {
        final manager = _manager(directory);

        await manager.set(
          appId: 'coupon',
          key: 'products',
          value: const <String, Object?>{'count': 2},
          bucket: MiniProgramCacheBucket.data,
        );
        await manager.set(
          appId: 'coupon',
          key: 'home_tab',
          value: 'deals',
          bucket: MiniProgramCacheBucket.state,
        );

        expect(await _entryFileCount(directory), 2);
        final firstFile = await _firstEntryFile(directory);
        final decoded =
            jsonDecode(await firstFile.readAsString()) as Map<String, Object?>;
        expect(decoded['schemaVersion'], 1);
        expect(p.basename(firstFile.path), isNot(contains('products')));

        final coldManager = _manager(directory);
        expect(
          await coldManager.get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'products',
          ),
          <String, Object?>{'count': 2},
        );
        expect(
          await coldManager.get<String>(
            appId: 'coupon',
            key: 'home_tab',
            bucket: MiniProgramCacheBucket.state,
          ),
          'deals',
        );
      });
    });

    test('does not persist memory session image or video by default', () async {
      await _withTempDirectory((directory) async {
        final manager = _manager(directory);

        await manager.set(appId: 'coupon', key: 'data', value: 'persisted');
        await manager.set(
          appId: 'coupon',
          key: 'memory',
          value: 'process',
          bucket: MiniProgramCacheBucket.memory,
        );
        await manager.set(
          appId: 'coupon',
          key: 'session',
          value: 'process',
          bucket: MiniProgramCacheBucket.session,
        );
        await manager.set(
          appId: 'coupon',
          key: 'image_metadata',
          value: const <String, Object?>{'uri': 'https://example.com/a.png'},
          bucket: MiniProgramCacheBucket.image,
        );
        await manager.set(
          appId: 'coupon',
          key: 'video_metadata',
          value: const <String, Object?>{'uri': 'https://example.com/a.mp4'},
          bucket: MiniProgramCacheBucket.video,
        );

        expect(
          await manager.get<String>(appId: 'coupon', key: 'data'),
          'persisted',
        );
        expect(
          await manager.get<String>(
            appId: 'coupon',
            key: 'memory',
            bucket: MiniProgramCacheBucket.memory,
          ),
          'process',
        );

        final coldManager = _manager(directory);
        expect(
          await coldManager.get<String>(appId: 'coupon', key: 'data'),
          'persisted',
        );
        expect(
          await coldManager.get<String>(
            appId: 'coupon',
            key: 'memory',
            bucket: MiniProgramCacheBucket.memory,
          ),
          isNull,
        );
        expect(
          await coldManager.get<String>(
            appId: 'coupon',
            key: 'session',
            bucket: MiniProgramCacheBucket.session,
          ),
          isNull,
        );
        expect(
          await coldManager.get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'image_metadata',
            bucket: MiniProgramCacheBucket.image,
          ),
          isNull,
        );
        expect(
          await coldManager.get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'video_metadata',
            bucket: MiniProgramCacheBucket.video,
          ),
          isNull,
        );
      });
    });

    test('can persist image metadata when host opts in', () async {
      await _withTempDirectory((directory) async {
        final manager = MiniProgramCacheManager(
          store: FileMiniProgramCacheStore(
            directory: directory,
            persistentBuckets: const <MiniProgramCacheBucket>{
              MiniProgramCacheBucket.data,
              MiniProgramCacheBucket.state,
              MiniProgramCacheBucket.image,
            },
          ),
        );

        await manager.set(
          appId: 'coupon',
          key: 'image_metadata',
          value: const <String, Object?>{'uri': 'https://example.com/a.png'},
          bucket: MiniProgramCacheBucket.image,
        );

        final coldManager = MiniProgramCacheManager(
          store: FileMiniProgramCacheStore(
            directory: directory,
            persistentBuckets: const <MiniProgramCacheBucket>{
              MiniProgramCacheBucket.data,
              MiniProgramCacheBucket.state,
              MiniProgramCacheBucket.image,
            },
          ),
        );
        expect(
          await coldManager.get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'image_metadata',
            bucket: MiniProgramCacheBucket.image,
          ),
          <String, Object?>{'uri': 'https://example.com/a.png'},
        );
        expect(
          await _manager(directory).get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'image_metadata',
            bucket: MiniProgramCacheBucket.image,
          ),
          isNull,
        );
      });
    });

    test('replaces existing files atomically for the same entry', () async {
      await _withTempDirectory((directory) async {
        final manager = _manager(directory);

        await manager.set(appId: 'coupon', key: 'products', value: 'old');
        await manager.set(appId: 'coupon', key: 'products', value: 'new');

        expect(await _entryFileCount(directory), 1);
        expect(
          await _manager(
            directory,
          ).get<String>(appId: 'coupon', key: 'products'),
          'new',
        );
      });
    });

    test('remove clearBucket and clearApp delete persisted files', () async {
      await _withTempDirectory((directory) async {
        final manager = _manager(directory);

        await manager.set(appId: 'coupon', key: 'products', value: 'data');
        await manager.set(
          appId: 'coupon',
          key: 'home_tab',
          value: 'state',
          bucket: MiniProgramCacheBucket.state,
        );
        await manager.set(appId: 'shop', key: 'products', value: 'other');

        await manager.remove(appId: 'coupon', key: 'products');
        expect(
          await _manager(
            directory,
          ).get<String>(appId: 'coupon', key: 'products'),
          isNull,
        );

        await manager.clearBucket(
          appId: 'coupon',
          bucket: MiniProgramCacheBucket.state,
        );
        expect(
          await _manager(directory).get<String>(
            appId: 'coupon',
            key: 'home_tab',
            bucket: MiniProgramCacheBucket.state,
          ),
          isNull,
        );
        expect(
          await _manager(directory).get<String>(appId: 'shop', key: 'products'),
          'other',
        );

        await manager.clearApp('shop');
        expect(await _entryFileCount(directory), 0);
      });
    });

    test('deletes corrupt and unknown-schema entries safely', () async {
      await _withTempDirectory((directory) async {
        await directory.create(recursive: true);
        await File(p.join(directory.path, 'corrupt.json')).writeAsString('{');
        await File(
          p.join(directory.path, 'unknown.json'),
        ).writeAsString(jsonEncode(<String, Object?>{'schemaVersion': 99}));

        final store = FileMiniProgramCacheStore(directory: directory);

        expect(await store.appIds(), isEmpty);
        expect(await _entryFileCount(directory), 0);
      });
    });

    test('deletes expired entries on read', () async {
      await _withTempDirectory((directory) async {
        final clock = _TestClock(DateTime.utc(2026, 6, 1));
        final manager = _manager(directory, clock: clock.now);
        const policy = MiniProgramCachePolicy(dataTtl: Duration(days: 1));

        await manager.set(
          appId: 'coupon',
          key: 'products',
          value: 'expired',
          policy: policy,
        );
        expect(await _entryFileCount(directory), 1);

        clock.advance(const Duration(days: 2));
        final coldManager = _manager(directory, clock: clock.now);

        expect(
          await coldManager.get<String>(
            appId: 'coupon',
            key: 'products',
            policy: policy,
          ),
          isNull,
        );
        expect(await _entryFileCount(directory), 0);
      });
    });

    test(
      'indexed app ids support global totals and cleanup after restart',
      () async {
        await _withTempDirectory((directory) async {
          final manager = _manager(directory);

          await manager.set(
            appId: 'coupon',
            key: 'normal',
            value: 'keep',
            sizeBytes: 10,
          );
          await manager.set(
            appId: 'shop',
            key: 'low',
            value: 'drop',
            sizeBytes: 20,
            priority: MiniProgramCachePriority.low,
          );

          final coldManager = _manager(directory);
          expect(await coldManager.getTotalBytes(), 30);

          await coldManager.clearLowPriority();

          expect(
            await _manager(directory).get<String>(appId: 'shop', key: 'low'),
            isNull,
          );
          expect(
            await _manager(
              directory,
            ).get<String>(appId: 'coupon', key: 'normal'),
            'keep',
          );
        });
      },
    );

    test(
      'clearAllThirdParty preserves host-pinned entries after restart',
      () async {
        await _withTempDirectory((directory) async {
          final manager = _manager(directory);

          await manager.set(
            appId: 'coupon',
            key: 'hostPinned',
            value: 'keep',
            priority: MiniProgramCachePriority.hostPinned,
          );
          await manager.set(appId: 'coupon', key: 'normal', value: 'drop');

          await _manager(directory).clearAllThirdParty();

          expect(
            await _manager(
              directory,
            ).get<String>(appId: 'coupon', key: 'hostPinned'),
            'keep',
          );
          expect(
            await _manager(
              directory,
            ).get<String>(appId: 'coupon', key: 'normal'),
            isNull,
          );
        });
      },
    );

    test('many app ids can persist the same key without conflict', () async {
      await _withTempDirectory((directory) async {
        final manager = _manager(directory);

        for (var index = 0; index < 100; index += 1) {
          await manager.forApp('app_$index').set('shared_key', index);
        }

        final coldManager = _manager(directory);
        for (var index = 0; index < 100; index += 1) {
          expect(
            await coldManager.forApp('app_$index').get<int>('shared_key'),
            index,
          );
        }
      });
    });
  });

  group('SharedPreferencesMiniProgramCacheStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists policy-managed buckets across store recreation', () async {
      const policy = MiniProgramCachePolicy(
        allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
          MiniProgramCacheBucket.memory,
          MiniProgramCacheBucket.data,
          MiniProgramCacheBucket.image,
          MiniProgramCacheBucket.state,
          MiniProgramCacheBucket.video,
        },
      );
      final firstManager = MiniProgramCacheManager(
        store: SharedPreferencesMiniProgramCacheStore(keyPrefix: 'mp_test'),
      );
      await firstManager
          .forApp('coupon', policy: policy)
          .set('products', 'persisted_data');
      await firstManager
          .forApp('coupon', policy: policy)
          .set('home_tab', 'saved_state', bucket: MiniProgramCacheBucket.state);
      await firstManager
          .forApp('coupon', policy: policy)
          .set(
            'hero_image',
            'saved_image',
            bucket: MiniProgramCacheBucket.image,
          );
      await firstManager
          .forApp('coupon', policy: policy)
          .set(
            'intro_video',
            'saved_video',
            bucket: MiniProgramCacheBucket.video,
          );
      await firstManager
          .forApp('coupon', policy: policy)
          .set('scratch', 'memory_only', bucket: MiniProgramCacheBucket.memory);

      final coldManager = MiniProgramCacheManager(
        store: SharedPreferencesMiniProgramCacheStore(keyPrefix: 'mp_test'),
      );

      expect(
        await coldManager
            .forApp('coupon', policy: policy)
            .get<String>('products'),
        'persisted_data',
      );
      expect(
        await coldManager
            .forApp('coupon', policy: policy)
            .get<String>('home_tab', bucket: MiniProgramCacheBucket.state),
        'saved_state',
      );
      expect(
        await coldManager
            .forApp('coupon', policy: policy)
            .get<String>('hero_image', bucket: MiniProgramCacheBucket.image),
        'saved_image',
      );
      expect(
        await coldManager
            .forApp('coupon', policy: policy)
            .get<String>('intro_video', bucket: MiniProgramCacheBucket.video),
        'saved_video',
      );
      expect(
        await coldManager
            .forApp('coupon', policy: policy)
            .get<String>('scratch', bucket: MiniProgramCacheBucket.memory),
        isNull,
      );
    });

    test('removes entries by app and bucket', () async {
      final manager = MiniProgramCacheManager(
        store: SharedPreferencesMiniProgramCacheStore(keyPrefix: 'mp_test'),
      );
      await manager.forApp('coupon').set('products', 'coupon');
      await manager
          .forApp('coupon')
          .set('home_tab', 'state', bucket: MiniProgramCacheBucket.state);
      await manager.forApp('shop').set('products', 'shop');

      await manager.clearBucket(
        appId: 'coupon',
        bucket: MiniProgramCacheBucket.data,
      );

      final coldAfterBucketClear = MiniProgramCacheManager(
        store: SharedPreferencesMiniProgramCacheStore(keyPrefix: 'mp_test'),
      );
      expect(
        await coldAfterBucketClear.forApp('coupon').get<String>('products'),
        isNull,
      );
      expect(
        await coldAfterBucketClear
            .forApp('coupon')
            .get<String>('home_tab', bucket: MiniProgramCacheBucket.state),
        'state',
      );
      expect(
        await coldAfterBucketClear.forApp('shop').get<String>('products'),
        'shop',
      );

      await coldAfterBucketClear.clearApp('coupon');
      final coldAfterAppClear = MiniProgramCacheManager(
        store: SharedPreferencesMiniProgramCacheStore(keyPrefix: 'mp_test'),
      );
      expect(
        await coldAfterAppClear
            .forApp('coupon')
            .get<String>('home_tab', bucket: MiniProgramCacheBucket.state),
        isNull,
      );
      expect(
        await coldAfterAppClear.forApp('shop').get<String>('products'),
        'shop',
      );
    });
  });

  group('MiniProgramCacheBundle', () {
    test(
      'fileBacked persists runtime data cache across bundle recreation',
      () async {
        await _withTempDirectory((directory) async {
          final firstBundle = MiniProgramCacheBundle.fileBacked(
            rootDirectory: directory,
          );
          await firstBundle.runtimeCache.set(
            appId: 'coupon',
            key: 'products',
            value: const <String, Object?>{'count': 2},
          );

          final coldBundle = MiniProgramCacheBundle.fileBacked(
            rootDirectory: directory,
          );
          expect(
            await coldBundle.runtimeCache.get<Map<String, Object?>>(
              appId: 'coupon',
              key: 'products',
            ),
            <String, Object?>{'count': 2},
          );
        });
      },
    );

    test(
      'webPersistent persists runtime data cache across bundle recreation',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final firstBundle = MiniProgramCacheBundle.webPersistent(
          runtimeCacheKeyPrefix: 'bundle_test',
        );
        await firstBundle.runtimeCache.set(
          appId: 'coupon',
          key: 'products',
          value: const <String, Object?>{'count': 2},
        );

        final coldBundle = MiniProgramCacheBundle.webPersistent(
          runtimeCacheKeyPrefix: 'bundle_test',
        );
        expect(
          await coldBundle.runtimeCache.get<Map<String, Object?>>(
            appId: 'coupon',
            key: 'products',
          ),
          <String, Object?>{'count': 2},
        );
      },
    );
  });
}

MiniProgramCacheManager _manager(
  Directory directory, {
  MiniProgramCacheClock? clock,
}) {
  return MiniProgramCacheManager(
    store: FileMiniProgramCacheStore(directory: directory, clock: clock),
    clock: clock,
  );
}

Future<void> _withTempDirectory(
  Future<void> Function(Directory directory) run,
) async {
  final directory = await Directory.systemTemp.createTemp(
    'mini_program_runtime_cache_test_',
  );
  try {
    await run(directory);
  } finally {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

Future<int> _entryFileCount(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }
  var count = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File && p.extension(entity.path) == '.json') {
      count += 1;
    }
  }
  return count;
}

Future<File> _firstEntryFile(Directory directory) async {
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File && p.extension(entity.path) == '.json') {
      return entity;
    }
  }
  throw StateError('No entry files found.');
}

class _TestClock {
  _TestClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
