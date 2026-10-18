import '../errors.dart';

Map<String, Object?> normalizeRequestedMaps(Object? raw) {
  if (raw is! Map ||
      raw.keys.any(
        (key) => !const {
          'enabled',
          'reason',
          'openLocation',
          'directions',
        }.contains(key),
      )) {
    throw const MiniProgramPartnerHandoffException(
      'requestedPermissions.maps requires a supported maps object.',
    );
  }
  final enabled = raw['enabled'];
  final reason = raw['reason'];
  final location = raw['openLocation'] ?? true;
  final directions = raw['directions'] ?? true;
  if (enabled is! bool ||
      location is! bool ||
      directions is! bool ||
      (enabled && !location && !directions) ||
      reason is! String ||
      reason.trim().isEmpty ||
      reason.length > 256) {
    throw const MiniProgramPartnerHandoffException(
      'Invalid requested maps operations or reason.',
    );
  }
  return Map<String, Object?>.unmodifiable({
    'enabled': enabled,
    'reason': reason.trim(),
    'openLocation': location,
    'directions': directions,
  });
}
