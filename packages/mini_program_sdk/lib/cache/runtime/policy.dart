part of '../runtime_cache.dart';

abstract interface class MiniProgramCachePolicyProvider {
  MiniProgramCachePolicy cachePolicyFor(String miniProgramId);
}

const Set<MiniProgramCacheBucket> _defaultMiniProgramCacheBuckets =
    <MiniProgramCacheBucket>{
      MiniProgramCacheBucket.memory,
      MiniProgramCacheBucket.data,
      MiniProgramCacheBucket.image,
      MiniProgramCacheBucket.state,
    };

@immutable
class MiniProgramCachePolicy {
  const MiniProgramCachePolicy({
    this.enabled = true,
    this.memoryTtl = const Duration(hours: 2),
    this.dataTtl = const Duration(days: 30),
    this.imageTtl = const Duration(days: 14),
    this.videoTtl = const Duration(hours: 6),
    this.stateInactiveTtl = const Duration(days: 60),
    this.sessionInactiveTtl = const Duration(days: 60),
    this.maxBytes = 20 * 1024 * 1024,
    this.maxDataBytes = 10 * 1024 * 1024,
    this.maxImageBytes = 20 * 1024 * 1024,
    this.maxVideoBytes = 50 * 1024 * 1024,
    this.maxSessionBytes = 512 * 1024,
    this.maxStateBytes = 5 * 1024 * 1024,
    this.allowedMiniProgramCacheBuckets = _defaultMiniProgramCacheBuckets,
    this.clearMemoryOnExit = true,
    this.clearExpiredOnStartup = true,
    this.clearSessionOnLogout = true,
    this.clearStateOnInactiveExpiry = true,
    this.clearWhenOverLimit = true,
  });

  final bool enabled;
  final Duration memoryTtl;
  final Duration dataTtl;
  final Duration imageTtl;
  final Duration videoTtl;
  final Duration stateInactiveTtl;
  final Duration sessionInactiveTtl;
  final int maxBytes;
  final int maxDataBytes;
  final int maxImageBytes;
  final int maxVideoBytes;
  final int maxSessionBytes;
  final int maxStateBytes;
  final Set<MiniProgramCacheBucket> allowedMiniProgramCacheBuckets;
  final bool clearMemoryOnExit;
  final bool clearExpiredOnStartup;
  final bool clearSessionOnLogout;
  final bool clearStateOnInactiveExpiry;
  final bool clearWhenOverLimit;

  Duration ttlFor(MiniProgramCacheBucket bucket) {
    return switch (bucket) {
      MiniProgramCacheBucket.memory => memoryTtl,
      MiniProgramCacheBucket.data => dataTtl,
      MiniProgramCacheBucket.image => imageTtl,
      MiniProgramCacheBucket.video => videoTtl,
      MiniProgramCacheBucket.session => sessionInactiveTtl,
      MiniProgramCacheBucket.state => stateInactiveTtl,
    };
  }

  int? maxBytesFor(MiniProgramCacheBucket bucket) {
    return switch (bucket) {
      MiniProgramCacheBucket.data => maxDataBytes,
      MiniProgramCacheBucket.image => maxImageBytes,
      MiniProgramCacheBucket.video => maxVideoBytes,
      MiniProgramCacheBucket.session => maxSessionBytes,
      MiniProgramCacheBucket.state => maxStateBytes,
      _ => null,
    };
  }

  bool allowsMiniProgramBucket(MiniProgramCacheBucket bucket) {
    return allowedMiniProgramCacheBuckets.contains(bucket);
  }
}
