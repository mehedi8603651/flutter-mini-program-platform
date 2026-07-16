part of '../mp_state.dart';

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

bool _pathsRelated(String watched, String changed) {
  return watched == changed ||
      watched.startsWith('$changed.') ||
      changed.startsWith('$watched.');
}
