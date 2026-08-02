import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'json_values.dart';
import 'models.dart';

const Map<String, Object?> defaultHostLiveStatePolicy = <String, Object?>{
  'maxBytes': 2 * 1024 * 1024,
  'maxEntries': 1000,
  'maxValueBytes': 256 * 1024,
  'maxDepth': 32,
};

Future<Map<String, Object?>> upsertHostPolicyFile({
  required File policyFile,
  required String appId,
  required String? sourcePath,
  required Map<String, Object?> requestedCache,
  required Map<String, Object?> requestedPublisherApi,
  required Map<String, Object?> requestedPermissions,
  required bool acceptRequestedPolicy,
  required bool forceAcceptedPolicy,
}) async {
  final existing = await policyFile.exists()
      ? _readHostPolicyDocument(
          await policyFile.readAsString(),
          policyFile.path,
        )
      : <String, Object?>{'schemaVersion': 1, 'apps': <String, Object?>{}};
  final apps = hostJsonObjectOrEmpty(existing['apps']);
  final existingApp = hostJsonObjectOrEmpty(apps[appId]);
  final existingAccepted = existingApp['accepted'] is Map
      ? hostJsonObjectOrEmpty(existingApp['accepted'])
      : null;

  apps[appId] = <String, Object?>{
    'requested': <String, Object?>{
      'source': _hostPolicySourceName(sourcePath),
      'cache': deepHostJsonObjectCopy(requestedCache),
      if (requestedPublisherApi.isNotEmpty)
        'publisherApi': deepHostJsonObjectCopy(requestedPublisherApi),
      'permissions': deepHostJsonObjectCopy(requestedPermissions),
    },
    'accepted': _acceptedHostPolicyFor(
      requestedCache: requestedCache,
      requestedPublisherApi: requestedPublisherApi,
      requestedPermissions: requestedPermissions,
      existingAccepted: existingAccepted,
      acceptRequestedPolicy: acceptRequestedPolicy,
      forceAcceptedPolicy: forceAcceptedPolicy,
    ),
  };
  for (final entry in apps.entries.toList(growable: false)) {
    final app = hostJsonObjectOrEmpty(entry.value);
    final accepted = hostJsonObjectOrEmpty(app['accepted']);
    accepted['liveState'] = accepted['liveState'] is Map
        ? validateHostLiveStatePolicy(
            hostJsonObjectOrEmpty(accepted['liveState']),
          )
        : deepHostJsonObjectCopy(defaultHostLiveStatePolicy);
    accepted['publisherApi'] = accepted['publisherApi'] is Map
        ? validateAcceptedHostPublisherApi(
            hostJsonObjectOrEmpty(accepted['publisherApi']),
          )
        : <String, Object?>{'enabled': false};
    accepted['permissions'] = accepted['permissions'] is Map
        ? validateAcceptedHostPermissions(
            hostJsonObjectOrEmpty(accepted['permissions']),
          )
        : <String, Object?>{};
    app['accepted'] = sortedHostJsonObject(accepted);
    apps[entry.key] = app;
  }

  final document = <String, Object?>{
    'schemaVersion': 1,
    'apps': sortedHostJsonObject(apps),
  };
  await policyFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
  return document;
}

Map<String, Object?> _readHostPolicyDocument(String source, String filePath) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw MiniProgramHostException(
      'Mini-program policy file is invalid in $filePath.',
    );
  }
  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion != null && schemaVersion != 1) {
    throw MiniProgramHostException(
      'Unsupported mini-program policy schema version in $filePath: '
      '$schemaVersion.',
    );
  }
  return deepHostJsonObjectCopy(decoded);
}

String _hostPolicySourceName(String? sourcePath) {
  final trimmed = sourcePath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'manual';
  }
  return p.basename(trimmed);
}

Map<String, Object?> _acceptedHostPolicyFor({
  required Map<String, Object?> requestedCache,
  required Map<String, Object?> requestedPublisherApi,
  required Map<String, Object?> requestedPermissions,
  required Map<String, Object?>? existingAccepted,
  required bool acceptRequestedPolicy,
  required bool forceAcceptedPolicy,
}) {
  if (forceAcceptedPolicy || existingAccepted == null) {
    return <String, Object?>{
      'cache': _acceptedHostCacheFromRequested(requestedCache),
      'publisherApi': _acceptedHostPublisherApiFromRequested(
        requestedPublisherApi,
        acceptRequested: forceAcceptedPolicy || acceptRequestedPolicy,
      ),
      'liveState': deepHostJsonObjectCopy(defaultHostLiveStatePolicy),
      'permissions': _acceptedHostPermissionsFromRequested(
        requestedPermissions,
        acceptRequested: acceptRequestedPolicy && !forceAcceptedPolicy,
      ),
    };
  }

  final accepted = deepHostJsonObjectCopy(existingAccepted);
  final acceptedCache = hostJsonObjectOrEmpty(accepted['cache']);
  for (final entry in requestedCache.entries) {
    if (acceptRequestedPolicy || !acceptedCache.containsKey(entry.key)) {
      acceptedCache[entry.key] = _acceptedHostCacheBucketFromRequest(
        entry.key,
        entry.value,
      );
    }
  }
  accepted['cache'] = sortedHostJsonObject(acceptedCache);
  if (acceptRequestedPolicy) {
    final acceptedPublisherApi = accepted['publisherApi'] is Map
        ? deepHostJsonObjectCopy(
            hostJsonObjectOrEmpty(accepted['publisherApi']),
          )
        : <String, Object?>{};
    acceptedPublisherApi['enabled'] = requestedPublisherApi['enabled'] == true;
    accepted['publisherApi'] = validateAcceptedHostPublisherApi(
      acceptedPublisherApi,
    );
  } else if (accepted['publisherApi'] is! Map) {
    accepted['publisherApi'] = _acceptedHostPublisherApiFromRequested(
      requestedPublisherApi,
      acceptRequested: false,
    );
  } else {
    accepted['publisherApi'] = validateAcceptedHostPublisherApi(
      hostJsonObjectOrEmpty(accepted['publisherApi']),
    );
  }
  accepted['liveState'] = accepted['liveState'] is Map
      ? validateHostLiveStatePolicy(
          hostJsonObjectOrEmpty(accepted['liveState']),
        )
      : deepHostJsonObjectCopy(defaultHostLiveStatePolicy);
  final acceptedPermissions = accepted['permissions'] is Map
      ? deepHostJsonObjectCopy(hostJsonObjectOrEmpty(accepted['permissions']))
      : <String, Object?>{};
  for (final entry in requestedPermissions.entries) {
    if (acceptRequestedPolicy || !acceptedPermissions.containsKey(entry.key)) {
      final current = acceptedPermissions[entry.key] is Map
          ? deepHostJsonObjectCopy(
              hostJsonObjectOrEmpty(acceptedPermissions[entry.key]),
            )
          : <String, Object?>{};
      acceptedPermissions[entry.key] = _acceptedHostPermissionFromRequested(
        entry.key,
        entry.value,
        acceptRequested: acceptRequestedPolicy,
        existing: current,
      );
    }
  }
  accepted['permissions'] = validateAcceptedHostPermissions(
    acceptedPermissions,
  );
  return sortedHostJsonObject(accepted);
}

Map<String, Object?> _acceptedHostPermissionsFromRequested(
  Map<String, Object?> requestedPermissions, {
  required bool acceptRequested,
}) {
  final accepted = <String, Object?>{};
  for (final entry in requestedPermissions.entries) {
    accepted[entry.key] = _acceptedHostPermissionFromRequested(
      entry.key,
      entry.value,
      acceptRequested: acceptRequested,
    );
  }
  return sortedHostJsonObject(accepted);
}

Map<String, Object?> _acceptedHostPermissionFromRequested(
  String permission,
  Object? requested, {
  required bool acceptRequested,
  Map<String, Object?> existing = const <String, Object?>{},
}) {
  if (permission == 'files') {
    final request = requested is Map
        ? hostJsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return validateAcceptedHostFiles(<String, Object?>{
      ...deepHostJsonObjectCopy(existing),
      'enabled': acceptRequested && request['enabled'] == true,
      'allowUpload': acceptRequested && request['upload'] == true,
      'allowDownload': acceptRequested && request['download'] == true,
      'allowedMimeTypes': request['mimeTypes'] is List
          ? List<Object?>.from(request['mimeTypes']! as List)
          : const <String>['*/*'],
      'allowedDestinations': request['destinations'] is List
          ? List<Object?>.from(request['destinations']! as List)
          : const <String>['downloads', 'choose', 'temporary'],
      'maxFileBytes': positiveHostInt(request['recommendedMaxFileBytes']),
      'maxFilesPerUpload':
          positiveHostInt(request['recommendedMaxFilesPerUpload']) ?? 10,
      'maxConcurrentTransfers':
          positiveHostInt(request['recommendedMaxConcurrentTransfers']) ?? 2,
      'minimumFreeBytes': 256 * 1024 * 1024,
    });
  }
  if (permission == 'camera') {
    final request = requested is Map
        ? hostJsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return validateAcceptedHostCamera(<String, Object?>{
      ...deepHostJsonObjectCopy(existing),
      'enabled': acceptRequested && request['enabled'] == true,
      'allowPhotoCapture': acceptRequested && request['capturePhoto'] == true,
    });
  }
  if (permission == 'flashlight') {
    final request = requested is Map
        ? hostJsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return validateAcceptedHostFlashlight(<String, Object?>{
      ...deepHostJsonObjectCopy(existing),
      'enabled': acceptRequested && request['enabled'] == true,
    });
  }
  if (permission == 'qrScanner') {
    final request = requested is Map
        ? hostJsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return validateAcceptedHostQrScanner(<String, Object?>{
      ...deepHostJsonObjectCopy(existing),
      'enabled': acceptRequested && request['enabled'] == true,
      'allowTorch': acceptRequested && request['allowTorch'] == true,
    });
  }
  if (permission == 'audioPlayback' || permission == 'videoPlayback') {
    final request = requested is Map
        ? hostJsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return validateAcceptedHostPlaybackPermission(<String, Object?>{
      ...deepHostJsonObjectCopy(existing),
      'enabled': acceptRequested && request['enabled'] == true,
    }, permission);
  }
  if (permission != 'location') {
    return deepHostJsonObjectCopy(existing);
  }
  final request = requested is Map
      ? hostJsonObjectOrEmpty(requested)
      : <String, Object?>{};
  return sortedHostJsonObject(<String, Object?>{
    ...deepHostJsonObjectCopy(existing),
    'enabled': acceptRequested && request['enabled'] == true,
    'accuracy': 'approximate',
    'mode': 'whenInUse',
  });
}

Map<String, Object?> validateAcceptedHostPermissions(
  Map<String, Object?> permissions,
) {
  final normalized = deepHostJsonObjectCopy(permissions);
  final rawFiles = normalized['files'];
  if (rawFiles != null) {
    if (rawFiles is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.files must be an object.',
      );
    }
    normalized['files'] = validateAcceptedHostFiles(
      hostJsonObjectOrEmpty(rawFiles),
    );
  }
  final rawLocation = normalized['location'];
  if (rawLocation != null) {
    if (rawLocation is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.location must be an object.',
      );
    }
    final location = deepHostJsonObjectCopy(hostJsonObjectOrEmpty(rawLocation));
    if (location['enabled'] is! bool) {
      throw const MiniProgramHostException(
        'Accepted permissions.location.enabled must be a boolean.',
      );
    }
    if (location['accuracy'] != 'approximate') {
      throw const MiniProgramHostException(
        'Accepted permissions.location.accuracy must be "approximate".',
      );
    }
    if (location['mode'] != 'whenInUse') {
      throw const MiniProgramHostException(
        'Accepted permissions.location.mode must be "whenInUse".',
      );
    }
    normalized['location'] = sortedHostJsonObject(location);
  }
  final rawCamera = normalized['camera'];
  if (rawCamera != null) {
    if (rawCamera is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.camera must be an object.',
      );
    }
    normalized['camera'] = validateAcceptedHostCamera(
      hostJsonObjectOrEmpty(rawCamera),
    );
  }
  final rawFlashlight = normalized['flashlight'];
  if (rawFlashlight != null) {
    if (rawFlashlight is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.flashlight must be an object.',
      );
    }
    normalized['flashlight'] = validateAcceptedHostFlashlight(
      hostJsonObjectOrEmpty(rawFlashlight),
    );
  }
  final rawQrScanner = normalized['qrScanner'];
  if (rawQrScanner != null) {
    if (rawQrScanner is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.qrScanner must be an object.',
      );
    }
    normalized['qrScanner'] = validateAcceptedHostQrScanner(
      hostJsonObjectOrEmpty(rawQrScanner),
    );
  }
  for (final permission in const <String>['audioPlayback', 'videoPlayback']) {
    final raw = normalized[permission];
    if (raw == null) continue;
    if (raw is! Map) {
      throw MiniProgramHostException(
        'Accepted permissions.$permission must be an object.',
      );
    }
    normalized[permission] = validateAcceptedHostPlaybackPermission(
      hostJsonObjectOrEmpty(raw),
      permission,
    );
  }
  return sortedHostJsonObject(normalized);
}

Map<String, Object?> validateAcceptedHostPlaybackPermission(
  Map<String, Object?> value,
  String permission,
) {
  final normalized = deepHostJsonObjectCopy(value);
  if (normalized['enabled'] is! bool) {
    throw MiniProgramHostException(
      'Accepted permissions.$permission.enabled must be a boolean.',
    );
  }
  return sortedHostJsonObject(normalized);
}

Map<String, Object?> validateAcceptedHostCamera(Map<String, Object?> value) {
  final normalized = deepHostJsonObjectCopy(value);
  for (final key in const <String>{'enabled', 'allowPhotoCapture'}) {
    if (normalized[key] is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.camera.$key must be a boolean.',
      );
    }
  }
  if (normalized['enabled'] == true &&
      normalized['allowPhotoCapture'] != true) {
    throw const MiniProgramHostException(
      'Enabled permissions.camera must allow photo capture.',
    );
  }
  return sortedHostJsonObject(normalized);
}

Map<String, Object?> validateAcceptedHostFlashlight(
  Map<String, Object?> value,
) {
  final normalized = deepHostJsonObjectCopy(value);
  if (normalized['enabled'] is! bool) {
    throw const MiniProgramHostException(
      'Accepted permissions.flashlight.enabled must be a boolean.',
    );
  }
  return sortedHostJsonObject(normalized);
}

Map<String, Object?> validateAcceptedHostQrScanner(Map<String, Object?> value) {
  final normalized = deepHostJsonObjectCopy(value);
  for (final key in const <String>{'enabled', 'allowTorch'}) {
    if (normalized[key] is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.qrScanner.$key must be a boolean.',
      );
    }
  }
  return sortedHostJsonObject(normalized);
}

Map<String, Object?> validateAcceptedHostFiles(Map<String, Object?> value) {
  final normalized = deepHostJsonObjectCopy(value);
  for (final key in const <String>{'enabled', 'allowUpload', 'allowDownload'}) {
    if (normalized[key] is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.files.$key must be a boolean.',
      );
    }
  }
  final enabled = normalized['enabled']! as bool;
  final allowUpload = normalized['allowUpload']! as bool;
  final allowDownload = normalized['allowDownload']! as bool;
  if (enabled && !allowUpload && !allowDownload) {
    throw const MiniProgramHostException(
      'Enabled permissions.files must allow upload or download.',
    );
  }
  normalized['allowedMimeTypes'] = _acceptedHostStringList(
    normalized['allowedMimeTypes'],
    name: 'Accepted permissions.files.allowedMimeTypes',
    maxItems: 32,
    validate: _isAcceptedHostMimeType,
  );
  normalized['allowedDestinations'] = _acceptedHostStringList(
    normalized['allowedDestinations'],
    name: 'Accepted permissions.files.allowedDestinations',
    maxItems: 3,
    validate: const <String>{'downloads', 'choose', 'temporary'}.contains,
  );
  final maxFileBytes = normalized['maxFileBytes'];
  if (maxFileBytes != null && positiveHostInt(maxFileBytes) == null) {
    throw const MiniProgramHostException(
      'Accepted permissions.files.maxFileBytes must be null or a positive integer.',
    );
  }
  normalized['maxFileBytes'] = maxFileBytes == null
      ? null
      : positiveHostInt(maxFileBytes);
  normalized['maxFilesPerUpload'] = _acceptedHostBoundedInt(
    normalized['maxFilesPerUpload'],
    name: 'Accepted permissions.files.maxFilesPerUpload',
    max: 100,
  );
  normalized['maxConcurrentTransfers'] = _acceptedHostBoundedInt(
    normalized['maxConcurrentTransfers'],
    name: 'Accepted permissions.files.maxConcurrentTransfers',
    max: 16,
  );
  normalized['minimumFreeBytes'] = _acceptedHostBoundedInt(
    normalized['minimumFreeBytes'],
    name: 'Accepted permissions.files.minimumFreeBytes',
    max: 1024 * 1024 * 1024 * 1024,
  );
  return sortedHostJsonObject(normalized);
}

List<String> _acceptedHostStringList(
  Object? raw, {
  required String name,
  required int maxItems,
  required bool Function(String value) validate,
}) {
  if (raw is! List || raw.isEmpty || raw.length > maxItems) {
    throw MiniProgramHostException('$name must contain 1-$maxItems values.');
  }
  final result = <String>[];
  for (final item in raw) {
    if (item is! String || !validate(item.trim().toLowerCase())) {
      throw MiniProgramHostException('$name contains an invalid value.');
    }
    final normalized = item.trim().toLowerCase();
    if (!result.contains(normalized)) {
      result.add(normalized);
    }
  }
  return result;
}

bool _isAcceptedHostMimeType(String value) {
  if (value == '*/*') {
    return true;
  }
  final parts = value.split('/');
  final token = RegExp(r'^[a-z0-9!#$&^_.+-]+$');
  return parts.length == 2 &&
      token.hasMatch(parts.first) &&
      (parts.last == '*' || token.hasMatch(parts.last));
}

int _acceptedHostBoundedInt(
  Object? raw, {
  required String name,
  required int max,
}) {
  final value = positiveHostInt(raw);
  if (value == null || value > max) {
    throw MiniProgramHostException('$name must be an integer from 1 to $max.');
  }
  return value;
}

Map<String, Object?> _acceptedHostPublisherApiFromRequested(
  Map<String, Object?> requestedPublisherApi, {
  required bool acceptRequested,
}) {
  final requestedEnabled = requestedPublisherApi['enabled'] == true;
  return <String, Object?>{'enabled': acceptRequested && requestedEnabled};
}

Map<String, Object?> validateAcceptedHostPublisherApi(
  Map<String, Object?> value,
) {
  final enabled = value['enabled'];
  if (enabled is! bool) {
    throw const MiniProgramHostException(
      'Accepted publisherApi.enabled must be a boolean.',
    );
  }
  return sortedHostJsonObject(<String, Object?>{
    ...deepHostJsonObjectCopy(value),
    'enabled': enabled,
  });
}

Map<String, Object?> validateHostLiveStatePolicy(Map<String, Object?> value) {
  final normalized = <String, Object?>{};
  for (final entry in defaultHostLiveStatePolicy.entries) {
    final candidate = value[entry.key] ?? entry.value;
    final parsed = positiveHostInt(candidate);
    if (parsed == null) {
      throw MiniProgramHostException(
        'Accepted live-state policy ${entry.key} must be a positive integer.',
      );
    }
    normalized[entry.key] = parsed;
  }
  final maxBytes = normalized['maxBytes']! as int;
  final maxValueBytes = normalized['maxValueBytes']! as int;
  if (maxValueBytes > maxBytes) {
    throw const MiniProgramHostException(
      'Accepted live-state maxValueBytes cannot exceed maxBytes.',
    );
  }
  return normalized;
}

Map<String, Object?> _acceptedHostCacheFromRequested(
  Map<String, Object?> requestedCache,
) {
  final acceptedCache = <String, Object?>{};
  for (final entry in requestedCache.entries) {
    acceptedCache[entry.key] = _acceptedHostCacheBucketFromRequest(
      entry.key,
      entry.value,
    );
  }
  return sortedHostJsonObject(acceptedCache);
}

Map<String, Object?> _acceptedHostCacheBucketFromRequest(
  String bucket,
  Object? requested,
) {
  final requestedPolicy = requested is Map
      ? hostJsonObjectOrEmpty(requested)
      : <String, Object?>{};
  return <String, Object?>{
    'enabled': requestedPolicy['enabled'] is bool
        ? requestedPolicy['enabled'] as bool
        : true,
    'maxBytes':
        positiveHostInt(requestedPolicy['recommendedMaxBytes']) ??
        _defaultHostPolicyMaxBytes(bucket),
    'ttlDays':
        positiveHostInt(requestedPolicy['recommendedTtlDays']) ??
        _defaultHostPolicyTtlDays(bucket),
  };
}

int _defaultHostPolicyMaxBytes(String bucket) {
  return switch (bucket) {
    'memory' => 1024 * 1024,
    'data' => 10 * 1024 * 1024,
    'image' => 20 * 1024 * 1024,
    'state' => 1024 * 1024,
    'video' => 50 * 1024 * 1024,
    _ => 1024 * 1024,
  };
}

int _defaultHostPolicyTtlDays(String bucket) {
  return switch (bucket) {
    'memory' => 1,
    'data' => 30,
    'image' => 14,
    'state' => 30,
    'video' => 1,
    _ => 30,
  };
}
