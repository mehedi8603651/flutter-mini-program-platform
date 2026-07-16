part of '../mp_state.dart';

@immutable
class _StateBranchMetrics {
  const _StateBranchMetrics({
    required this.pairBytes,
    required this.valueBytes,
    required this.entries,
    required this.depth,
  });

  final int pairBytes;
  final int valueBytes;
  final int entries;
  final int depth;
}

class _BatchCheckpoint {
  const _BatchCheckpoint({
    required this.values,
    required this.metrics,
    required this.pendingPaths,
  });

  final Map<String, dynamic> values;
  final Map<String, _StateBranchMetrics> metrics;
  final Set<String> pendingPaths;
}
