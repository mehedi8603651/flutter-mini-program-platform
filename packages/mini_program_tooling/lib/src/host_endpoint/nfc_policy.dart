import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'json_values.dart';
import 'models.dart';

Map<String, Object?> validateAcceptedNfcPermission(Map<String, Object?> raw) {
  final next = deepHostJsonObjectCopy(raw);
  final enabled = next['enabled'] ?? false;
  if (enabled is! bool) {
    throw const MiniProgramHostException(
      'Accepted permissions.nfc.enabled must be boolean.',
    );
  }
  next['enabled'] = enabled;
  for (final entry in {
    'maxReadMs': (15000, 1000, MiniProgramNfc.maxReadMs),
    'maxRecords': (8, 1, MiniProgramNfc.maxRecords),
    'maxMessageBytes': (4096, 1, MiniProgramNfc.maxMessageBytes),
  }.entries) {
    final value = next[entry.key] ?? entry.value.$1;
    if (value is! int || value < entry.value.$2 || value > entry.value.$3) {
      throw MiniProgramHostException('Invalid accepted NFC ${entry.key}.');
    }
    next[entry.key] = value;
  }
  try {
    next['allowedRecordTypes'] = MiniProgramNfc.recordTypes(
      next['allowedRecordTypes'] ?? const ['text', 'uri'],
    );
  } on FormatException {
    throw const MiniProgramHostException(
      'Invalid accepted NFC allowedRecordTypes.',
    );
  }
  return sortedHostJsonObject(next);
}

String buildNfcPolicyResolver(Map<String, Object?> apps) {
  final entries = apps.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final buffer = StringBuffer(
    'MiniProgramNfcPolicy nfcPolicyForMiniProgram(String appId) {\n  switch (appId) {\n',
  );
  for (final entry in entries) {
    final accepted = hostJsonObjectOrEmpty(
      hostJsonObjectOrEmpty(entry.value)['accepted'],
    );
    final raw = hostJsonObjectOrEmpty(accepted['permissions'])['nfc'];
    if (raw != null && raw is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.nfc must be an object.',
      );
    }
    final p = validateAcceptedNfcPermission(hostJsonObjectOrEmpty(raw));
    final types = (p['allowedRecordTypes'] as List)
        .map((v) => hostDartString(v as String))
        .join(', ');
    buffer.writeln('    case ${hostDartString(entry.key)}:');
    buffer.writeln(
      '      return const MiniProgramNfcPolicy(enabled: ${p['enabled']}, allowedRecordTypes: [$types], maxReadMs: ${p['maxReadMs']}, maxRecords: ${p['maxRecords']}, maxMessageBytes: ${p['maxMessageBytes']});',
    );
  }
  buffer.writeln('    default: return const MiniProgramNfcPolicy();\n  }\n}\n');
  return buffer.toString();
}
