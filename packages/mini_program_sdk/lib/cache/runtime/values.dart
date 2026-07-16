part of '../runtime_cache.dart';

String _normalizeAppId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'appId', 'appId must not be blank.');
  }
  if (_unsafeKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'appId',
      'appId cannot contain path traversal or separators.',
    );
  }
  return normalized;
}

String _normalizeKey(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'key', 'Cache key must not be blank.');
  }
  if (_unsafeKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'key',
      'Cache key cannot contain path traversal or separators.',
    );
  }
  return normalized;
}

final RegExp _unsafeKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/]');

Object? _normalizeCacheValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_normalizeCacheValue).toList(growable: false);
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'key',
          'Cache map keys must be non-empty strings.',
        );
      }
      normalized[key] = _normalizeCacheValue(entry.value);
    }
    return normalized;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported cache value.');
}

int _encodedSize(Object? value) => utf8.encode(jsonEncode(value)).length;
