part of '../mp_state.dart';

/// Host-owned memory limits for one active mini-program state namespace.
@immutable
class MiniProgramLiveStatePolicy {
  const MiniProgramLiveStatePolicy({
    this.maxBytes = 2 * 1024 * 1024,
    this.maxEntries = 1000,
    this.maxValueBytes = 256 * 1024,
    this.maxDepth = 32,
  }) : assert(maxBytes > 0),
       assert(maxEntries > 0),
       assert(maxValueBytes > 0),
       assert(maxValueBytes <= maxBytes),
       assert(maxDepth > 0);

  final int maxBytes;
  final int maxEntries;
  final int maxValueBytes;
  final int maxDepth;
}

/// Supplies per-mini-program live-state policy to the runtime host.
abstract interface class MiniProgramLiveStatePolicyProvider {
  MiniProgramLiveStatePolicy liveStatePolicyFor(String miniProgramId);
}

/// Raised when a live-state write would exceed host-owned limits.
class MiniProgramStateLimitException implements Exception {
  const MiniProgramStateLimitException({
    required this.metric,
    required this.limit,
    required this.actual,
  });

  final String metric;
  final int limit;
  final int actual;

  Map<String, dynamic> get details => <String, dynamic>{
    'metric': metric,
    'limit': limit,
    'actual': actual,
  };

  @override
  String toString() =>
      'Mini-program live state exceeds $metric limit ($actual > $limit).';
}
