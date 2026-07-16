import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime_cache.dart';
import 'runtime_entry_codec.dart';
import 'storage_key_codec.dart';

class SharedPreferencesMiniProgramCacheStore
    implements MiniProgramIndexedCacheStore {
  SharedPreferencesMiniProgramCacheStore({
    String keyPrefix = 'mini_program_runtime_cache',
    Set<MiniProgramCacheBucket> persistentBuckets = _defaultPersistentBuckets,
    MiniProgramCacheClock? clock,
    Future<SharedPreferences>? preferences,
  }) : _keyPrefix = normalizeRuntimeCacheKeyPrefix(keyPrefix),
       _persistentBuckets = Set<MiniProgramCacheBucket>.unmodifiable(
         persistentBuckets,
       ),
       _clock = clock ?? DateTime.now,
       _preferences = preferences ?? SharedPreferences.getInstance();

  final String _keyPrefix;
  final Set<MiniProgramCacheBucket> _persistentBuckets;
  final MiniProgramCacheClock _clock;
  final Future<SharedPreferences> _preferences;
  final Map<String, MiniProgramCacheEntry> _entries =
      <String, MiniProgramCacheEntry>{};
  final Set<String> _loadedKeys = <String>{};
  bool _loadedPersistedEntries = false;

  @override
  Future<void> set(MiniProgramCacheEntry entry) async {
    _entries[entry.namespacedKey] = entry;
    _loadedKeys.add(entry.namespacedKey);
    if (!_persistentBuckets.contains(entry.bucket)) {
      await _removeStorageKey(_storageKeyFor(entry.namespacedKey));
      return;
    }
    final prefs = await _preferences;
    await prefs.setString(
      _storageKeyFor(entry.namespacedKey),
      jsonEncode(encodeRuntimeCacheEntry(entry)),
    );
  }

  @override
  Future<MiniProgramCacheEntry?> get(String namespacedKey) async {
    if (_loadedKeys.contains(namespacedKey)) {
      final entry = _entries[namespacedKey];
      if (entry != null && entry.isExpired(_clock())) {
        await remove(namespacedKey);
        return null;
      }
      return entry;
    }
    _loadedKeys.add(namespacedKey);
    final entry = await _readEntry(_storageKeyFor(namespacedKey));
    if (entry == null) {
      return null;
    }
    _entries[namespacedKey] = entry;
    return entry;
  }

  @override
  Future<void> remove(String namespacedKey) async {
    _entries.remove(namespacedKey);
    _loadedKeys.add(namespacedKey);
    await _removeStorageKey(_storageKeyFor(namespacedKey));
  }

  @override
  Future<void> clearApp(String appId) async {
    final normalizedAppId = MiniProgramCacheManager.namespacedKey(
      appId: appId,
      bucket: MiniProgramCacheBucket.data,
      key: '_probe',
    ).split('/')[1];
    _entries.removeWhere((_, entry) => entry.appId == normalizedAppId);
    await _removeStoredEntriesWhere(
      (entry) => entry == null || entry.appId == normalizedAppId,
    );
  }

  @override
  Future<void> clearBucket(String appId, MiniProgramCacheBucket bucket) async {
    final normalizedAppId = MiniProgramCacheManager.namespacedKey(
      appId: appId,
      bucket: bucket,
      key: '_probe',
    ).split('/')[1];
    _entries.removeWhere(
      (_, entry) => entry.appId == normalizedAppId && entry.bucket == bucket,
    );
    await _removeStoredEntriesWhere(
      (entry) =>
          entry == null ||
          (entry.appId == normalizedAppId && entry.bucket == bucket),
    );
  }

  @override
  Future<List<MiniProgramCacheEntry>> entries(String appId) async {
    final normalizedAppId = MiniProgramCacheManager.namespacedKey(
      appId: appId,
      bucket: MiniProgramCacheBucket.data,
      key: '_probe',
    ).split('/')[1];
    await _loadPersistedEntries();
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
    await _loadPersistedEntries();
    return _entries.values
        .map((entry) => entry.appId)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _loadPersistedEntries() async {
    if (_loadedPersistedEntries) {
      return;
    }
    _loadedPersistedEntries = true;
    for (final storageKey in await _storageKeys()) {
      await _readEntry(storageKey);
    }
  }

  Future<MiniProgramCacheEntry?> _readEntry(String storageKey) async {
    final prefs = await _preferences;
    final value = prefs.getString(storageKey);
    if (value == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        await prefs.remove(storageKey);
        return null;
      }
      final entry = decodeRuntimeCacheEntry(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (entry == null ||
          entry.isExpired(_clock()) ||
          !_persistentBuckets.contains(entry.bucket)) {
        await prefs.remove(storageKey);
        return null;
      }
      _loadedKeys.add(entry.namespacedKey);
      _entries[entry.namespacedKey] = entry;
      return entry;
    } catch (_) {
      await prefs.remove(storageKey);
      return null;
    }
  }

  Future<void> _removeStoredEntriesWhere(
    bool Function(MiniProgramCacheEntry? entry) shouldRemove,
  ) async {
    final prefs = await _preferences;
    for (final storageKey in await _storageKeys()) {
      final entry = await _readEntry(storageKey);
      if (shouldRemove(entry)) {
        if (entry != null) {
          _entries.remove(entry.namespacedKey);
        }
        await prefs.remove(storageKey);
      }
    }
  }

  Future<List<String>> _storageKeys() async {
    final prefs = await _preferences;
    final prefix = '$_keyPrefix/';
    return prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
  }

  Future<void> _removeStorageKey(String storageKey) async {
    final prefs = await _preferences;
    await prefs.remove(storageKey);
  }

  String _storageKeyFor(String namespacedKey) {
    return '$_keyPrefix/${encodeRuntimeCacheStorageKey(namespacedKey)}';
  }
}

const Set<MiniProgramCacheBucket> _defaultPersistentBuckets =
    <MiniProgramCacheBucket>{
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.image,
      MiniProgramCacheBucket.state,
      MiniProgramCacheBucket.video,
    };
