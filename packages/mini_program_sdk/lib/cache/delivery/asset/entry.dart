import 'package:flutter/foundation.dart';

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
