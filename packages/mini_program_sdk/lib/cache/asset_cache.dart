import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
class CachedAssetEntry {
  const CachedAssetEntry({
    required this.sourceUri,
    required this.filePath,
    required this.cachedAt,
    this.contentType,
  });

  factory CachedAssetEntry.fromJson(Map<String, dynamic> json) {
    return CachedAssetEntry(
      sourceUri: json['sourceUri'] as String,
      filePath: json['filePath'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      contentType: json['contentType'] as String?,
    );
  }

  final String sourceUri;
  final String filePath;
  final DateTime cachedAt;
  final String? contentType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceUri': sourceUri,
      'filePath': filePath,
      'cachedAt': cachedAt.toIso8601String(),
      'contentType': contentType,
    };
  }
}

abstract interface class AssetCache {
  Future<CachedAssetEntry?> read(String sourceUri);

  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  });

  Future<void> remove(String sourceUri);

  Future<void> clear();
}

class NoOpAssetCache implements AssetCache {
  const NoOpAssetCache();

  static const NoOpAssetCache shared = NoOpAssetCache();

  @override
  Future<CachedAssetEntry?> read(String sourceUri) async => null;

  @override
  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  }) async {
    return null;
  }

  @override
  Future<void> remove(String sourceUri) async {}

  @override
  Future<void> clear() async {}
}

class FileAssetCache implements AssetCache {
  FileAssetCache({required Directory directory}) : _directory = directory;

  final Directory _directory;
  final Map<String, CachedAssetEntry> _entries = <String, CachedAssetEntry>{};
  final Set<String> _loadedKeys = <String>{};

  @override
  Future<CachedAssetEntry?> read(String sourceUri) async {
    if (_loadedKeys.contains(sourceUri)) {
      return _entries[sourceUri];
    }

    _loadedKeys.add(sourceUri);
    final metadataFile = _metadataFileFor(sourceUri);
    if (!await metadataFile.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map) {
        await _deleteEntryFiles(sourceUri);
        return null;
      }

      final entry = CachedAssetEntry.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (!await File(entry.filePath).exists()) {
        await _deleteEntryFiles(sourceUri);
        return null;
      }

      _entries[sourceUri] = entry;
      return entry;
    } catch (_) {
      await _deleteEntryFiles(sourceUri);
      return null;
    }
  }

  @override
  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  }) async {
    await _directory.create(recursive: true);

    final extension = _resolveFileExtension(
      sourceUri: sourceUri,
      contentType: contentType,
      suggestedFileExtension: suggestedFileExtension,
    );
    final assetFile = _assetFileFor(sourceUri, extension: extension);
    await assetFile.writeAsBytes(bytes, flush: true);

    final entry = CachedAssetEntry(
      sourceUri: sourceUri,
      filePath: assetFile.path,
      cachedAt: cachedAt,
      contentType: contentType,
    );
    await _metadataFileFor(
      sourceUri,
    ).writeAsString(jsonEncode(entry.toJson()), flush: true);
    _entries[sourceUri] = entry;
    _loadedKeys.add(sourceUri);
    return entry;
  }

  @override
  Future<void> remove(String sourceUri) async {
    _entries.remove(sourceUri);
    _loadedKeys.add(sourceUri);
    await _deleteEntryFiles(sourceUri);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _loadedKeys.clear();
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }

  File _metadataFileFor(String sourceUri) {
    return File(
      p.join(_directory.path, '${_encodeCacheKey(sourceUri)}.asset.json'),
    );
  }

  File _assetFileFor(String sourceUri, {required String extension}) {
    return File(
      p.join(_directory.path, '${_encodeCacheKey(sourceUri)}$extension'),
    );
  }

  Future<void> _deleteEntryFiles(String sourceUri) async {
    final metadataFile = _metadataFileFor(sourceUri);
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }

    final pattern = _encodeCacheKey(sourceUri);
    if (await _directory.exists()) {
      await for (final entity in _directory.list()) {
        if (entity is File && p.basename(entity.path).startsWith(pattern)) {
          await entity.delete();
        }
      }
    }
  }

  String _resolveFileExtension({
    required String sourceUri,
    String? contentType,
    String? suggestedFileExtension,
  }) {
    final sanitizedSuggested = _sanitizeExtension(suggestedFileExtension);
    if (sanitizedSuggested != null) {
      return sanitizedSuggested;
    }

    final sourceExtension = _sanitizeExtension(
      p.extension(Uri.parse(sourceUri).path),
    );
    if (sourceExtension != null) {
      return sourceExtension;
    }

    final normalizedContentType = contentType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    switch (normalizedContentType) {
      case 'image/png':
        return '.png';
      case 'image/jpeg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      case 'image/svg+xml':
        return '.svg';
      case 'image/gif':
        return '.gif';
      default:
        return '.bin';
    }
  }

  String? _sanitizeExtension(String? extension) {
    if (extension == null || extension.trim().isEmpty) {
      return null;
    }

    if (extension.startsWith('.')) {
      return extension;
    }

    return '.${extension.trim()}';
  }
}

String _encodeCacheKey(String value) => base64Url.encode(utf8.encode(value));
