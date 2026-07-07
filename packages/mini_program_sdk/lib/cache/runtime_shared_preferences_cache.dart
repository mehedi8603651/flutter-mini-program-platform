import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'runtime_cache.dart';

class SharedPreferencesMiniProgramCacheStore
    implements MiniProgramIndexedCacheStore {
  SharedPreferencesMiniProgramCacheStore({
    String keyPrefix = 'mini_program_runtime_cache',
    Set<MiniProgramCacheBucket> persistentBuckets = _defaultPersistentBuckets,
    MiniProgramCacheClock? clock,
    Future<SharedPreferences>? preferences,
  }) : _keyPrefix = _normalizeKeyPrefix(keyPrefix),
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
      jsonEncode(_entryToJson(entry)),
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
      final entry = _entryFromJson(
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
    return '$_keyPrefix/${base64Url.encode(utf8.encode(namespacedKey))}';
  }
}

const Set<MiniProgramCacheBucket> _defaultPersistentBuckets =
    <MiniProgramCacheBucket>{
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.image,
      MiniProgramCacheBucket.state,
      MiniProgramCacheBucket.video,
    };

const int _schemaVersion = 1;

String _normalizeKeyPrefix(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.contains('/') ||
      normalized.contains('\\')) {
    throw ArgumentError.value(
      value,
      'keyPrefix',
      'Shared preferences cache keyPrefix must be a non-empty key namespace.',
    );
  }
  return normalized;
}

Map<String, Object?> _entryToJson(MiniProgramCacheEntry entry) {
  return <String, Object?>{
    'schemaVersion': _schemaVersion,
    'appId': entry.appId,
    'bucket': entry.bucket.name,
    'key': entry.key,
    'value': entry.value,
    'createdAt': entry.createdAt.toUtc().toIso8601String(),
    'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
    'lastAccessedAt': entry.lastAccessedAt.toUtc().toIso8601String(),
    'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
    'sizeBytes': entry.sizeBytes,
    'priority': entry.priority.name,
  };
}

MiniProgramCacheEntry? _entryFromJson(Map<String, Object?> json) {
  if (json['schemaVersion'] != _schemaVersion) {
    return null;
  }
  final appId = json['appId'];
  final bucketName = json['bucket'];
  final key = json['key'];
  final createdAt = json['createdAt'];
  final updatedAt = json['updatedAt'];
  final lastAccessedAt = json['lastAccessedAt'];
  final expiresAt = json['expiresAt'];
  final sizeBytes = json['sizeBytes'];
  final priorityName = json['priority'];
  if (appId is! String ||
      bucketName is! String ||
      key is! String ||
      createdAt is! String ||
      updatedAt is! String ||
      lastAccessedAt is! String ||
      expiresAt is! String ||
      sizeBytes is! int ||
      priorityName is! String) {
    return null;
  }
  final bucket = _bucketFromName(bucketName);
  final priority = _priorityFromName(priorityName);
  if (bucket == null || priority == null || sizeBytes < 0) {
    return null;
  }
  return MiniProgramCacheEntry(
    appId: appId,
    bucket: bucket,
    key: key,
    value: json['value'],
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
    lastAccessedAt: DateTime.parse(lastAccessedAt),
    expiresAt: DateTime.parse(expiresAt),
    sizeBytes: sizeBytes,
    priority: priority,
  );
}

MiniProgramCacheBucket? _bucketFromName(String name) {
  for (final bucket in MiniProgramCacheBucket.values) {
    if (bucket.name == name) {
      return bucket;
    }
  }
  return null;
}

MiniProgramCachePriority? _priorityFromName(String name) {
  for (final priority in MiniProgramCachePriority.values) {
    if (priority.name == name) {
      return priority;
    }
  }
  return null;
}
