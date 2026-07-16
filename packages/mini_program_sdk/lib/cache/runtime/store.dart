part of '../runtime_cache.dart';

abstract interface class MiniProgramCacheStore {
  Future<void> set(MiniProgramCacheEntry entry);
  Future<MiniProgramCacheEntry?> get(String namespacedKey);
  Future<void> remove(String namespacedKey);
  Future<void> clearApp(String appId);
  Future<void> clearBucket(String appId, MiniProgramCacheBucket bucket);
  Future<List<MiniProgramCacheEntry>> entries(String appId);
  Future<int> totalBytes(String appId);
}

abstract interface class MiniProgramIndexedCacheStore
    implements MiniProgramCacheStore {
  Future<List<String>> appIds();
}
