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
  final rawLocation = normalized['location'];
  if (rawLocation == null) {
    return sortedHostJsonObject(normalized);
  }
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
  return sortedHostJsonObject(normalized);
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
