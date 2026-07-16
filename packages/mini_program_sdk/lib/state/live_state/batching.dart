part of '../mp_state.dart';

void _batchStoreUpdates(MpStore store, void Function() updates) {
  store._ensureActive();
  final checkpoint = _BatchCheckpoint(
    values: _cloneStateMap(store._values),
    metrics: Map<String, _StateBranchMetrics>.from(store._branchMetrics),
    pendingPaths: Set<String>.from(store._pendingChangedPaths),
  );
  store._batchDepth += 1;
  var depthDecremented = false;
  try {
    updates();
    store._batchDepth -= 1;
    depthDecremented = true;
    if (store._batchDepth > 0) {
      return;
    }
    final changedPaths = Set<String>.from(store._pendingChangedPaths);
    final metrics = _calculateBranchMetrics(store._values);
    _validateMetrics(metrics, store._policy);
    store._branchMetrics
      ..clear()
      ..addAll(metrics);
    store._pendingChangedPaths.clear();
    _notifyStoreChangedPaths(store, changedPaths);
  } catch (_) {
    if (!depthDecremented) {
      store._batchDepth -= 1;
    }
    _restoreStoreCheckpoint(store, checkpoint);
    rethrow;
  }
}

void _applySingleStoreChange(
  MpStore store,
  String changedKey,
  void Function() update,
) {
  final topLevelKey = changedKey.split('.').first;
  final hadBranch = store._values.containsKey(topLevelKey);
  final previousBranch = hadBranch
      ? _cloneStateValue(store._values[topLevelKey])
      : null;
  final previousMetrics = store._branchMetrics[topLevelKey];
  try {
    update();
    final nextMetrics = Map<String, _StateBranchMetrics>.from(
      store._branchMetrics,
    );
    if (store._values.containsKey(topLevelKey)) {
      nextMetrics[topLevelKey] = _measureBranch(
        topLevelKey,
        store._values[topLevelKey],
      );
    } else {
      nextMetrics.remove(topLevelKey);
    }
    _validateMetrics(nextMetrics, store._policy);
    store._branchMetrics
      ..clear()
      ..addAll(nextMetrics);
  } catch (_) {
    if (hadBranch) {
      store._values[topLevelKey] = previousBranch;
    } else {
      store._values.remove(topLevelKey);
    }
    if (previousMetrics == null) {
      store._branchMetrics.remove(topLevelKey);
    } else {
      store._branchMetrics[topLevelKey] = previousMetrics;
    }
    rethrow;
  }
  _notifyStoreRelated(store, changedKey);
}

void _notifyStoreChangedPaths(MpStore store, Set<String> changedPaths) {
  if (changedPaths.isEmpty) {
    return;
  }
  for (final entry in store._watchers.entries) {
    if (changedPaths.any((changed) => _pathsRelated(entry.key, changed))) {
      entry.value.value = _cloneStateValue(
        _readStatePath(store._values, entry.key),
      );
    }
  }
}

void _restoreStoreCheckpoint(MpStore store, _BatchCheckpoint checkpoint) {
  store._values
    ..clear()
    ..addAll(_cloneStateMap(checkpoint.values));
  store._branchMetrics
    ..clear()
    ..addAll(checkpoint.metrics);
  store._pendingChangedPaths
    ..clear()
    ..addAll(checkpoint.pendingPaths);
}

void _notifyStoreRelated(MpStore store, String changedKey) {
  for (final entry in store._watchers.entries) {
    if (_pathsRelated(entry.key, changedKey)) {
      entry.value.value = _cloneStateValue(
        _readStatePath(store._values, entry.key),
      );
    }
  }
}
