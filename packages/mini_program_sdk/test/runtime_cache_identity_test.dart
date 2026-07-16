import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test(
    'lifecycle cleanup continues through overrideable manager methods',
    () async {
      final manager = _OverrideTrackingCacheManager();
      const policy = MiniProgramCachePolicy(
        clearExpiredOnStartup: true,
        clearStateOnInactiveExpiry: true,
        clearWhenOverLimit: false,
        clearMemoryOnExit: true,
        clearSessionOnLogout: true,
      );

      await manager.openApp('override_app', policy: policy);
      await manager.closeApp('override_app', policy: policy);
      await manager.clearOnLogout('override_app', policy: policy);

      expect(manager.calls, <String>[
        'clearExpired:override_app',
        'clearInactiveSessions',
        'clearInactiveState',
        'clearBucket:override_app:memory',
        'clearBucket:override_app:session',
      ]);
    },
  );

  test('total-limit cleanup preserves bucket and access ordering', () async {
    final clock = _CacheTestClock(DateTime.utc(2026, 7, 16, 10));
    final manager = MiniProgramCacheManager.inMemory(clock: clock.now);
    const policy = MiniProgramCachePolicy(
      maxBytes: 25,
      maxDataBytes: 100,
      maxImageBytes: 100,
      maxVideoBytes: 100,
      clearWhenOverLimit: true,
    );

    await manager.set(
      appId: 'cleanup',
      key: 'data',
      value: 'data',
      bucket: MiniProgramCacheBucket.data,
      sizeBytes: 10,
      policy: policy,
    );
    clock.advance(const Duration(minutes: 1));
    await manager.set(
      appId: 'cleanup',
      key: 'image',
      value: 'image',
      bucket: MiniProgramCacheBucket.image,
      sizeBytes: 10,
      policy: policy,
    );
    clock.advance(const Duration(minutes: 1));
    await manager.set(
      appId: 'cleanup',
      key: 'video',
      value: 'video',
      bucket: MiniProgramCacheBucket.video,
      sizeBytes: 10,
      policy: policy,
    );

    expect(
      await manager.has(
        appId: 'cleanup',
        key: 'video',
        bucket: MiniProgramCacheBucket.video,
        policy: policy,
      ),
      isFalse,
    );
    expect(
      await manager.has(
        appId: 'cleanup',
        key: 'image',
        bucket: MiniProgramCacheBucket.image,
        policy: policy,
      ),
      isTrue,
    );
    expect(
      await manager.has(
        appId: 'cleanup',
        key: 'data',
        bucket: MiniProgramCacheBucket.data,
        policy: policy,
      ),
      isTrue,
    );
  });

  test('cache distinguishes a stored null from a missing entry', () async {
    final manager = MiniProgramCacheManager.inMemory();

    await manager.set(appId: 'nullable', key: 'value', value: null);

    expect(await manager.has(appId: 'nullable', key: 'value'), isTrue);
    expect(await manager.get<Object?>(appId: 'nullable', key: 'value'), isNull);
    expect(await manager.has(appId: 'nullable', key: 'missing'), isFalse);
  });

  test('usage JSON hides session and host-pinned cache data', () async {
    final manager = MiniProgramCacheManager.inMemory();
    const policy = MiniProgramCachePolicy(
      maxBytes: 1000,
      maxDataBytes: 500,
      maxSessionBytes: 200,
    );

    await manager.set(
      appId: 'usage',
      key: 'visible',
      value: 'value',
      sizeBytes: 20,
      policy: policy,
    );
    await manager.set(
      appId: 'usage',
      key: 'pinned',
      value: 'host',
      sizeBytes: 30,
      priority: MiniProgramCachePriority.hostPinned,
      policy: policy,
    );
    await manager.set(
      appId: 'usage',
      key: 'session',
      value: 'private',
      bucket: MiniProgramCacheBucket.session,
      sizeBytes: 40,
      policy: policy,
    );

    final usage = await manager.usageForApp('usage', policy: policy);
    final json = usage.toMiniProgramJson();

    expect(json['usedBytes'], 20);
    expect(json['entryCount'], 1);
    expect((json['buckets'] as Map<String, dynamic>).keys, <String>[
      'memory',
      'data',
      'image',
      'state',
      'video',
    ]);
    expect(json.toString(), isNot(contains('session')));
    expect((json['buckets'] as Map<String, dynamic>)['data'], <String, dynamic>{
      'enabled': true,
      'usedBytes': 20,
      'maxBytes': 500,
      'remainingBytes': 480,
      'ttlMs': const Duration(days: 30).inMilliseconds,
      'entryCount': 1,
    });
  });

  test('runtime cache APIs remain available from the SDK barrel', () {
    final store = MiniProgramMemoryCacheStore();
    final manager = MiniProgramCacheManager(store: store);
    final cache = manager.forApp('public_api');

    expect(store, isA<MiniProgramIndexedCacheStore>());
    expect(manager.store, same(store));
    expect(cache.appId, 'public_api');
    expect(const MiniProgramCachePolicy(), isA<MiniProgramCachePolicy>());
    expect(MiniProgramCacheBucket.values, hasLength(6));
    expect(MiniProgramCacheStorage.values, hasLength(5));
    expect(MiniProgramCachePriority.values, hasLength(4));
  });
}

class _OverrideTrackingCacheManager extends MiniProgramCacheManager {
  _OverrideTrackingCacheManager() : super(store: MiniProgramMemoryCacheStore());

  final List<String> calls = <String>[];

  @override
  Future<void> clearExpired({
    String? appId,
    MiniProgramCachePolicy? policy,
  }) async {
    calls.add('clearExpired:$appId');
  }

  @override
  Future<void> clearInactiveSessions({MiniProgramCachePolicy? policy}) async {
    calls.add('clearInactiveSessions');
  }

  @override
  Future<void> clearInactiveState({MiniProgramCachePolicy? policy}) async {
    calls.add('clearInactiveState');
  }

  @override
  Future<void> clearBucket({
    required String appId,
    required MiniProgramCacheBucket bucket,
    MiniProgramCachePolicy? policy,
  }) async {
    calls.add('clearBucket:$appId:${bucket.name}');
  }
}

class _CacheTestClock {
  _CacheTestClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
