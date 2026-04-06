import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

@immutable
class CachedManifestEntry {
  const CachedManifestEntry({
    required this.miniProgramId,
    required this.manifest,
    required this.cachedAt,
  });

  factory CachedManifestEntry.fromJson(Map<String, dynamic> json) {
    return CachedManifestEntry(
      miniProgramId: json['miniProgramId'] as String,
      manifest: MiniProgramManifest.fromJson(
        Map<String, dynamic>.from(json['manifest'] as Map),
      ),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  final String miniProgramId;
  final MiniProgramManifest manifest;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'miniProgramId': miniProgramId,
      'manifest': manifest.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
}

abstract interface class ManifestCache {
  Future<CachedManifestEntry?> read(String miniProgramId);

  Future<void> write(CachedManifestEntry entry);

  Future<void> remove(String miniProgramId);

  Future<void> clear();
}

class InMemoryManifestCache implements ManifestCache {
  InMemoryManifestCache();

  static final InMemoryManifestCache shared = InMemoryManifestCache();

  final Map<String, CachedManifestEntry> _entries =
      <String, CachedManifestEntry>{};

  @override
  Future<CachedManifestEntry?> read(String miniProgramId) async {
    return _entries[miniProgramId];
  }

  @override
  Future<void> write(CachedManifestEntry entry) async {
    _entries[entry.miniProgramId] = entry;
  }

  @override
  Future<void> remove(String miniProgramId) async {
    _entries.remove(miniProgramId);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

class FileManifestCache implements ManifestCache {
  FileManifestCache({required Directory directory}) : _directory = directory;

  final Directory _directory;
  final Map<String, CachedManifestEntry> _entries =
      <String, CachedManifestEntry>{};
  final Set<String> _loadedKeys = <String>{};

  @override
  Future<CachedManifestEntry?> read(String miniProgramId) async {
    if (_loadedKeys.contains(miniProgramId)) {
      return _entries[miniProgramId];
    }

    _loadedKeys.add(miniProgramId);
    final file = _fileFor(miniProgramId);
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        await _safeDelete(file);
        return null;
      }

      final entry = CachedManifestEntry.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      _entries[miniProgramId] = entry;
      return entry;
    } catch (_) {
      await _safeDelete(file);
      return null;
    }
  }

  @override
  Future<void> write(CachedManifestEntry entry) async {
    _entries[entry.miniProgramId] = entry;
    _loadedKeys.add(entry.miniProgramId);

    await _directory.create(recursive: true);
    await _fileFor(
      entry.miniProgramId,
    ).writeAsString(jsonEncode(entry.toJson()), flush: true);
  }

  @override
  Future<void> remove(String miniProgramId) async {
    _entries.remove(miniProgramId);
    _loadedKeys.add(miniProgramId);
    await _safeDelete(_fileFor(miniProgramId));
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _loadedKeys.clear();
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  File _fileFor(String miniProgramId) {
    return File(
      p.join(_directory.path, '${_encodeCacheKey(miniProgramId)}.json'),
    );
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

String _encodeCacheKey(String value) => base64Url.encode(utf8.encode(value));
