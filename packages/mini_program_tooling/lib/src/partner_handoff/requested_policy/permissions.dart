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
    if (entry.key != 'location') {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPermissions contains an '
        'unsupported permission: ${entry.key}.',
      );
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
