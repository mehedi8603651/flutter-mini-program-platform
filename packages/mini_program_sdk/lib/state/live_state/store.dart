part of '../mp_state.dart';

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
    _applySingleStoreChange(this, normalizedKey, () {
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
    _applySingleStoreChange(this, normalizedKey, () {
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
    _batchStoreUpdates(this, updates);
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

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MpStore has been disposed.');
    }
  }
}
