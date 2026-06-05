import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// In-memory state store for one active mini-program host instance.
///
/// Values are intentionally memory-only. Persistent data belongs in a future
/// storage layer, while private data should remain behind publisher APIs.
class MpStore {
  final Map<String, dynamic> _values = <String, dynamic>{};
  final Map<String, ValueNotifier<Object?>> _watchers =
      <String, ValueNotifier<Object?>>{};
  bool _disposed = false;

  /// Creates or replaces [key] with [value].
  void put(String key, Object? value) => set(key, value);

  /// Reads [key] and casts it to [T] when possible.
  T? get<T>(String key) {
    _ensureActive();
    final value = _readStatePath(_values, validateStateKey(key));
    return value is T ? value : null;
  }

  /// Replaces [key] with [value].
  void set(String key, Object? value) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    _writeStatePath(_values, normalizedKey, _normalizeStateValue(value));
    _notifyRelated(normalizedKey);
  }

  /// Removes [key] if present.
  void remove(String key) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    _removeStatePath(_values, normalizedKey);
    _notifyRelated(normalizedKey);
  }

  /// Clears all state values for the current mini-program instance.
  void clear() {
    _ensureActive();
    if (_values.isEmpty) {
      return;
    }
    _values.clear();
    for (final watcher in _watchers.values) {
      watcher.value = null;
    }
  }

  /// Watches [key]. The returned listenable only updates for related paths.
  ValueListenable<Object?> watch(String key) {
    _ensureActive();
    final normalizedKey = validateStateKey(key);
    return _watchers.putIfAbsent(
      normalizedKey,
      () => ValueNotifier<Object?>(_readStatePath(_values, normalizedKey)),
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
  }

  void _notifyRelated(String changedKey) {
    for (final entry in _watchers.entries) {
      if (_pathsRelated(entry.key, changedKey)) {
        entry.value.value = _readStatePath(_values, entry.key);
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
  MpStateManager({MpStore? store}) : store = store ?? MpStore();

  /// Backing store for advanced host-side inspection and tests.
  final MpStore store;

  /// Creates or replaces [key] with [value].
  void put(String key, Object? value) => store.put(key, value);

  /// Reads [key] and casts it to [T] when possible.
  T? get<T>(String key) => store.get<T>(key);

  /// Replaces [key] with [value].
  void set(String key, Object? value) => store.set(key, value);

  /// Removes [key] if present.
  void remove(String key) => store.remove(key);

  /// Clears all memory state for this mini-program instance.
  void clear() => store.clear();

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
  if (value == null || value is String || value is num || value is bool) {
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
