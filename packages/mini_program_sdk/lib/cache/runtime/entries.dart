part of '../runtime_cache.dart';

@immutable
class MiniProgramCacheEntry {
  const MiniProgramCacheEntry({
    required this.appId,
    required this.bucket,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessedAt,
    required this.expiresAt,
    required this.sizeBytes,
    required this.priority,
  });

  final String appId;
  final MiniProgramCacheBucket bucket;
  final String key;
  final Object? value;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final DateTime expiresAt;
  final int sizeBytes;
  final MiniProgramCachePriority priority;

  String get namespacedKey => MiniProgramCacheManager.namespacedKey(
    appId: appId,
    bucket: bucket,
    key: key,
  );

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  MiniProgramCacheEntry copyWith({
    Object? value = _unset,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
    int? sizeBytes,
    MiniProgramCachePriority? priority,
  }) {
    return MiniProgramCacheEntry(
      appId: appId,
      bucket: bucket,
      key: key,
      value: identical(value, _unset) ? this.value : value,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      priority: priority ?? this.priority,
    );
  }
}

@immutable
class MiniProgramCacheMetadata {
  const MiniProgramCacheMetadata({
    required this.appId,
    required this.firstOpenedAt,
    required this.lastOpenedAt,
    required this.lastAccessedAt,
    required this.totalBytes,
    required this.dataBytes,
    required this.imageBytes,
    required this.videoBytes,
    required this.sessionBytes,
    required this.stateBytes,
  });

  final String appId;
  final DateTime firstOpenedAt;
  final DateTime lastOpenedAt;
  final DateTime lastAccessedAt;
  final int totalBytes;
  final int dataBytes;
  final int imageBytes;
  final int videoBytes;
  final int sessionBytes;
  final int stateBytes;

  MiniProgramCacheMetadata copyWith({
    DateTime? firstOpenedAt,
    DateTime? lastOpenedAt,
    DateTime? lastAccessedAt,
    int? totalBytes,
    int? dataBytes,
    int? imageBytes,
    int? videoBytes,
    int? sessionBytes,
    int? stateBytes,
  }) {
    return MiniProgramCacheMetadata(
      appId: appId,
      firstOpenedAt: firstOpenedAt ?? this.firstOpenedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      totalBytes: totalBytes ?? this.totalBytes,
      dataBytes: dataBytes ?? this.dataBytes,
      imageBytes: imageBytes ?? this.imageBytes,
      videoBytes: videoBytes ?? this.videoBytes,
      sessionBytes: sessionBytes ?? this.sessionBytes,
      stateBytes: stateBytes ?? this.stateBytes,
    );
  }
}

const Object _unset = Object();
