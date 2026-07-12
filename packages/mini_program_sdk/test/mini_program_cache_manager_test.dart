import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgramCacheManager', () {
    test('policy defaults are host-safe and namespaced keys are scoped', () {
      const policy = MiniProgramCachePolicy();

      expect(policy.enabled, isTrue);
      expect(policy.dataTtl, const Duration(days: 30));
      expect(policy.imageTtl, const Duration(days: 14));
      expect(policy.videoTtl, const Duration(hours: 6));
      expect(policy.sessionInactiveTtl, const Duration(days: 60));
      expect(policy.maxBytes, 20 * 1024 * 1024);
      expect(policy.maxStateBytes, 5 * 1024 * 1024);
      expect(
        policy.allowedMiniProgramCacheBuckets,
        containsAll(<MiniProgramCacheBucket>[
          MiniProgramCacheBucket.memory,
          MiniProgramCacheBucket.data,
          MiniProgramCacheBucket.image,
          MiniProgramCacheBucket.state,
        ]),
      );
      expect(
        policy.allowedMiniProgramCacheBuckets,
        isNot(contains(MiniProgramCacheBucket.session)),
      );
      expect(
        MiniProgramCacheManager.namespacedKey(
          appId: 'coupon',
          bucket: MiniProgramCacheBucket.data,
          key: 'products_page_1',
        ),
        'mp_cache/coupon/data/products_page_1',
      );
      expect(
        () => MiniProgramCacheManager.namespacedKey(
          appId: 'coupon',
          bucket: MiniProgramCacheBucket.data,
          key: '../products',
        ),
        throwsArgumentError,
      );
    });

    test('set, get, has, remove, and clear values by app and bucket', () async {
      final manager = MiniProgramCacheManager.inMemory();
      final cache = manager.forApp('coupon');

      await cache.set('products', const <String, Object?>{'count': 2});

      expect(await cache.has('products'), isTrue);
      expect(
        await cache.get<Map<String, Object?>>('products'),
        <String, Object?>{'count': 2},
      );

      await cache.remove('products');
      expect(await cache.has('products'), isFalse);

      await cache.set('one', 1);
      await cache.set('two', 2, bucket: MiniProgramCacheBucket.image);
      await cache.clear(bucket: MiniProgramCacheBucket.data);
      expect(await cache.has('one'), isFalse);
      expect(
        await cache.has('two', bucket: MiniProgramCacheBucket.image),
        isTrue,
      );

      await cache.clear();
      expect(
        await cache.has('two', bucket: MiniProgramCacheBucket.image),
        isFalse,
      );
    });

    test('TTL expiry removes entries and requested TTL is clamped', () async {
      final clock = _TestClock(DateTime.utc(2026, 6, 1));
      final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(dataTtl: Duration(days: 30));

      await manager.set(
        appId: 'coupon',
        key: 'products',
        value: 'live',
        ttl: const Duration(days: 60),
        policy: policy,
      );

      final entry = (await manager.store.entries('coupon')).single;
      expect(entry.expiresAt, DateTime.utc(2026, 7, 1));

      clock.advance(const Duration(days: 31));

      expect(
        await manager.get<String>(
          appId: 'coupon',
          key: 'products',
          policy: policy,
        ),
        isNull,
      );
      expect(await manager.store.entries('coupon'), isEmpty);
    });

    test('metadata tracks opened time and bucket byte totals', () async {
      final clock = _TestClock(DateTime.utc(2026, 6, 1, 8));
      final manager = MiniProgramCacheManager.inMemory(clock: clock.now);

      await manager.openApp('coupon');
      await manager.set(
        appId: 'coupon',
        key: 'data',
        value: 'abc',
        bucket: MiniProgramCacheBucket.data,
        sizeBytes: 10,
      );
      await manager.set(
        appId: 'coupon',
        key: 'image',
        value: null,
        bucket: MiniProgramCacheBucket.image,
        sizeBytes: 20,
      );

      final metadata = manager.getMetadata('coupon')!;
      expect(metadata.firstOpenedAt, DateTime.utc(2026, 6, 1, 8));
      expect(metadata.lastOpenedAt, DateTime.utc(2026, 6, 1, 8));
      expect(metadata.totalBytes, 30);
      expect(metadata.dataBytes, 10);
      expect(metadata.imageBytes, 20);
      expect(await manager.getTotalBytes(appId: 'coupon'), 30);
    });

    test('memory cache clears on app close when policy enables it', () async {
      final manager = MiniProgramCacheManager.inMemory();
      const policy = MiniProgramCachePolicy(clearMemoryOnExit: true);

      await manager.openApp('coupon', policy: policy);
      await manager
          .forApp('coupon', policy: policy)
          .set('runtime_value', true, bucket: MiniProgramCacheBucket.memory);

      expect(
        await manager.has(
          appId: 'coupon',
          key: 'runtime_value',
          bucket: MiniProgramCacheBucket.memory,
          policy: policy,
        ),
        isTrue,
      );

      await manager.closeApp('coupon', policy: policy);

      expect(
        await manager.has(
          appId: 'coupon',
          key: 'runtime_value',
          bucket: MiniProgramCacheBucket.memory,
          policy: policy,
        ),
        isFalse,
      );
    });

    test(
      'inactive session and state cleanup use last opened metadata',
      () async {
        final clock = _TestClock(DateTime.utc(2026, 1, 1));
        final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
        const policy = MiniProgramCachePolicy(
          sessionInactiveTtl: Duration(days: 60),
          stateInactiveTtl: Duration(days: 60),
        );

        await manager.openApp('coupon', policy: policy);
        await manager.set(
          appId: 'coupon',
          key: 'login_state',
          value: 'session',
          bucket: MiniProgramCacheBucket.session,
          policy: policy,
        );
        await manager.set(
          appId: 'coupon',
          key: 'home_tab',
          value: 'saved',
          bucket: MiniProgramCacheBucket.state,
          policy: policy,
        );

        clock.advance(const Duration(days: 61));
        await manager.clearInactiveSessions(policy: policy);
        await manager.clearInactiveState(policy: policy);

        expect(
          await manager.has(
            appId: 'coupon',
            key: 'login_state',
            bucket: MiniProgramCacheBucket.session,
            policy: policy,
          ),
          isFalse,
        );
        expect(
          await manager.has(
            appId: 'coupon',
            key: 'home_tab',
            bucket: MiniProgramCacheBucket.state,
            policy: policy,
          ),
          isFalse,
        );
      },
    );

    test('video bucket removes oldest entries over its bucket limit', () async {
      final clock = _TestClock(DateTime.utc(2026, 6, 1));
      final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(maxVideoBytes: 50);

      await manager.set(
        appId: 'coupon',
        key: 'video_1',
        value: null,
        bucket: MiniProgramCacheBucket.video,
        sizeBytes: 30,
        policy: policy,
      );
      clock.advance(const Duration(minutes: 1));
      await manager.set(
        appId: 'coupon',
        key: 'video_2',
        value: null,
        bucket: MiniProgramCacheBucket.video,
        sizeBytes: 30,
        policy: policy,
      );

      expect(
        await manager.has(
          appId: 'coupon',
          key: 'video_1',
          bucket: MiniProgramCacheBucket.video,
          policy: policy,
        ),
        isFalse,
      );
      expect(
        await manager.has(
          appId: 'coupon',
          key: 'video_2',
          bucket: MiniProgramCacheBucket.video,
          policy: policy,
        ),
        isTrue,
      );
    });

    test('state bucket removes oldest entries over its bucket limit', () async {
      final clock = _TestClock(DateTime.utc(2026, 6, 1));
      final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(maxStateBytes: 50);

      await manager.set(
        appId: 'calculator',
        key: 'history_1',
        value: 'older',
        bucket: MiniProgramCacheBucket.state,
        sizeBytes: 30,
        policy: policy,
      );
      clock.advance(const Duration(minutes: 1));
      await manager.set(
        appId: 'calculator',
        key: 'history_2',
        value: 'newer',
        bucket: MiniProgramCacheBucket.state,
        sizeBytes: 30,
        policy: policy,
      );

      expect(
        await manager.has(
          appId: 'calculator',
          key: 'history_1',
          bucket: MiniProgramCacheBucket.state,
          policy: policy,
        ),
        isFalse,
      );
      expect(
        await manager.has(
          appId: 'calculator',
          key: 'history_2',
          bucket: MiniProgramCacheBucket.state,
          policy: policy,
        ),
        isTrue,
      );
    });

    test(
      'quota cleanup removes low priority and preserves host-pinned entries',
      () async {
        final manager = MiniProgramCacheManager.inMemory();
        const policy = MiniProgramCachePolicy(maxBytes: 20);

        await manager.set(
          appId: 'coupon',
          key: 'hostPinned',
          value: 'keep',
          sizeBytes: 8,
          priority: MiniProgramCachePriority.hostPinned,
          policy: policy,
        );
        await manager.set(
          appId: 'coupon',
          key: 'normal',
          value: 'keep',
          sizeBytes: 8,
          priority: MiniProgramCachePriority.normal,
          policy: policy,
        );
        await manager.set(
          appId: 'coupon',
          key: 'low',
          value: 'drop',
          sizeBytes: 8,
          priority: MiniProgramCachePriority.low,
          policy: policy,
        );

        expect(
          await manager.has(appId: 'coupon', key: 'low', policy: policy),
          isFalse,
        );
        expect(
          await manager.has(appId: 'coupon', key: 'normal', policy: policy),
          isTrue,
        );
        expect(
          await manager.has(appId: 'coupon', key: 'hostPinned', policy: policy),
          isTrue,
        );

        await manager.clearAllThirdParty();

        expect(
          await manager.has(appId: 'coupon', key: 'normal', policy: policy),
          isFalse,
        );
        expect(
          await manager.has(appId: 'coupon', key: 'hostPinned', policy: policy),
          isTrue,
        );
      },
    );

    test(
      'clearOnLogout removes only the session bucket when enabled',
      () async {
        final manager = MiniProgramCacheManager.inMemory();
        const policy = MiniProgramCachePolicy(clearSessionOnLogout: true);

        await manager.set(
          appId: 'coupon',
          key: 'login_state',
          value: true,
          bucket: MiniProgramCacheBucket.session,
          policy: policy,
        );
        await manager.set(
          appId: 'coupon',
          key: 'products',
          value: true,
          bucket: MiniProgramCacheBucket.data,
          policy: policy,
        );

        await manager.clearOnLogout('coupon', policy: policy);

        expect(
          await manager.has(
            appId: 'coupon',
            key: 'login_state',
            bucket: MiniProgramCacheBucket.session,
            policy: policy,
          ),
          isFalse,
        );
        expect(
          await manager.has(
            appId: 'coupon',
            key: 'products',
            bucket: MiniProgramCacheBucket.data,
            policy: policy,
          ),
          isTrue,
        );
      },
    );

    test(
      'app-scoped cache cannot write session or host-pinned cache',
      () async {
        final cache = MiniProgramCacheManager.inMemory().forApp('coupon');

        expect(
          () => cache.set(
            'login_state',
            true,
            bucket: MiniProgramCacheBucket.session,
          ),
          throwsArgumentError,
        );
        expect(
          () => cache.set(
            'products',
            true,
            priority: MiniProgramCachePriority.hostPinned,
          ),
          throwsArgumentError,
        );
      },
    );

    test('app-scoped cache rejects host-disabled buckets', () async {
      final cache = MiniProgramCacheManager.inMemory().forApp(
        'calculator',
        policy: const MiniProgramCachePolicy(
          allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
            MiniProgramCacheBucket.data,
          },
        ),
      );

      expect(
        () => cache.set(
          'history',
          '1 + 1 = 2',
          bucket: MiniProgramCacheBucket.state,
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            cache.get<String>('history', bucket: MiniProgramCacheBucket.state),
        throwsArgumentError,
      );
    });

    test('reports policy-aware app usage without host-private data', () async {
      final clock = _TestClock(DateTime.utc(2026, 7, 1));
      final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(
        maxBytes: 100,
        maxDataBytes: 40,
        maxStateBytes: 30,
        dataTtl: Duration(days: 7),
        stateInactiveTtl: Duration(days: 30),
        allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
          MiniProgramCacheBucket.data,
          MiniProgramCacheBucket.state,
        },
      );
      await manager.set(
        appId: 'calculator',
        key: 'data',
        value: 1,
        sizeBytes: 10,
        policy: policy,
      );
      await manager.set(
        appId: 'calculator',
        key: 'history',
        value: const <int>[1, 2],
        bucket: MiniProgramCacheBucket.state,
        sizeBytes: 6,
        policy: policy,
      );
      await manager.set(
        appId: 'calculator',
        key: 'session',
        value: 'private',
        bucket: MiniProgramCacheBucket.session,
        sizeBytes: 9,
        policy: policy,
      );
      await manager.set(
        appId: 'calculator',
        key: 'pinned',
        value: true,
        priority: MiniProgramCachePriority.hostPinned,
        sizeBytes: 12,
        policy: policy,
      );

      final hostUsage = await manager.usageForApp('calculator', policy: policy);
      expect(hostUsage.usedBytes, 37);

      final json = hostUsage.toMiniProgramJson();
      expect(json['usedBytes'], 16);
      expect(json['entryCount'], 2);
      expect(json['buckets'], isNot(contains('session')));
      final buckets = json['buckets']! as Map<String, dynamic>;
      expect(buckets['data'], <String, dynamic>{
        'enabled': true,
        'usedBytes': 10,
        'maxBytes': 40,
        'remainingBytes': 30,
        'ttlMs': const Duration(days: 7).inMilliseconds,
        'entryCount': 1,
      });
      expect(buckets['state'], <String, dynamic>{
        'enabled': true,
        'usedBytes': 6,
        'maxBytes': 30,
        'remainingBytes': 24,
        'ttlMs': const Duration(days: 30).inMilliseconds,
        'entryCount': 1,
      });
      expect((buckets['image'] as Map<String, dynamic>)['enabled'], isFalse);
      expect((buckets['image'] as Map<String, dynamic>)['usedBytes'], 0);
    });

    test(
      '100 mini-program appIds can store the same key without conflict',
      () async {
        final manager = MiniProgramCacheManager.inMemory();

        for (var index = 0; index < 100; index += 1) {
          await manager.forApp('app_$index').set('shared_key', index);
        }

        for (var index = 0; index < 100; index += 1) {
          expect(
            await manager.forApp('app_$index').get<int>('shared_key'),
            index,
          );
        }

        await manager.clearApp('app_42');
        expect(await manager.forApp('app_42').has('shared_key'), isFalse);
        expect(await manager.forApp('app_41').has('shared_key'), isTrue);
      },
    );
  });
}

class _TestClock {
  _TestClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
