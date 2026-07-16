part of '../../mp_screen_renderer.dart';

const List<MiniProgramCacheBucket> _miniProgramCacheActionBuckets =
    <MiniProgramCacheBucket>[
      MiniProgramCacheBucket.memory,
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.image,
      MiniProgramCacheBucket.state,
      MiniProgramCacheBucket.video,
    ];

abstract final class _MpCacheActionHandler {
  static Future<HostActionResult> _cacheSet(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final actionName = 'cache.set';
    final requestId = _optionalStringProp(props, 'requestId');
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final bucket = _cacheBucketProp(props);
    final disabledBucket = _disabledCacheBucket(
      scope,
      actionName,
      bucket,
      requestId: requestId,
    );
    if (disabledBucket != null) {
      return disabledBucket;
    }
    await cache.set(
      _stringProp(props, 'key'),
      props['value'],
      bucket: bucket,
      ttl: _optionalDurationMs(props, 'ttlMs'),
      priority: _cachePriorityProp(props),
    );
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: const <String, dynamic>{'stored': true},
    );
  }

  static Future<HostActionResult> _cacheGet(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final actionName = 'cache.get';
    final requestId = _optionalStringProp(props, 'requestId');
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final key = _stringProp(props, 'key');
    final bucket = _cacheBucketProp(props);
    final disabledBucket = _disabledCacheBucket(
      scope,
      actionName,
      bucket,
      requestId: requestId,
    );
    if (disabledBucket != null) {
      return disabledBucket;
    }
    final found = await cache.has(key, bucket: bucket);
    final value = found ? await cache.get<Object?>(key, bucket: bucket) : null;
    final targetState = _optionalStringProp(props, 'targetState');
    final skipMissing = _boolProp(props, 'skipMissing');
    if (targetState != null && (found || !skipMissing)) {
      final state = scope.stateManager;
      if (state == null) {
        return _MpStateActionHandler._stateUnavailable(
          actionName,
          requestId: requestId,
        );
      }
      state.set(targetState, value);
    }
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: <String, dynamic>{'found': found, 'value': value},
    );
  }

  static Future<HostActionResult> _cacheHas(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final actionName = 'cache.has';
    final requestId = _optionalStringProp(props, 'requestId');
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final bucket = _cacheBucketProp(props);
    final disabledBucket = _disabledCacheBucket(
      scope,
      actionName,
      bucket,
      requestId: requestId,
    );
    if (disabledBucket != null) {
      return disabledBucket;
    }
    final found = await cache.has(_stringProp(props, 'key'), bucket: bucket);
    final targetState = _optionalStringProp(props, 'targetState');
    if (targetState != null) {
      final state = scope.stateManager;
      if (state == null) {
        return _MpStateActionHandler._stateUnavailable(
          actionName,
          requestId: requestId,
        );
      }
      state.set(targetState, found);
    }
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: <String, dynamic>{'found': found},
    );
  }

  static Future<HostActionResult> _cacheRemove(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final actionName = 'cache.remove';
    final requestId = _optionalStringProp(props, 'requestId');
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final key = _stringProp(props, 'key');
    final bucket = _cacheBucketProp(props);
    final disabledBucket = _disabledCacheBucket(
      scope,
      actionName,
      bucket,
      requestId: requestId,
    );
    if (disabledBucket != null) {
      return disabledBucket;
    }
    final existed = await cache.has(key, bucket: bucket);
    await cache.remove(key, bucket: bucket);
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: <String, dynamic>{'removed': existed},
    );
  }

  static Future<HostActionResult> _cacheClear(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final actionName = 'cache.clear';
    final requestId = _optionalStringProp(props, 'requestId');
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final bucketName = _optionalStringProp(props, 'bucket');
    if (bucketName != null) {
      final bucket = _cacheBucketFromName(bucketName);
      final disabledBucket = _disabledCacheBucket(
        scope,
        actionName,
        bucket,
        requestId: requestId,
      );
      if (disabledBucket != null) {
        return disabledBucket;
      }
      await cache.clear(bucket: bucket);
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: <String, dynamic>{
          'cleared': true,
          'clearedBuckets': <String>[bucket.name],
        },
      );
    }
    final clearedBuckets = <String>[];
    for (final bucket in _miniProgramCacheActionBuckets) {
      if (!scope.cachePolicy.allowsMiniProgramBucket(bucket)) {
        continue;
      }
      await cache.clear(bucket: bucket);
      clearedBuckets.add(bucket.name);
    }
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: <String, dynamic>{
        'cleared': true,
        'clearedBuckets': clearedBuckets,
      },
    );
  }

  static Future<HostActionResult> _cacheInfo(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'cache.info';
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    final usage = await scope.cacheManager.usageForApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final data = usage.toMiniProgramJson();
    state.set(_stringProp(props, 'targetState'), data);
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: data,
    );
  }

  static HostActionResult? _disabledCacheBucket(
    MiniProgramSdkScope scope,
    String actionName,
    MiniProgramCacheBucket bucket, {
    String? requestId,
  }) {
    if (scope.cachePolicy.enabled &&
        scope.cachePolicy.allowsMiniProgramBucket(bucket)) {
      return null;
    }
    return HostActionResult.failed(
      requestId: requestId,
      actionName: actionName,
      message:
          'Cache bucket "${bucket.name}" is disabled by host policy for this mini-program.',
      errorCode: 'cache_bucket_disabled',
    );
  }
}
