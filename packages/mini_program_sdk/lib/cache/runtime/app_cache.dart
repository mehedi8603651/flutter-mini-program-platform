part of '../runtime_cache.dart';

class MiniProgramAppCache {
  const MiniProgramAppCache._({
    required MiniProgramCacheManager manager,
    required String appId,
    MiniProgramCachePolicy? policy,
  }) : _manager = manager,
       _appId = appId,
       _policy = policy;

  final MiniProgramCacheManager _manager;
  final String _appId;
  final MiniProgramCachePolicy? _policy;

  String get appId => _appId;

  Future<void> set(
    String key,
    Object? value, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    Duration? ttl,
    MiniProgramCachePriority priority = MiniProgramCachePriority.normal,
  }) {
    _checkBucketAllowed(bucket);
    return _manager._set(
      appId: _appId,
      key: key,
      value: value,
      bucket: bucket,
      ttl: ttl,
      priority: priority,
      sizeBytes: null,
      policy: _policy,
      hostOwned: false,
    );
  }

  Future<T?> get<T>(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    _checkBucketAllowed(bucket);
    return _manager.get<T>(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<bool> has(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    _checkBucketAllowed(bucket);
    return _manager.has(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<void> remove(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    _checkBucketAllowed(bucket);
    return _manager.remove(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<void> clear({MiniProgramCacheBucket? bucket}) {
    if (bucket != null) {
      _checkBucketAllowed(bucket);
      return _manager.clear(appId: _appId, bucket: bucket, policy: _policy);
    }
    return _clearAllowedBuckets();
  }

  Future<void> _clearAllowedBuckets() async {
    final policy = _manager._policyFor(_appId, _policy);
    for (final bucket in _defaultMiniProgramCacheBuckets) {
      if (!policy.allowsMiniProgramBucket(bucket)) {
        continue;
      }
      await _manager.clear(appId: _appId, bucket: bucket, policy: policy);
    }
  }

  void _checkBucketAllowed(MiniProgramCacheBucket bucket) {
    final policy = _manager._policyFor(_appId, _policy);
    if (policy.allowsMiniProgramBucket(bucket)) {
      return;
    }
    throw ArgumentError.value(
      bucket,
      'bucket',
      'The cache bucket is disabled by host policy for this mini-program.',
    );
  }
}
