part of '../mp_state.dart';

Map<String, _StateBranchMetrics> _calculateBranchMetrics(
  Map<String, dynamic> values,
) {
  return <String, _StateBranchMetrics>{
    for (final entry in values.entries)
      entry.key: _measureBranch(entry.key, entry.value),
  };
}

_StateBranchMetrics _measureBranch(String key, Object? value) {
  final encodedKeyBytes = utf8.encode(jsonEncode(key)).length;
  final encodedValueBytes = utf8.encode(jsonEncode(value)).length;
  return _StateBranchMetrics(
    pairBytes: encodedKeyBytes + 1 + encodedValueBytes,
    valueBytes: encodedValueBytes,
    entries: 1 + _nestedStateEntries(value),
    depth: _stateValueDepth(value, 1),
  );
}

int _nestedStateEntries(Object? value) {
  if (value is List) {
    return value.fold<int>(
      0,
      (total, item) => total + 1 + _nestedStateEntries(item),
    );
  }
  if (value is Map) {
    return value.values.fold<int>(
      0,
      (total, item) => total + 1 + _nestedStateEntries(item),
    );
  }
  return 0;
}

int _stateValueDepth(Object? value, int currentDepth) {
  if (value is List) {
    if (value.isEmpty) {
      return currentDepth;
    }
    return value
        .map((item) => _stateValueDepth(item, currentDepth + 1))
        .reduce((left, right) => left > right ? left : right);
  }
  if (value is Map) {
    if (value.isEmpty) {
      return currentDepth;
    }
    return value.values
        .map((item) => _stateValueDepth(item, currentDepth + 1))
        .reduce((left, right) => left > right ? left : right);
  }
  return currentDepth;
}

void _validateMetrics(
  Map<String, _StateBranchMetrics> metrics,
  MiniProgramLiveStatePolicy policy,
) {
  final totalBytes = metrics.isEmpty
      ? 2
      : 2 +
            metrics.values.fold<int>(
              0,
              (total, branch) => total + branch.pairBytes,
            ) +
            metrics.length -
            1;
  if (totalBytes > policy.maxBytes) {
    throw MiniProgramStateLimitException(
      metric: 'maxBytes',
      limit: policy.maxBytes,
      actual: totalBytes,
    );
  }
  final entries = metrics.values.fold<int>(
    0,
    (total, branch) => total + branch.entries,
  );
  if (entries > policy.maxEntries) {
    throw MiniProgramStateLimitException(
      metric: 'maxEntries',
      limit: policy.maxEntries,
      actual: entries,
    );
  }
  for (final branch in metrics.values) {
    if (branch.valueBytes > policy.maxValueBytes) {
      throw MiniProgramStateLimitException(
        metric: 'maxValueBytes',
        limit: policy.maxValueBytes,
        actual: branch.valueBytes,
      );
    }
  }
  final depth = metrics.values.fold<int>(
    0,
    (current, branch) => branch.depth > current ? branch.depth : current,
  );
  if (depth > policy.maxDepth) {
    throw MiniProgramStateLimitException(
      metric: 'maxDepth',
      limit: policy.maxDepth,
      actual: depth,
    );
  }
}
