part of '../runtime_cache.dart';

class MiniProgramMemoryCacheStore implements MiniProgramIndexedCacheStore {
  final Map<String, MiniProgramCacheEntry> _entries =
      <String, MiniProgramCacheEntry>{};

  @override
  Future<void> set(MiniProgramCacheEntry entry) async {
    _entries[entry.namespacedKey] = entry;
  }

  @override
  Future<MiniProgramCacheEntry?> get(String namespacedKey) async {
    return _entries[namespacedKey];
  }

  @override
  Future<void> remove(String namespacedKey) async {
    _entries.remove(namespacedKey);
  }

  @override
  Future<void> clearApp(String appId) async {
    final prefix = 'mp_cache/${_normalizeAppId(appId)}/';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clearBucket(String appId, MiniProgramCacheBucket bucket) async {
    final prefix = 'mp_cache/${_normalizeAppId(appId)}/${bucket.name}/';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<List<MiniProgramCacheEntry>> entries(String appId) async {
    final normalizedAppId = _normalizeAppId(appId);
    return _entries.values
        .where((entry) => entry.appId == normalizedAppId)
        .toList(growable: false);
  }

  @override
  Future<int> totalBytes(String appId) async {
    return (await entries(
      appId,
    )).fold<int>(0, (total, entry) => total + entry.sizeBytes);
  }

  @override
  Future<List<String>> appIds() async {
    return _entries.values
        .map((entry) => entry.appId)
        .toSet()
        .toList(growable: false);
  }
}
