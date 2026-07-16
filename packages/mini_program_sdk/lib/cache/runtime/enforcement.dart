part of '../runtime_cache.dart';

Future<void> _enforceCacheLimits(
  MiniProgramCacheManager manager,
  String appId,
  MiniProgramCachePolicy policy,
) async {
  await manager.clearExpired(appId: appId, policy: policy);
  for (final bucket in MiniProgramCacheBucket.values) {
    final bucketLimit = policy.maxBytesFor(bucket);
    if (bucketLimit == null) {
      continue;
    }
    await _enforceCacheBucketLimit(manager, appId, bucket, bucketLimit);
  }
  await _enforceCacheTotalLimit(manager, appId, policy.maxBytes);
  await _refreshCacheMetadata(manager, appId);
}

Future<void> _enforceCacheBucketLimit(
  MiniProgramCacheManager manager,
  String appId,
  MiniProgramCacheBucket bucket,
  int limit,
) async {
  final entries = (await manager.store.entries(appId))
      .where(
        (entry) =>
            entry.bucket == bucket &&
            entry.priority != MiniProgramCachePriority.hostPinned,
      )
      .toList();
  entries.sort(_compareCacheCleanup);
  var total = entries.fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
  for (final entry in entries) {
    if (total <= limit) {
      return;
    }
    await manager.store.remove(entry.namespacedKey);
    total -= entry.sizeBytes;
  }
}

Future<void> _enforceCacheTotalLimit(
  MiniProgramCacheManager manager,
  String appId,
  int limit,
) async {
  final entries = (await manager.store.entries(appId))
      .where((entry) => entry.priority != MiniProgramCachePriority.hostPinned)
      .toList();
  entries.sort(_compareCacheCleanup);
  var total = (await manager.store.entries(
    appId,
  )).fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
  for (final entry in entries) {
    if (total <= limit) {
      return;
    }
    await manager.store.remove(entry.namespacedKey);
    total -= entry.sizeBytes;
  }
}

int _compareCacheCleanup(MiniProgramCacheEntry a, MiniProgramCacheEntry b) {
  final priorityCompare = _cachePriorityRank(
    a.priority,
  ).compareTo(_cachePriorityRank(b.priority));
  if (priorityCompare != 0) {
    return priorityCompare;
  }
  final bucketCompare = _cacheBucketCleanupRank(
    a.bucket,
  ).compareTo(_cacheBucketCleanupRank(b.bucket));
  if (bucketCompare != 0) {
    return bucketCompare;
  }
  return a.lastAccessedAt.compareTo(b.lastAccessedAt);
}

int _cachePriorityRank(MiniProgramCachePriority priority) {
  return switch (priority) {
    MiniProgramCachePriority.low => 0,
    MiniProgramCachePriority.normal => 1,
    MiniProgramCachePriority.high => 2,
    MiniProgramCachePriority.hostPinned => 3,
  };
}

int _cacheBucketCleanupRank(MiniProgramCacheBucket bucket) {
  return switch (bucket) {
    MiniProgramCacheBucket.video => 0,
    MiniProgramCacheBucket.image => 1,
    MiniProgramCacheBucket.data => 2,
    MiniProgramCacheBucket.state => 3,
    MiniProgramCacheBucket.memory => 4,
    MiniProgramCacheBucket.session => 5,
  };
}
