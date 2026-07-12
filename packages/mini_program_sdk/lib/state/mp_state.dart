import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

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

/// In-memory state store for one active mini-program host instance.
///
/// Values are intentionally memory-only. Persistent data belongs in a future
/// storage layer, while private data should remain behind publisher APIs.
class MpStore {
  MpStore({
    MiniProgramLiveStatePolicy policy = const MiniProgramLiveStatePolicy(),
  }) : _policy = policy;

  final Map<String, dynamic> _values = <String, dynamic>{};
  final Map<String, ValueNotifier<Object?>> _watchers =
      <String, ValueNotifier<Object?>>{};
  final Map<String, _StateBranchMetrics> _branchMetrics =
      <String, _StateBranchMetrics>{};
  final Set<String> _pendingChangedPaths = <String>{};
  MiniProgramLiveStatePolicy _policy;
  int _batchDepth = 0;
  bool _disposed = false;

  MiniProgramLiveStatePolicy get policy => _policy;

  void updatePolicy(MiniProgramLiveStatePolicy policy) {
    _ensureActive();
    if (_batchDepth > 0) {
      throw StateError('Cannot update live-state policy during a batch.');
    }
    _validateMetrics(_branchMetrics, policy);
    _policy = policy;
  }

  /// Creates or replaces [key] with [value].
  void put(String key, Object? value) => set(key, value);

  /// Reads [key] and casts it to [T] when possible.
  T? get<T>(String key) {
    _ensureActive();
    final value = _readStatePath(_values, validateStateKey(key));
    final cloned = _cloneStateValue(value);
    return cloned is T ? cloned : null;
  }

  /// Replaces [key] with [value].
  void set(String key, Object? value) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    final normalizedValue = _normalizeStateValue(value);
    if (_batchDepth > 0) {
      _writeStatePath(_values, normalizedKey, normalizedValue);
      _pendingChangedPaths.add(normalizedKey);
      return;
    }
    _applySingleChange(normalizedKey, () {
      _writeStatePath(_values, normalizedKey, normalizedValue);
    });
  }

  /// Whether [key] currently exists, including values explicitly set to null.
  bool contains(String key) {
    _ensureActive();
    return _containsStatePath(_values, validateStateKey(key));
  }

  /// Removes [key] if present.
  void remove(String key) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    if (!_containsStatePath(_values, normalizedKey)) {
      return;
    }
    if (_batchDepth > 0) {
      _removeStatePath(_values, normalizedKey);
      _pendingChangedPaths.add(normalizedKey);
      return;
    }
    _applySingleChange(normalizedKey, () {
      _removeStatePath(_values, normalizedKey);
    });
  }

  /// Clears all state values for the current mini-program instance.
  void clear() {
    _ensureActive();
    if (_values.isEmpty) {
      return;
    }
    final changedPaths = _values.keys.toList(growable: false);
    _values.clear();
    if (_batchDepth > 0) {
      _pendingChangedPaths.addAll(changedPaths);
      return;
    }
    _branchMetrics.clear();
    for (final watcher in _watchers.values) {
      watcher.value = null;
    }
  }

  /// Applies synchronous updates atomically and coalesces watcher changes.
  void batchUpdates(void Function() updates) {
    _ensureActive();
    final checkpoint = _BatchCheckpoint(
      values: _cloneStateMap(_values),
      metrics: Map<String, _StateBranchMetrics>.from(_branchMetrics),
      pendingPaths: Set<String>.from(_pendingChangedPaths),
    );
    _batchDepth += 1;
    var depthDecremented = false;
    try {
      updates();
      _batchDepth -= 1;
      depthDecremented = true;
      if (_batchDepth > 0) {
        return;
      }
      final changedPaths = Set<String>.from(_pendingChangedPaths);
      final metrics = _calculateBranchMetrics(_values);
      _validateMetrics(metrics, _policy);
      _branchMetrics
        ..clear()
        ..addAll(metrics);
      _pendingChangedPaths.clear();
      _notifyChangedPaths(changedPaths);
    } catch (_) {
      if (!depthDecremented) {
        _batchDepth -= 1;
      }
      _restoreCheckpoint(checkpoint);
      rethrow;
    }
  }

  /// Watches [key]. The returned listenable only updates for related paths.
  ValueListenable<Object?> watch(String key) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    return _watchers.putIfAbsent(
      normalizedKey,
      () => ValueNotifier<Object?>(
        _cloneStateValue(_readStatePath(_values, normalizedKey)),
      ),
    );
  }

  /// Returns a defensive copy of the state namespace for binding resolution.
  Map<String, dynamic> toBindingData() {
    _ensureActive();
    return Map<String, dynamic>.from(_cloneStateValue(_values) as Map);
  }

  /// Releases watcher resources.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final watcher in _watchers.values) {
      watcher.dispose();
    }
    _watchers.clear();
    _values.clear();
    _branchMetrics.clear();
    _pendingChangedPaths.clear();
  }

  void _applySingleChange(String changedKey, void Function() update) {
    final topLevelKey = changedKey.split('.').first;
    final hadBranch = _values.containsKey(topLevelKey);
    final previousBranch = hadBranch
        ? _cloneStateValue(_values[topLevelKey])
        : null;
    final previousMetrics = _branchMetrics[topLevelKey];
    try {
      update();
      final nextMetrics = Map<String, _StateBranchMetrics>.from(_branchMetrics);
      if (_values.containsKey(topLevelKey)) {
        nextMetrics[topLevelKey] = _measureBranch(
          topLevelKey,
          _values[topLevelKey],
        );
      } else {
        nextMetrics.remove(topLevelKey);
      }
      _validateMetrics(nextMetrics, _policy);
      _branchMetrics
        ..clear()
        ..addAll(nextMetrics);
    } catch (_) {
      if (hadBranch) {
        _values[topLevelKey] = previousBranch;
      } else {
        _values.remove(topLevelKey);
      }
      if (previousMetrics == null) {
        _branchMetrics.remove(topLevelKey);
      } else {
        _branchMetrics[topLevelKey] = previousMetrics;
      }
      rethrow;
    }
    _notifyRelated(changedKey);
  }

  void _notifyChangedPaths(Set<String> changedPaths) {
    if (changedPaths.isEmpty) {
      return;
    }
    for (final entry in _watchers.entries) {
      if (changedPaths.any((changed) => _pathsRelated(entry.key, changed))) {
        entry.value.value = _cloneStateValue(
          _readStatePath(_values, entry.key),
        );
      }
    }
  }

  void _restoreCheckpoint(_BatchCheckpoint checkpoint) {
    _values
      ..clear()
      ..addAll(_cloneStateMap(checkpoint.values));
    _branchMetrics
      ..clear()
      ..addAll(checkpoint.metrics);
    _pendingChangedPaths
      ..clear()
      ..addAll(checkpoint.pendingPaths);
  }

  void _notifyRelated(String changedKey) {
    for (final entry in _watchers.entries) {
      if (_pathsRelated(entry.key, changedKey)) {
        entry.value.value = _cloneStateValue(
          _readStatePath(_values, entry.key),
        );
      }
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MpStore has been disposed.');
    }
  }
}

/// Typed facade around [MpStore] owned by a mini-program host instance.
class MpStateManager {
  /// Creates a state manager backed by [store] or a new [MpStore].
  MpStateManager({
    MpStore? store,
    MiniProgramLiveStatePolicy policy = const MiniProgramLiveStatePolicy(),
  }) : store = store ?? MpStore(policy: policy);

  /// Backing store for advanced host-side inspection and tests.
  final MpStore store;

  MiniProgramLiveStatePolicy get policy => store.policy;

  void updatePolicy(MiniProgramLiveStatePolicy policy) =>
      store.updatePolicy(policy);

  /// Creates or replaces [key] with [value].
  void put(String key, Object? value) => store.put(key, value);

  /// Reads [key] and casts it to [T] when possible.
  T? get<T>(String key) => store.get<T>(key);

  /// Whether [key] currently exists, including null values.
  bool contains(String key) => store.contains(key);

  /// Replaces [key] with [value].
  void set(String key, Object? value) => store.set(key, value);

  /// Removes [key] if present.
  void remove(String key) => store.remove(key);

  /// Clears all memory state for this mini-program instance.
  void clear() => store.clear();

  /// Applies synchronous state writes atomically with one watcher update.
  void batchUpdates(void Function() updates) => store.batchUpdates(updates);

  /// Watches [key] for related changes.
  ValueListenable<Object?> watch(String key) => store.watch(key);

  /// Binding data exposed under `{{state.*}}`.
  Map<String, dynamic> toBindingData() => store.toBindingData();

  /// Releases state resources.
  void dispose() => store.dispose();
}

typedef MpRouterScreenHandler =
    Future<HostActionResult> Function(
      String screenId,
      Map<String, dynamic> params,
      String? requestId,
    );

typedef MpRouterResultHandler =
    Future<HostActionResult> Function(
      Map<String, dynamic> result,
      String? requestId,
    );

typedef MpRouterPopToScreenHandler =
    Future<HostActionResult> Function(
      String screenId,
      Map<String, dynamic> result,
      String? requestId,
    );

/// Lightweight router facade used by Mp JSON actions.
class MpRouter {
  /// Creates a router facade over the active mini-program stack.
  const MpRouter({
    required this.push,
    required this.replace,
    required this.reset,
    required this.pop,
    required this.popToRoot,
    required this.popToScreen,
  });

  /// Pushes [screenId] and exposes [params] under `{{route.*}}`.
  final MpRouterScreenHandler push;

  /// Replaces the current screen with [screenId].
  final MpRouterScreenHandler replace;

  /// Resets the stack to [screenId].
  final MpRouterScreenHandler reset;

  /// Pops the current screen and returns [result] to the revealed screen.
  final MpRouterResultHandler pop;

  /// Pops to the root screen and returns [result].
  final MpRouterResultHandler popToRoot;

  /// Pops to [screenId] and returns [result].
  final MpRouterPopToScreenHandler popToScreen;
}

final RegExp _stateKeyPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);

const Set<String> _blockedStateSegments = <String>{
  'authorization',
  'credential',
  'idtoken',
  'password',
  'refreshtoken',
  'secret',
  'token',
};

/// Validates and normalizes an Mp state key.
String validateStateKey(String key) {
  final normalized = key.trim();
  if (!_stateKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      key,
      'key',
      'Mp state keys must be lowercase dot paths.',
    );
  }
  for (final segment in normalized.split('.')) {
    final compact = segment.replaceAll('_', '').toLowerCase();
    if (_blockedStateSegments.contains(compact)) {
      throw ArgumentError.value(
        key,
        'key',
        'Mp state keys cannot contain secret-like segments.',
      );
    }
  }
  return normalized;
}

Object? _readStatePath(Map<String, dynamic> source, String path) {
  Object? current = source;
  for (final segment in path.split('.')) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
    if (current == null) {
      return null;
    }
  }
  return current;
}

bool _containsStatePath(Map<String, dynamic> source, String path) {
  Object? current = source;
  final segments = path.split('.');
  for (var index = 0; index < segments.length; index += 1) {
    if (current is! Map || !current.containsKey(segments[index])) {
      return false;
    }
    current = current[segments[index]];
  }
  return true;
}

void _writeStatePath(Map<String, dynamic> source, String path, Object? value) {
  final segments = path.split('.');
  var current = source;
  for (var index = 0; index < segments.length - 1; index += 1) {
    final segment = segments[index];
    final existing = current[segment];
    if (existing is Map<String, dynamic>) {
      current = existing;
    } else if (existing is Map) {
      final normalized = Map<String, dynamic>.from(existing);
      current[segment] = normalized;
      current = normalized;
    } else {
      final nested = <String, dynamic>{};
      current[segment] = nested;
      current = nested;
    }
  }
  current[segments.last] = value;
}

void _removeStatePath(Map<String, dynamic> source, String path) {
  final segments = path.split('.');
  var current = source;
  for (var index = 0; index < segments.length - 1; index += 1) {
    final next = current[segments[index]];
    if (next is Map<String, dynamic>) {
      current = next;
    } else if (next is Map) {
      current = Map<String, dynamic>.from(next);
    } else {
      return;
    }
  }
  current.remove(segments.last);
}

Object? _normalizeStateValue(Object? value) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'value',
        'Mp state numbers must be finite.',
      );
    }
    return value;
  }
  if (value is List) {
    return value.map(_normalizeStateValue).toList(growable: false);
  }
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'key',
          'Mp state map keys must be non-empty strings.',
        );
      }
      normalized[key] = _normalizeStateValue(entry.value);
    }
    return normalized;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported Mp state value.');
}

Object? _cloneStateValue(Object? value) {
  if (value is List) {
    return value.map(_cloneStateValue).toList(growable: false);
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _cloneStateValue(entry.value),
    };
  }
  return value;
}

bool _pathsRelated(String watched, String changed) {
  return watched == changed ||
      watched.startsWith('$changed.') ||
      changed.startsWith('$watched.');
}

Map<String, dynamic> _cloneStateMap(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(_cloneStateValue(value) as Map);
}

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
