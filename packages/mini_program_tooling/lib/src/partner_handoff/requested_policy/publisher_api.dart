import '../errors.dart';

Map<String, Object?> normalizePartnerHandoffRequestedPublisherApi(Object? raw) {
  if (raw == null) {
    return const <String, Object?>{};
  }
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPublisherApi must be an object.',
    );
  }
  if (raw.isEmpty) {
    return const <String, Object?>{};
  }
  const allowedKeys = <String>{'enabled', 'reason', 'contract'};
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || !allowedKeys.contains(key)) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedPublisherApi contains an '
        'unsupported property: $key.',
      );
    }
    normalized[key] = entry.value;
  }
  final enabled = normalized['enabled'];
  if (enabled is! bool) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPublisherApi.enabled must be a '
      'boolean.',
    );
  }
  final reason = normalized['reason'];
  if (reason is! String || reason.trim().isEmpty || reason.length > 256) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPublisherApi.reason must be '
      '1-256 characters.',
    );
  }
  final contract = normalized['contract'];
  if (contract != null && contract != 'publisher_backend.json') {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedPublisherApi.contract must be '
      '"publisher_backend.json".',
    );
  }
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'enabled': enabled,
    'reason': reason.trim(),
    'contract': 'publisher_backend.json',
  });
}
