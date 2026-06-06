import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'runtime_cache.dart';

class FileMiniProgramCacheStore implements MiniProgramIndexedCacheStore {
  FileMiniProgramCacheStore({
    required Directory directory,
    Set<MiniProgramCacheBucket> persistentBuckets = _defaultPersistentBuckets,
    MiniProgramCacheClock? clock,
  }) : _directory = directory,
       _persistentBuckets = Set<MiniProgramCacheBucket>.unmodifiable(
         persistentBuckets,
       ),
       _clock = clock ?? DateTime.now;

  final Directory _directory;
  final Set<MiniProgramCacheBucket> _persistentBuckets;
  final MiniProgramCacheClock _clock;
  final Map<String, MiniProgramCacheEntry> _entries =
      <String, MiniProgramCacheEntry>{};
  final Set<String> _loadedKeys = <String>{};
  bool _loadedPersistedEntries = false;

  @override
  Future<void> set(MiniProgramCacheEntry entry) async {
    _entries[entry.namespacedKey] = entry;
    _loadedKeys.add(entry.namespacedKey);
    if (!_persistentBuckets.contains(entry.bucket)) {
      await _safeDelete(_fileFor(entry.namespacedKey));
      return;
    }
    await _writeEntry(entry);
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
    final entry = await _readEntry(_fileFor(namespacedKey));
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
    await _safeDelete(_fileFor(namespacedKey));
  }

  @override
  Future<void> clearApp(String appId) async {
    final normalizedAppId = MiniProgramCacheManager.namespacedKey(
      appId: appId,
      bucket: MiniProgramCacheBucket.data,
      key: '_probe',
    ).split('/')[1];
    _entries.removeWhere((_, entry) => entry.appId == normalizedAppId);
    if (!await _directory.exists()) {
      return;
    }
    for (final file in await _entryFiles()) {
      final entry = await _readEntry(file);
      if (entry == null) {
        await _safeDelete(file);
        continue;
      }
      if (entry.appId == normalizedAppId) {
        _entries.remove(entry.namespacedKey);
        await _safeDelete(file);
      }
    }
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
    if (!await _directory.exists()) {
      return;
    }
    for (final file in await _entryFiles()) {
      final entry = await _readEntry(file);
      if (entry == null) {
        await _safeDelete(file);
        continue;
      }
      if (entry.appId == normalizedAppId && entry.bucket == bucket) {
        _entries.remove(entry.namespacedKey);
        await _safeDelete(file);
      }
    }
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

  Future<void> _writeEntry(MiniProgramCacheEntry entry) async {
    await _directory.create(recursive: true);
    final target = _fileFor(entry.namespacedKey);
    final temp = File(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temp.writeAsString(jsonEncode(_entryToJson(entry)), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<MiniProgramCacheEntry?> _readEntry(File file) async {
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        await _safeDelete(file);
        return null;
      }
      final entry = _entryFromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (entry == null ||
          entry.isExpired(_clock()) ||
          !_persistentBuckets.contains(entry.bucket)) {
        await _safeDelete(file);
        return null;
      }
      _loadedKeys.add(entry.namespacedKey);
      _entries[entry.namespacedKey] = entry;
      return entry;
    } catch (_) {
      await _safeDelete(file);
      return null;
    }
  }

  Future<void> _loadPersistedEntries() async {
    if (_loadedPersistedEntries) {
      return;
    }
    _loadedPersistedEntries = true;
    if (!await _directory.exists()) {
      return;
    }
    for (final file in await _entryFiles()) {
      await _readEntry(file);
    }
  }

  Future<List<File>> _entryFiles() async {
    if (!await _directory.exists()) {
      return const <File>[];
    }
    final files = <File>[];
    await for (final entity in _directory.list()) {
      if (entity is File && p.extension(entity.path) == '.json') {
        files.add(entity);
      }
    }
    return files;
  }

  File _fileFor(String namespacedKey) {
    return File(
      p.join(_directory.path, '${_encodeCacheKey(namespacedKey)}.json'),
    );
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

const Set<MiniProgramCacheBucket> _defaultPersistentBuckets =
    <MiniProgramCacheBucket>{
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.state,
    };

const int _schemaVersion = 1;

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

String _encodeCacheKey(String value) => base64Url.encode(utf8.encode(value));
