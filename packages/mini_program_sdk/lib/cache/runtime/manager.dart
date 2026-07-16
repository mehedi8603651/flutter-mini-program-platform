part of '../runtime_cache.dart';

class MiniProgramCacheManager {
  MiniProgramCacheManager({
    MiniProgramCacheStore? store,
    this.defaultPolicy = const MiniProgramCachePolicy(),
    MiniProgramCacheClock? clock,
  }) : store = store ?? MiniProgramMemoryCacheStore(),
       _clock = clock ?? DateTime.now;

  factory MiniProgramCacheManager.inMemory({
    MiniProgramCachePolicy defaultPolicy = const MiniProgramCachePolicy(),
    MiniProgramCacheClock? clock,
  }) {
    return MiniProgramCacheManager(
      store: MiniProgramMemoryCacheStore(),
      defaultPolicy: defaultPolicy,
      clock: clock,
    );
  }

  final MiniProgramCacheStore store;
  final MiniProgramCachePolicy defaultPolicy;
  final MiniProgramCacheClock _clock;
  final Map<String, MiniProgramCachePolicy> _policies =
      <String, MiniProgramCachePolicy>{};
  final Map<String, MiniProgramCacheMetadata> _metadata =
      <String, MiniProgramCacheMetadata>{};
  final Set<String> _knownAppIds = <String>{};

  static String namespacedKey({
    required String appId,
    required MiniProgramCacheBucket bucket,
    required String key,
  }) {
    return 'mp_cache/${_normalizeAppId(appId)}/${bucket.name}/${_normalizeKey(key)}';
  }

  MiniProgramAppCache forApp(String appId, {MiniProgramCachePolicy? policy}) {
    return MiniProgramAppCache._(
      manager: this,
      appId: _normalizeAppId(appId),
      policy: policy,
    );
  }

  Future<void> openApp(String appId, {MiniProgramCachePolicy? policy}) {
    return _openCacheApp(this, appId, policy: policy);
  }

  Future<void> closeApp(String appId, {MiniProgramCachePolicy? policy}) {
    return _closeCacheApp(this, appId, policy: policy);
  }

  Future<void> set({
    required String appId,
    required String key,
    required Object? value,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    Duration? ttl,
    MiniProgramCachePriority priority = MiniProgramCachePriority.normal,
    int? sizeBytes,
    MiniProgramCachePolicy? policy,
  }) {
    return _set(
      appId: appId,
      key: key,
      value: value,
      bucket: bucket,
      ttl: ttl,
      priority: priority,
      sizeBytes: sizeBytes,
      policy: policy,
      hostOwned: true,
    );
  }

  Future<T?> get<T>({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) {
    return _getCacheValue<T>(
      this,
      appId: appId,
      key: key,
      bucket: bucket,
      policy: policy,
    );
  }

  Future<bool> has({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) {
    return _hasCacheValue(
      this,
      appId: appId,
      key: key,
      bucket: bucket,
      policy: policy,
    );
  }

  Future<void> remove({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) {
    return _removeCacheValue(
      this,
      appId: appId,
      key: key,
      bucket: bucket,
      policy: policy,
    );
  }

  Future<void> clear({
    required String appId,
    MiniProgramCacheBucket? bucket,
    MiniProgramCachePolicy? policy,
  }) {
    return _clearCache(this, appId: appId, bucket: bucket, policy: policy);
  }

  Future<void> clearApp(String appId, {MiniProgramCachePolicy? policy}) {
    return _clearCacheApp(this, appId, policy: policy);
  }

  Future<void> clearBucket({
    required String appId,
    required MiniProgramCacheBucket bucket,
    MiniProgramCachePolicy? policy,
  }) {
    return _clearCacheBucket(
      this,
      appId: appId,
      bucket: bucket,
      policy: policy,
    );
  }

  Future<void> clearExpired({String? appId, MiniProgramCachePolicy? policy}) {
    return _clearExpiredCache(this, appId: appId, policy: policy);
  }

  Future<void> clearLowPriority({String? appId}) {
    return _clearLowPriorityCache(this, appId: appId);
  }

  Future<void> clearAllThirdParty() {
    return _clearAllThirdPartyCache(this);
  }

  Future<void> clearOnLogout(String appId, {MiniProgramCachePolicy? policy}) {
    return _clearCacheOnLogout(this, appId, policy: policy);
  }

  Future<void> clearInactiveSessions({MiniProgramCachePolicy? policy}) {
    return _clearInactiveSessionCache(this, policy: policy);
  }

  Future<void> clearInactiveState({MiniProgramCachePolicy? policy}) {
    return _clearInactiveStateCache(this, policy: policy);
  }

  MiniProgramCacheMetadata? getMetadata(String appId) {
    return _metadata[_normalizeAppId(appId)];
  }

  Future<int> getTotalBytes({String? appId}) {
    return _getCacheTotalBytes(this, appId: appId);
  }

  Future<MiniProgramCacheUsage> usageForApp(
    String appId, {
    MiniProgramCachePolicy? policy,
  }) {
    return _cacheUsageForApp(this, appId, policy: policy);
  }

  Future<void> _set({
    required String appId,
    required String key,
    required Object? value,
    required MiniProgramCacheBucket bucket,
    required Duration? ttl,
    required MiniProgramCachePriority priority,
    required int? sizeBytes,
    required MiniProgramCachePolicy? policy,
    required bool hostOwned,
  }) {
    return _setCacheValue(
      this,
      appId: appId,
      key: key,
      value: value,
      bucket: bucket,
      ttl: ttl,
      priority: priority,
      sizeBytes: sizeBytes,
      policy: policy,
      hostOwned: hostOwned,
    );
  }

  MiniProgramCachePolicy _policyFor(
    String appId,
    MiniProgramCachePolicy? override,
  ) {
    return override ?? _policies[appId] ?? defaultPolicy;
  }
}
