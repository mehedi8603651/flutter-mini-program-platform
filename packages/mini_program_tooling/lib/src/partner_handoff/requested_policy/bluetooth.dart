import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../errors.dart';

Map<String, Object?> normalizeRequestedBluetooth(Object? raw) {
  if (raw is! Map ||
      raw.keys.any(
        (key) => !const {
          'enabled',
          'reason',
          'write',
          'notifications',
          'serviceUuids',
          'recommendedMaxScanMs',
          'recommendedMaxDevices',
          'recommendedMaxValueBytes',
        }.contains(key),
      )) {
    throw const MiniProgramPartnerHandoffException(
      'Unsupported requestedPermissions.bluetooth property.',
    );
  }
  final reason = raw['reason'];
  if (raw['enabled'] is! bool ||
      reason is! String ||
      reason.trim().isEmpty ||
      reason.length > 256) {
    throw const MiniProgramPartnerHandoffException(
      'BLE requests require enabled and a bounded reason.',
    );
  }
  final result = <String, Object?>{
    'enabled': raw['enabled'],
    'reason': reason.trim(),
  };
  for (final field in ['write', 'notifications']) {
    final value = raw[field] ?? (field == 'notifications');
    if (value is! bool) {
      throw const MiniProgramPartnerHandoffException(
        'BLE operation requests must be boolean.',
      );
    }
    result[field] = value;
  }
  for (final entry in {
    'recommendedMaxScanMs': (10000, 500, 15000),
    'recommendedMaxDevices': (20, 1, 64),
    'recommendedMaxValueBytes': (512, 1, 512),
  }.entries) {
    final value = raw[entry.key] ?? entry.value.$1;
    if (value is! int || value < entry.value.$2 || value > entry.value.$3) {
      throw const MiniProgramPartnerHandoffException(
        'Invalid requested BLE limit.',
      );
    }
    result[entry.key] = value;
  }
  try {
    result['serviceUuids'] = MiniProgramBluetooth.uuids(
      raw['serviceUuids'] ?? const [],
    );
  } on FormatException {
    throw const MiniProgramPartnerHandoffException(
      'Invalid requested BLE service UUIDs.',
    );
  }
  return Map.unmodifiable(result);
}
