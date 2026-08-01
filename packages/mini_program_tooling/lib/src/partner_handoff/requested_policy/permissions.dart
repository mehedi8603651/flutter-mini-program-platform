import '../errors.dart';

Map<String, Object?> normalizePartnerHandoffRequestedPermissions(Object? raw) {
  if (raw == null) {
    return const <String, Object?>{};
  }
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPermissions must be an object.',
    );
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key != 'location' &&
        entry.key != 'files' &&
        entry.key != 'camera' &&
        entry.key != 'flashlight') {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions contains an '
        'unsupported permission: ${entry.key}.',
      );
    }
    if (entry.key == 'files') {
      normalized['files'] = _normalizeRequestedFiles(entry.value);
      continue;
    }
    if (entry.key == 'camera') {
      normalized['camera'] = _normalizeRequestedCamera(entry.value);
      continue;
    }
    if (entry.key == 'flashlight') {
      normalized['flashlight'] = _normalizeRequestedFlashlight(entry.value);
      continue;
    }
    final value = entry.value;
    if (value is! Map) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions.location must be '
        'an object.',
      );
    }
    const allowedKeys = <String>{'enabled', 'reason', 'accuracy', 'mode'};
    for (final key in value.keys) {
      if (key is! String || !allowedKeys.contains(key)) {
        throw MiniProgramPartnerHandoffException(
          'MiniProgram partner handoff requestedPermissions.location '
          'contains an unsupported property: $key.',
        );
      }
    }
    final enabled = value['enabled'];
    if (enabled is! bool) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff '
        'requestedPermissions.location.enabled must be a boolean.',
      );
    }
    final reason = value['reason'];
    if (reason is! String || reason.trim().isEmpty || reason.length > 256) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff '
        'requestedPermissions.location.reason must be 1-256 characters.',
      );
    }
    if (value['accuracy'] != 'approximate') {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff '
        'requestedPermissions.location.accuracy must be "approximate".',
      );
    }
    if (value['mode'] != 'whenInUse') {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff '
        'requestedPermissions.location.mode must be "whenInUse".',
      );
    }
    normalized['location'] =
        Map<String, Object?>.unmodifiable(<String, Object?>{
          'enabled': enabled,
          'reason': reason.trim(),
          'accuracy': 'approximate',
          'mode': 'whenInUse',
        });
  }
  return Map<String, Object?>.unmodifiable(normalized);
}

Map<String, Object?> _normalizeRequestedCamera(Object? raw) {
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPermissions.camera must be an object.',
    );
  }
  const allowedKeys = <String>{'enabled', 'reason', 'capturePhoto'};
  for (final key in raw.keys) {
    if (key is! String || !allowedKeys.contains(key)) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions.camera contains an '
        'unsupported property: $key.',
      );
    }
  }
  final enabled = raw['enabled'];
  final capturePhoto = raw['capturePhoto'];
  final reason = raw['reason'];
  if (enabled is! bool || capturePhoto is! bool) {
    throw const MiniProgramPartnerHandoffException(
      'requestedPermissions.camera enabled and capturePhoto must be booleans.',
    );
  }
  if (enabled && !capturePhoto) {
    throw const MiniProgramPartnerHandoffException(
      'Enabled requestedPermissions.camera must request photo capture.',
    );
  }
  _validateRequestedPermissionReason(reason, 'camera');
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'enabled': enabled,
    'reason': (reason! as String).trim(),
    'capturePhoto': capturePhoto,
  });
}

Map<String, Object?> _normalizeRequestedFlashlight(Object? raw) {
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPermissions.flashlight must be an object.',
    );
  }
  const allowedKeys = <String>{'enabled', 'reason'};
  for (final key in raw.keys) {
    if (key is! String || !allowedKeys.contains(key)) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions.flashlight contains '
        'an unsupported property: $key.',
      );
    }
  }
  final enabled = raw['enabled'];
  final reason = raw['reason'];
  if (enabled is! bool) {
    throw const MiniProgramPartnerHandoffException(
      'requestedPermissions.flashlight.enabled must be a boolean.',
    );
  }
  _validateRequestedPermissionReason(reason, 'flashlight');
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'enabled': enabled,
    'reason': (reason! as String).trim(),
  });
}

void _validateRequestedPermissionReason(Object? reason, String permission) {
  if (reason is! String || reason.trim().isEmpty || reason.length > 256) {
    throw MiniProgramPartnerHandoffException(
      'requestedPermissions.$permission.reason must be 1-256 characters.',
    );
  }
}

Map<String, Object?> _normalizeRequestedFiles(Object? raw) {
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPermissions.files must be an object.',
    );
  }
  const allowedKeys = <String>{
    'enabled',
    'reason',
    'upload',
    'download',
    'mimeTypes',
    'destinations',
    'recommendedMaxFileBytes',
    'recommendedMaxFilesPerUpload',
    'recommendedMaxConcurrentTransfers',
  };
  for (final key in raw.keys) {
    if (key is! String || !allowedKeys.contains(key)) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions.files contains an '
        'unsupported property: $key.',
      );
    }
  }
  final enabled = raw['enabled'];
  final upload = raw['upload'];
  final download = raw['download'];
  final reason = raw['reason'];
  if (enabled is! bool || upload is! bool || download is! bool) {
    throw const MiniProgramPartnerHandoffException(
      'requestedPermissions.files enabled, upload, and download must be booleans.',
    );
  }
  if (enabled && !upload && !download) {
    throw const MiniProgramPartnerHandoffException(
      'Enabled requestedPermissions.files must request upload or download.',
    );
  }
  if (reason is! String || reason.trim().isEmpty || reason.length > 256) {
    throw const MiniProgramPartnerHandoffException(
      'requestedPermissions.files.reason must be 1-256 characters.',
    );
  }
  final mimeTypes = _requestedStringList(
    raw['mimeTypes'] ?? const <String>['*/*'],
    name: 'requestedPermissions.files.mimeTypes',
    maxItems: 32,
    validate: _isMimeType,
  );
  final destinations = _requestedStringList(
    raw['destinations'] ?? const <String>['downloads', 'choose', 'temporary'],
    name: 'requestedPermissions.files.destinations',
    maxItems: 3,
    validate: const <String>{'downloads', 'choose', 'temporary'}.contains,
  );
  final maxFileBytes = _optionalPositiveInt(
    raw['recommendedMaxFileBytes'],
    'requestedPermissions.files.recommendedMaxFileBytes',
  );
  final maxFiles = _positiveIntOrDefault(
    raw['recommendedMaxFilesPerUpload'],
    10,
    'requestedPermissions.files.recommendedMaxFilesPerUpload',
    max: 100,
  );
  final maxConcurrent = _positiveIntOrDefault(
    raw['recommendedMaxConcurrentTransfers'],
    2,
    'requestedPermissions.files.recommendedMaxConcurrentTransfers',
    max: 16,
  );
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'enabled': enabled,
    'reason': reason.trim(),
    'upload': upload,
    'download': download,
    'mimeTypes': List<String>.unmodifiable(mimeTypes),
    'destinations': List<String>.unmodifiable(destinations),
    if (maxFileBytes != null) 'recommendedMaxFileBytes': maxFileBytes,
    'recommendedMaxFilesPerUpload': maxFiles,
    'recommendedMaxConcurrentTransfers': maxConcurrent,
  });
}

List<String> _requestedStringList(
  Object? raw, {
  required String name,
  required int maxItems,
  required bool Function(String value) validate,
}) {
  if (raw is! List || raw.isEmpty || raw.length > maxItems) {
    throw MiniProgramPartnerHandoffException(
      '$name must contain 1-$maxItems values.',
    );
  }
  final result = <String>[];
  for (final value in raw) {
    if (value is! String || !validate(value.trim().toLowerCase())) {
      throw MiniProgramPartnerHandoffException(
        '$name contains an invalid value.',
      );
    }
    final normalized = value.trim().toLowerCase();
    if (!result.contains(normalized)) {
      result.add(normalized);
    }
  }
  return result;
}

bool _isMimeType(String value) {
  if (value == '*/*') {
    return true;
  }
  final parts = value.split('/');
  final token = RegExp(r'^[a-z0-9!#$&^_.+-]+$');
  return parts.length == 2 &&
      token.hasMatch(parts.first) &&
      (parts.last == '*' || token.hasMatch(parts.last));
}

int? _optionalPositiveInt(Object? value, String name) {
  if (value == null) {
    return null;
  }
  if (value is! int || value <= 0) {
    throw MiniProgramPartnerHandoffException(
      '$name must be a positive integer.',
    );
  }
  return value;
}

int _positiveIntOrDefault(
  Object? value,
  int fallback,
  String name, {
  required int max,
}) {
  if (value == null) {
    return fallback;
  }
  if (value is! int || value <= 0 || value > max) {
    throw MiniProgramPartnerHandoffException(
      '$name must be an integer from 1 to $max.',
    );
  }
  return value;
}
