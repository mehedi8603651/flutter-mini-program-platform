part of '../runtime_cache.dart';

Future<T?> _getCacheValue<T>(
  MiniProgramCacheManager manager, {
  required String appId,
  required String key,
  required MiniProgramCacheBucket bucket,
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final normalizedKey = _normalizeKey(key);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  if (!effectivePolicy.enabled) {
    return null;
  }
  final namespacedKey = MiniProgramCacheManager.namespacedKey(
    appId: normalizedAppId,
    bucket: bucket,
    key: normalizedKey,
  );
  final entry = await manager.store.get(namespacedKey);
  if (entry == null) {
    return null;
  }
  final now = manager._clock();
  if (entry.isExpired(now)) {
    await manager.store.remove(namespacedKey);
    await _refreshCacheMetadata(manager, normalizedAppId);
    return null;
  }
  await manager.store.set(entry.copyWith(lastAccessedAt: now));
  await _touchCacheApp(manager, normalizedAppId);
  final value = entry.value;
  return value is T ? value : null;
}

Future<bool> _hasCacheValue(
  MiniProgramCacheManager manager, {
  required String appId,
  required String key,
  required MiniProgramCacheBucket bucket,
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final normalizedKey = _normalizeKey(key);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  if (!effectivePolicy.enabled) {
    return false;
  }
  final namespacedKey = MiniProgramCacheManager.namespacedKey(
    appId: normalizedAppId,
    bucket: bucket,
    key: normalizedKey,
  );
  final entry = await manager.store.get(namespacedKey);
  if (entry == null) {
    return false;
  }
  final now = manager._clock();
  if (entry.isExpired(now)) {
    await manager.store.remove(namespacedKey);
    await _refreshCacheMetadata(manager, normalizedAppId);
    return false;
  }
  await manager.store.set(entry.copyWith(lastAccessedAt: now));
  await _touchCacheApp(manager, normalizedAppId);
  return true;
}

Future<void> _removeCacheValue(
  MiniProgramCacheManager manager, {
  required String appId,
  required String key,
  required MiniProgramCacheBucket bucket,
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final namespacedKey = MiniProgramCacheManager.namespacedKey(
    appId: normalizedAppId,
    bucket: bucket,
    key: key,
  );
  await manager.store.remove(namespacedKey);
  await _refreshCacheMetadata(manager, normalizedAppId);
}

Future<void> _clearCache(
  MiniProgramCacheManager manager, {
  required String appId,
  required MiniProgramCacheBucket? bucket,
  required MiniProgramCachePolicy? policy,
}) async {
  if (bucket == null) {
    await manager.clearApp(appId, policy: policy);
    return;
  }
  await manager.clearBucket(appId: appId, bucket: bucket, policy: policy);
}

Future<void> _clearCacheApp(
  MiniProgramCacheManager manager,
  String appId, {
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  await manager.store.clearApp(normalizedAppId);
  await _refreshCacheMetadata(manager, normalizedAppId);
}

Future<void> _clearCacheBucket(
  MiniProgramCacheManager manager, {
  required String appId,
  required MiniProgramCacheBucket bucket,
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  await manager.store.clearBucket(normalizedAppId, bucket);
  await _refreshCacheMetadata(manager, normalizedAppId);
}

Future<int> _getCacheTotalBytes(
  MiniProgramCacheManager manager, {
  required String? appId,
}) async {
  if (appId != null) {
    return manager.store.totalBytes(_normalizeAppId(appId));
  }
  var total = 0;
  for (final knownAppId in await _trackedCacheAppIds(manager)) {
    total += await manager.store.totalBytes(knownAppId);
  }
  return total;
}

Future<MiniProgramCacheUsage> _cacheUsageForApp(
  MiniProgramCacheManager manager,
  String appId, {
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  await manager.clearExpired(appId: normalizedAppId, policy: effectivePolicy);
  final entries = await manager.store.entries(normalizedAppId);
  final buckets = <MiniProgramCacheBucket, MiniProgramCacheBucketUsage>{};
  for (final bucket in MiniProgramCacheBucket.values) {
    final bucketEntries = entries
        .where((entry) => entry.bucket == bucket)
        .toList(growable: false);
    final usedBytes = bucketEntries.fold<int>(
      0,
      (total, entry) => total + entry.sizeBytes,
    );
    final miniProgramEntries = bucketEntries
        .where((entry) => entry.priority != MiniProgramCachePriority.hostPinned)
        .toList(growable: false);
    final miniProgramUsedBytes = miniProgramEntries.fold<int>(
      0,
      (total, entry) => total + entry.sizeBytes,
    );
    final maxBytes = effectivePolicy.maxBytesFor(bucket);
    buckets[bucket] = MiniProgramCacheBucketUsage(
      bucket: bucket,
      enabledForMiniProgram:
          effectivePolicy.enabled &&
          effectivePolicy.allowsMiniProgramBucket(bucket),
      usedBytes: usedBytes,
      miniProgramUsedBytes: miniProgramUsedBytes,
      maxBytes: maxBytes,
      remainingBytes: maxBytes == null
          ? null
          : (maxBytes - usedBytes).clamp(0, maxBytes).toInt(),
      ttl: effectivePolicy.ttlFor(bucket),
      entryCount: bucketEntries.length,
      miniProgramEntryCount: miniProgramEntries.length,
    );
  }
  final usedBytes = entries.fold<int>(
    0,
    (total, entry) => total + entry.sizeBytes,
  );
  return MiniProgramCacheUsage(
    appId: normalizedAppId,
    enabled: effectivePolicy.enabled,
    usedBytes: usedBytes,
    maxBytes: effectivePolicy.maxBytes,
    remainingBytes: (effectivePolicy.maxBytes - usedBytes)
        .clamp(0, effectivePolicy.maxBytes)
        .toInt(),
    entryCount: entries.length,
    buckets:
        Map<MiniProgramCacheBucket, MiniProgramCacheBucketUsage>.unmodifiable(
          buckets,
        ),
  );
}

Future<void> _setCacheValue(
  MiniProgramCacheManager manager, {
  required String appId,
  required String key,
  required Object? value,
  required MiniProgramCacheBucket bucket,
  required Duration? ttl,
  required MiniProgramCachePriority priority,
  required int? sizeBytes,
  required MiniProgramCachePolicy? policy,
  required bool hostOwned,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final normalizedKey = _normalizeKey(key);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  if (!effectivePolicy.enabled) {
    return;
  }
  if (!hostOwned && bucket == MiniProgramCacheBucket.session) {
    throw ArgumentError.value(
      bucket,
      'bucket',
      'The session cache bucket is host-controlled.',
    );
  }
  if (!hostOwned && priority == MiniProgramCachePriority.hostPinned) {
    throw ArgumentError.value(
      priority,
      'priority',
      'Host-pinned cache priority is host-controlled.',
    );
  }
  final normalizedValue = _normalizeCacheValue(value);
  final normalizedSize = sizeBytes ?? _encodedSize(normalizedValue);
  if (normalizedSize < 0) {
    throw ArgumentError.value(
      sizeBytes,
      'sizeBytes',
      'Cache size must be non-negative.',
    );
  }
  final resolvedTtl = _clampCacheTtl(
    ttl,
    bucket: bucket,
    policy: effectivePolicy,
  );
  final now = manager._clock();
  final namespacedKey = MiniProgramCacheManager.namespacedKey(
    appId: normalizedAppId,
    bucket: bucket,
    key: normalizedKey,
  );
  final existing = await manager.store.get(namespacedKey);
  await manager.store.set(
    MiniProgramCacheEntry(
      appId: normalizedAppId,
      bucket: bucket,
      key: normalizedKey,
      value: normalizedValue,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastAccessedAt: now,
      expiresAt: now.add(resolvedTtl),
      sizeBytes: normalizedSize,
      priority: priority,
    ),
  );
  await _touchCacheApp(manager, normalizedAppId);
  await _refreshCacheMetadata(manager, normalizedAppId);
  if (effectivePolicy.clearWhenOverLimit) {
    await _enforceCacheLimits(manager, normalizedAppId, effectivePolicy);
  }
}

Duration _clampCacheTtl(
  Duration? requested, {
  required MiniProgramCacheBucket bucket,
  required MiniProgramCachePolicy policy,
}) {
  final maxTtl = policy.ttlFor(bucket);
  if (requested == null) {
    return maxTtl;
  }
  if (requested <= Duration.zero) {
    throw ArgumentError.value(requested, 'ttl', 'Cache TTL must be positive.');
  }
  return requested <= maxTtl ? requested : maxTtl;
}
