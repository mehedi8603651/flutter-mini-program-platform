import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../storage_key_codec.dart';
import 'entry.dart';
import 'keys.dart';
import 'store.dart';

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
    return File(
      p.join(_directory.path, '${encodeDeliveryCacheKey(cacheKey)}.json'),
    );
  }

  Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
