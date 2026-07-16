part of '../runtime_cache.dart';

@immutable
class MiniProgramCacheBucketUsage {
  const MiniProgramCacheBucketUsage({
    required this.bucket,
    required this.enabledForMiniProgram,
    required this.usedBytes,
    required this.miniProgramUsedBytes,
    required this.maxBytes,
    required this.remainingBytes,
    required this.ttl,
    required this.entryCount,
    required this.miniProgramEntryCount,
  });

  final MiniProgramCacheBucket bucket;
  final bool enabledForMiniProgram;
  final int usedBytes;
  final int miniProgramUsedBytes;
  final int? maxBytes;
  final int? remainingBytes;
  final Duration ttl;
  final int entryCount;
  final int miniProgramEntryCount;
}

@immutable
class MiniProgramCacheUsage {
  const MiniProgramCacheUsage({
    required this.appId,
    required this.enabled,
    required this.usedBytes,
    required this.maxBytes,
    required this.remainingBytes,
    required this.entryCount,
    required this.buckets,
  });

  final String appId;
  final bool enabled;
  final int usedBytes;
  final int maxBytes;
  final int remainingBytes;
  final int entryCount;
  final Map<MiniProgramCacheBucket, MiniProgramCacheBucketUsage> buckets;

  Map<String, dynamic> toMiniProgramJson() {
    const visibleBuckets = <MiniProgramCacheBucket>[
      MiniProgramCacheBucket.memory,
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.image,
      MiniProgramCacheBucket.state,
      MiniProgramCacheBucket.video,
    ];
    final visible = <String, dynamic>{};
    var visibleBytes = 0;
    var visibleEntries = 0;
    for (final bucket in visibleBuckets) {
      final usage = buckets[bucket]!;
      final bucketEnabled = enabled && usage.enabledForMiniProgram;
      if (bucketEnabled) {
        visibleBytes += usage.miniProgramUsedBytes;
        visibleEntries += usage.miniProgramEntryCount;
      }
      visible[bucket.name] = <String, dynamic>{
        'enabled': bucketEnabled,
        'usedBytes': bucketEnabled ? usage.miniProgramUsedBytes : 0,
        'maxBytes': bucketEnabled ? usage.maxBytes : null,
        'remainingBytes': bucketEnabled && usage.maxBytes != null
            ? (usage.maxBytes! - usage.miniProgramUsedBytes)
                  .clamp(0, usage.maxBytes!)
                  .toInt()
            : null,
        'ttlMs': bucketEnabled ? usage.ttl.inMilliseconds : null,
        'entryCount': bucketEnabled ? usage.miniProgramEntryCount : 0,
      };
    }
    return <String, dynamic>{
      'appId': appId,
      'enabled': enabled,
      'usedBytes': visibleBytes,
      'maxBytes': enabled ? maxBytes : 0,
      'remainingBytes': enabled
          ? (maxBytes - visibleBytes).clamp(0, maxBytes).toInt()
          : 0,
      'entryCount': visibleEntries,
      'buckets': visible,
    };
  }
}
