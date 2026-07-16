part of '../../../mp_screen_renderer.dart';

List<String> _parseStateKeys(Object? value, {required String path}) {
  if (value is! List || value.isEmpty) {
    _fail('Mp state keys must be a non-empty array.', path: path);
  }
  final keys = <String>[];
  for (var index = 0; index < value.length; index += 1) {
    final rawKey = value[index];
    if (rawKey is! String) {
      _fail('Mp state key must be a string.', path: '$path[$index]');
    }
    keys.add(_validateStateKey(rawKey, path: '$path[$index]'));
  }
  return List<String>.unmodifiable(keys);
}

String _requiredStateKey(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _validateStateKey(
    _requiredStableString(json, key, path: path),
    path: '$path.$key',
  );
}

String _validateStateKey(String value, {required String path}) {
  try {
    return validateStateKey(value);
  } on ArgumentError {
    _fail(
      'Mp state key must be a safe lowercase dot path.',
      path: path,
      details: <String, dynamic>{'stateKey': value},
    );
  }
}

bool _statePatchPathsOverlap(String left, String right) {
  return left == right ||
      left.startsWith('$right.') ||
      right.startsWith('$left.');
}

String _requiredCacheKey(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path).trim();
  if (_unsafeCacheKeyPattern.hasMatch(value)) {
    _fail(
      'Mp cache key cannot contain path traversal, separators, or file path markers.',
      path: '$path.$key',
      details: <String, dynamic>{key: value},
    );
  }
  return value;
}

String? _optionalCacheBucket(
  Map<String, dynamic> json, {
  required String path,
}) {
  final bucket = _optionalStableString(json, 'bucket', path: path);
  if (bucket == null) {
    return null;
  }
  if (!_allowedMiniProgramCacheBuckets.contains(bucket)) {
    _fail(
      'Mp cache bucket is not allowed for mini-program actions.',
      path: '$path.bucket',
      details: <String, dynamic>{'bucket': bucket},
    );
  }
  return bucket;
}

String? _optionalCachePriority(
  Map<String, dynamic> json, {
  required String path,
}) {
  final priority = _optionalStableString(json, 'priority', path: path);
  if (priority == null) {
    return null;
  }
  if (!_allowedMiniProgramCachePriorities.contains(priority)) {
    _fail(
      'Mp cache priority is not allowed for mini-program actions.',
      path: '$path.priority',
      details: <String, dynamic>{'priority': priority},
    );
  }
  return priority;
}

void _validateCacheValue(Object? value, {required String path}) {
  if (value == null || value is String || value is bool) {
    return;
  }
  if (value is num) {
    if (!value.isFinite) {
      _fail('Mp cache value numbers must be finite.', path: path);
    }
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _validateCacheValue(value[index], path: '$path[$index]');
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String || entry.key.toString().trim().isEmpty) {
        _fail('Mp cache value map keys must be non-empty strings.', path: path);
      }
      _validateCacheValue(entry.value, path: '$path.${entry.key}');
    }
    return;
  }
  _fail('Mp cache value must be JSON-safe.', path: path);
}
