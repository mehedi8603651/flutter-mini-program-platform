import '../runtime_cache.dart';

const int runtimeCachePersistenceSchemaVersion = 1;

Map<String, Object?> encodeRuntimeCacheEntry(MiniProgramCacheEntry entry) {
  return <String, Object?>{
    'schemaVersion': runtimeCachePersistenceSchemaVersion,
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

MiniProgramCacheEntry? decodeRuntimeCacheEntry(Map<String, Object?> json) {
  if (json['schemaVersion'] != runtimeCachePersistenceSchemaVersion) {
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
