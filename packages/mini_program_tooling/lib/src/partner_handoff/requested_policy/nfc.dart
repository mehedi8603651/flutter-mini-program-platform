import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../errors.dart';

Map<String, Object?> normalizeRequestedNfc(Object? raw) {
  if (raw is! Map ||
      raw.keys.any(
        (key) => !const {
          'enabled',
          'reason',
          'recordTypes',
          'recommendedMaxReadMs',
          'recommendedMaxRecords',
          'recommendedMaxMessageBytes',
        }.contains(key),
      )) {
    throw const MiniProgramPartnerHandoffException(
      'Unsupported requestedPermissions.nfc property.',
    );
  }
  final reason = raw['reason'];
  if (raw['enabled'] is! bool ||
      reason is! String ||
      reason.trim().isEmpty ||
      reason.length > 256 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(reason)) {
    throw const MiniProgramPartnerHandoffException(
      'NFC requests require enabled and a bounded reason.',
    );
  }
  final result = <String, Object?>{
    'enabled': raw['enabled'],
    'reason': reason.trim(),
  };
  for (final entry in {
    'recommendedMaxReadMs': (15000, 1000, MiniProgramNfc.maxReadMs),
    'recommendedMaxRecords': (8, 1, MiniProgramNfc.maxRecords),
    'recommendedMaxMessageBytes': (4096, 1, MiniProgramNfc.maxMessageBytes),
  }.entries) {
    final value = raw[entry.key] ?? entry.value.$1;
    if (value is! int || value < entry.value.$2 || value > entry.value.$3) {
      throw const MiniProgramPartnerHandoffException(
        'Invalid requested NFC limit.',
      );
    }
    result[entry.key] = value;
  }
  try {
    result['recordTypes'] = MiniProgramNfc.recordTypes(
      raw['recordTypes'] ?? const ['text', 'uri'],
    );
  } on FormatException {
    throw const MiniProgramPartnerHandoffException(
      'Invalid requested NFC record types.',
    );
  }
  return Map.unmodifiable(result);
}
