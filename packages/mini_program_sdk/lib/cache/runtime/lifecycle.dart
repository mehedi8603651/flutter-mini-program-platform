part of '../runtime_cache.dart';

Future<void> _openCacheApp(
  MiniProgramCacheManager manager,
  String appId, {
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  final now = manager._clock();
  final existing = manager._metadata[normalizedAppId];
  manager._metadata[normalizedAppId] =
      existing?.copyWith(lastOpenedAt: now, lastAccessedAt: now) ??
      MiniProgramCacheMetadata(
        appId: normalizedAppId,
        firstOpenedAt: now,
        lastOpenedAt: now,
        lastAccessedAt: now,
        totalBytes: 0,
        dataBytes: 0,
        imageBytes: 0,
        videoBytes: 0,
        sessionBytes: 0,
        stateBytes: 0,
      );
  if (effectivePolicy.clearExpiredOnStartup) {
    await manager.clearExpired(appId: normalizedAppId, policy: effectivePolicy);
  }
  await manager.clearInactiveSessions(policy: effectivePolicy);
  if (effectivePolicy.clearStateOnInactiveExpiry) {
    await manager.clearInactiveState(policy: effectivePolicy);
  }
  if (effectivePolicy.clearWhenOverLimit) {
    await _enforceCacheLimits(manager, normalizedAppId, effectivePolicy);
  }
}

Future<void> _closeCacheApp(
  MiniProgramCacheManager manager,
  String appId, {
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  if (effectivePolicy.clearMemoryOnExit) {
    await manager.clearBucket(
      appId: normalizedAppId,
      bucket: MiniProgramCacheBucket.memory,
      policy: effectivePolicy,
    );
  }
}

Future<void> _clearExpiredCache(
  MiniProgramCacheManager manager, {
  required String? appId,
  required MiniProgramCachePolicy? policy,
}) async {
  final now = manager._clock();
  final appIds = await _trackedCacheAppIds(
    manager,
    appId: appId,
    policy: policy,
  );
  for (final candidate in appIds) {
    final normalizedAppId = _rememberCacheApp(
      manager,
      candidate,
      policy: policy,
    );
    final entries = await manager.store.entries(normalizedAppId);
    for (final entry in entries) {
      if (entry.isExpired(now)) {
        await manager.store.remove(entry.namespacedKey);
      }
    }
    await _refreshCacheMetadata(manager, normalizedAppId);
  }
}

Future<void> _clearLowPriorityCache(
  MiniProgramCacheManager manager, {
  required String? appId,
}) async {
  final appIds = await _trackedCacheAppIds(manager, appId: appId);
  for (final candidate in appIds) {
    final normalizedAppId = _rememberCacheApp(manager, candidate);
    final entries = await manager.store.entries(normalizedAppId);
    for (final entry in entries) {
      if (entry.priority == MiniProgramCachePriority.low) {
        await manager.store.remove(entry.namespacedKey);
      }
    }
    await _refreshCacheMetadata(manager, normalizedAppId);
  }
}

Future<void> _clearAllThirdPartyCache(MiniProgramCacheManager manager) async {
  for (final appId in await _trackedCacheAppIds(manager)) {
    final entries = await manager.store.entries(appId);
    for (final entry in entries) {
      if (entry.priority != MiniProgramCachePriority.hostPinned) {
        await manager.store.remove(entry.namespacedKey);
      }
    }
    await _refreshCacheMetadata(manager, appId);
  }
}

Future<void> _clearCacheOnLogout(
  MiniProgramCacheManager manager,
  String appId, {
  required MiniProgramCachePolicy? policy,
}) async {
  final normalizedAppId = _rememberCacheApp(manager, appId, policy: policy);
  final effectivePolicy = manager._policyFor(normalizedAppId, policy);
  if (!effectivePolicy.clearSessionOnLogout) {
    return;
  }
  await manager.clearBucket(
    appId: normalizedAppId,
    bucket: MiniProgramCacheBucket.session,
    policy: effectivePolicy,
  );
}

Future<void> _clearInactiveSessionCache(
  MiniProgramCacheManager manager, {
  required MiniProgramCachePolicy? policy,
}) async {
  final now = manager._clock();
  for (final metadata in manager._metadata.values.toList()) {
    final effectivePolicy = manager._policyFor(metadata.appId, policy);
    if (now.difference(metadata.lastOpenedAt) >
        effectivePolicy.sessionInactiveTtl) {
      await manager.clearBucket(
        appId: metadata.appId,
        bucket: MiniProgramCacheBucket.session,
        policy: effectivePolicy,
      );
    }
  }
}

Future<void> _clearInactiveStateCache(
  MiniProgramCacheManager manager, {
  required MiniProgramCachePolicy? policy,
}) async {
  final now = manager._clock();
  for (final metadata in manager._metadata.values.toList()) {
    final effectivePolicy = manager._policyFor(metadata.appId, policy);
    if (now.difference(metadata.lastOpenedAt) >
        effectivePolicy.stateInactiveTtl) {
      await manager.clearBucket(
        appId: metadata.appId,
        bucket: MiniProgramCacheBucket.state,
        policy: effectivePolicy,
      );
    }
  }
}
