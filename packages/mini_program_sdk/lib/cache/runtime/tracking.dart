part of '../runtime_cache.dart';

String _rememberCacheApp(
  MiniProgramCacheManager manager,
  String appId, {
  MiniProgramCachePolicy? policy,
}) {
  final normalizedAppId = _normalizeAppId(appId);
  manager._knownAppIds.add(normalizedAppId);
  if (policy != null) {
    manager._policies[normalizedAppId] = policy;
  }
  return normalizedAppId;
}

Future<List<String>> _trackedCacheAppIds(
  MiniProgramCacheManager manager, {
  String? appId,
  MiniProgramCachePolicy? policy,
}) async {
  if (appId != null) {
    return <String>[_rememberCacheApp(manager, appId, policy: policy)];
  }
  final appIds = <String>{...manager._knownAppIds};
  final indexedStore = manager.store;
  if (indexedStore is MiniProgramIndexedCacheStore) {
    appIds.addAll(await indexedStore.appIds());
  }
  return appIds.toList(growable: false);
}

Future<void> _touchCacheApp(
  MiniProgramCacheManager manager,
  String appId,
) async {
  final now = manager._clock();
  final existing = manager._metadata[appId];
  if (existing == null) {
    manager._metadata[appId] = MiniProgramCacheMetadata(
      appId: appId,
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
    return;
  }
  manager._metadata[appId] = existing.copyWith(lastAccessedAt: now);
}

Future<void> _refreshCacheMetadata(
  MiniProgramCacheManager manager,
  String appId,
) async {
  final normalizedAppId = _normalizeAppId(appId);
  final entries = await manager.store.entries(normalizedAppId);
  final existing = manager._metadata[normalizedAppId];
  final now = manager._clock();
  final firstOpenedAt = existing?.firstOpenedAt ?? now;
  final lastOpenedAt = existing?.lastOpenedAt ?? now;
  final lastAccessedAt = existing?.lastAccessedAt ?? now;
  manager._metadata[normalizedAppId] = MiniProgramCacheMetadata(
    appId: normalizedAppId,
    firstOpenedAt: firstOpenedAt,
    lastOpenedAt: lastOpenedAt,
    lastAccessedAt: lastAccessedAt,
    totalBytes: entries.fold<int>(0, (sum, entry) => sum + entry.sizeBytes),
    dataBytes: _cacheBytesFor(entries, MiniProgramCacheBucket.data),
    imageBytes: _cacheBytesFor(entries, MiniProgramCacheBucket.image),
    videoBytes: _cacheBytesFor(entries, MiniProgramCacheBucket.video),
    sessionBytes: _cacheBytesFor(entries, MiniProgramCacheBucket.session),
    stateBytes: _cacheBytesFor(entries, MiniProgramCacheBucket.state),
  );
}

int _cacheBytesFor(
  List<MiniProgramCacheEntry> entries,
  MiniProgramCacheBucket bucket,
) {
  return entries
      .where((entry) => entry.bucket == bucket)
      .fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
}
