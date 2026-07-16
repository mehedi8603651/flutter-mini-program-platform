import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage_key_codec.dart';
import 'entry.dart';
import 'store.dart';

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
      p.join(_directory.path, '${encodeDeliveryCacheKey(miniProgramId)}.json'),
    );
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
