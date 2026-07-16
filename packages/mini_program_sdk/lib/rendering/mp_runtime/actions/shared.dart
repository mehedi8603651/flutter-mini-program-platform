part of '../../mp_screen_renderer.dart';

Future<MiniProgramBackendRequest> _authorize(
  MiniProgramSdkScope scope,
  MiniProgramBackendRequest request,
) {
  final controller = scope.authController;
  if (controller == null) {
    return Future<MiniProgramBackendRequest>.value(request);
  }
  return controller.authorizeRequest(
    request: request,
    connector: scope.backendConnector,
  );
}

MiniProgramBackendCachePolicy _cachePolicy(Map<String, dynamic> props) {
  final ttl = _cacheTtl(props);
  return ttl == null
      ? const MiniProgramBackendCachePolicy.noCache()
      : MiniProgramBackendCachePolicy(ttl: ttl);
}

Duration? _cacheTtl(Map<String, dynamic> props) {
  final value = props['cacheTtlSeconds'];
  return value is int ? Duration(seconds: value) : null;
}

String _stringProp(Map<String, dynamic> props, String key) {
  final value = props[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('Mp action requires a non-empty "$key" string.');
}

String? _optionalStringProp(Map<String, dynamic> props, String key) {
  final value = props[key];
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('Mp action "$key" must be a non-empty string.');
}

Map<String, dynamic> _mapProp(Map<String, dynamic> props, String key) {
  final value = props[key];
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('Mp action "$key" must be an object.');
}

bool _boolProp(Map<String, dynamic> props, String key) {
  final value = props[key];
  return value is bool && value;
}

Duration? _optionalDurationMs(Map<String, dynamic> props, String key) {
  final value = props[key];
  if (value == null) {
    return null;
  }
  if (value is int && value > 0) {
    return Duration(milliseconds: value);
  }
  throw FormatException('Mp action "$key" must be a positive integer.');
}

MiniProgramCacheBucket _cacheBucketProp(Map<String, dynamic> props) {
  return _cacheBucketFromName(_optionalStringProp(props, 'bucket') ?? 'data');
}

MiniProgramCachePriority _cachePriorityProp(Map<String, dynamic> props) {
  return switch (_optionalStringProp(props, 'priority') ?? 'normal') {
    'low' => MiniProgramCachePriority.low,
    'normal' => MiniProgramCachePriority.normal,
    'high' => MiniProgramCachePriority.high,
    _ => throw const FormatException('Unsupported Mp cache priority.'),
  };
}

MiniProgramCacheBucket _cacheBucketFromName(String name) {
  return switch (name) {
    'memory' => MiniProgramCacheBucket.memory,
    'data' => MiniProgramCacheBucket.data,
    'image' => MiniProgramCacheBucket.image,
    'state' => MiniProgramCacheBucket.state,
    'video' => MiniProgramCacheBucket.video,
    _ => throw const FormatException('Unsupported Mp cache bucket.'),
  };
}

int _intProp(Map<String, dynamic> props, String key, {required int fallback}) {
  final value = props[key];
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Mp action "$key" must be an integer.');
}

int? _optionalIntProp(Map<String, dynamic> props, String key) {
  final value = props[key];
  return value is int ? value : null;
}

num _numProp(Map<String, dynamic> props, String key, {required num fallback}) {
  final value = props[key];
  if (value == null) {
    return fallback;
  }
  if (value is num) {
    return value;
  }
  throw FormatException('Mp action "$key" must be numeric.');
}
