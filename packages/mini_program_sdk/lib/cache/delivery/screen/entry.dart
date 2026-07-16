import 'package:flutter/foundation.dart';

import 'keys.dart';

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
