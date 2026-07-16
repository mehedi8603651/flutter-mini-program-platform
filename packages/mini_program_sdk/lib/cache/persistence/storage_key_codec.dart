import 'dart:convert';

String encodeRuntimeCacheStorageKey(String value) {
  return base64Url.encode(utf8.encode(value));
}

String normalizeRuntimeCacheKeyPrefix(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.contains('/') ||
      normalized.contains('\\')) {
    throw ArgumentError.value(
      value,
      'keyPrefix',
      'Shared preferences cache keyPrefix must be a non-empty key namespace.',
    );
  }
  return normalized;
}
