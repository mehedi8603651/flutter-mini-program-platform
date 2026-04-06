import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
class CachedScreenEntry {
  const CachedScreenEntry({
    required this.miniProgramId,
    required this.version,
    required this.screenId,
    required this.screenJson,
    required this.cachedAt,
  });

  factory CachedScreenEntry.fromJson(Map<String, dynamic> json) {
    return CachedScreenEntry(
      miniProgramId: json['miniProgramId'] as String,
      version: json['version'] as String,
      screenId: json['screenId'] as String,
      screenJson: Map<String, dynamic>.from(json['screenJson'] as Map),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  final String miniProgramId;
  final String version;
  final String screenId;
  final Map<String, dynamic> screenJson;
  final DateTime cachedAt;

  String get cacheKey => buildScreenCacheKey(
    miniProgramId: miniProgramId,
    version: version,
    screenId: screenId,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'miniProgramId': miniProgramId,
      'version': version,
      'screenId': screenId,
      'screenJson': screenJson,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
}

abstract interface class ScreenCache {
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  Future<void> write(CachedScreenEntry entry);

  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  Future<void> clear();
}

class InMemoryScreenCache implements ScreenCache {
  InMemoryScreenCache();

  static final InMemoryScreenCache shared = InMemoryScreenCache();

  final Map<String, CachedScreenEntry> _entries = <String, CachedScreenEntry>{};

  @override
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _entries[buildScreenCacheKey(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    )];
  }

  @override
  Future<void> write(CachedScreenEntry entry) async {
    _entries[entry.cacheKey] = entry;
  }

  @override
  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    _entries.remove(
      buildScreenCacheKey(
        miniProgramId: miniProgramId,
        version: version,
        screenId: screenId,
      ),
    );
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

class FileScreenCache implements ScreenCache {
  FileScreenCache({required Directory directory}) : _directory = directory;

  final Directory _directory;
  final Map<String, CachedScreenEntry> _entries = <String, CachedScreenEntry>{};
  final Set<String> _loadedKeys = <String>{};

  @override
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    final cacheKey = buildScreenCacheKey(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    );
    if (_loadedKeys.contains(cacheKey)) {
      return _entries[cacheKey];
    }

    _loadedKeys.add(cacheKey);
    final file = _fileFor(cacheKey);
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        await _safeDelete(file);
        return null;
      }

      final entry = CachedScreenEntry.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      _entries[cacheKey] = entry;
      return entry;
    } catch (_) {
      await _safeDelete(file);
      return null;
    }
  }

  @override
  Future<void> write(CachedScreenEntry entry) async {
    _entries[entry.cacheKey] = entry;
    _loadedKeys.add(entry.cacheKey);

    await _directory.create(recursive: true);
    await _fileFor(
      entry.cacheKey,
    ).writeAsString(jsonEncode(entry.toJson()), flush: true);
  }

  @override
  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    final cacheKey = buildScreenCacheKey(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    );
    _entries.remove(cacheKey);
    _loadedKeys.add(cacheKey);
    await _safeDelete(_fileFor(cacheKey));
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _loadedKeys.clear();
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  File _fileFor(String cacheKey) {
    return File(p.join(_directory.path, '${_encodeCacheKey(cacheKey)}.json'));
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

String buildScreenCacheKey({
  required String miniProgramId,
  required String version,
  required String screenId,
}) => '$miniProgramId::$version::$screenId';

String _encodeCacheKey(String value) => base64Url.encode(utf8.encode(value));
