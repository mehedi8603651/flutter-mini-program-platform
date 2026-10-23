import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'json_values.dart';
import 'models.dart';

Map<String, Object?> validateAcceptedBluetoothPermission(
  Map<String, Object?> raw,
) {
  final next = deepHostJsonObjectCopy(raw);
  for (final field in ['enabled', 'allowWrite', 'allowNotifications']) {
    final value = next[field] ?? (field == 'allowNotifications');
    if (value is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.bluetooth.$field must be boolean.',
      );
    }
    next[field] = value;
  }
  for (final entry in {
    'maxScanMs': (10000, 500, 15000),
    'maxDevices': (20, 1, 64),
    'maxValueBytes': (512, 1, 512),
  }.entries) {
    final value = next[entry.key] ?? entry.value.$1;
    if (value is! int || value < entry.value.$2 || value > entry.value.$3) {
      throw MiniProgramHostException('Invalid accepted BLE ${entry.key}.');
    }
    next[entry.key] = value;
  }
  try {
    next['allowedServices'] = MiniProgramBluetooth.uuids(
      next['allowedServices'] ?? const [],
    );
  } on FormatException {
    throw const MiniProgramHostException(
      'Invalid accepted BLE allowedServices.',
    );
  }
  return sortedHostJsonObject(next);
}

String buildBluetoothPolicyResolver(Map<String, Object?> apps) {
  final entries = apps.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final buffer = StringBuffer(
    'MiniProgramBluetoothPolicy bluetoothPolicyForMiniProgram(String appId) {\n  switch (appId) {\n',
  );
  for (final entry in entries) {
    final accepted = hostJsonObjectOrEmpty(
      hostJsonObjectOrEmpty(entry.value)['accepted'],
    );
    final raw = hostJsonObjectOrEmpty(accepted['permissions'])['bluetooth'];
    if (raw != null && raw is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.bluetooth must be an object.',
      );
    }
    final p = validateAcceptedBluetoothPermission(hostJsonObjectOrEmpty(raw));
    final services = (p['allowedServices'] as List)
        .map((v) => hostDartString(v as String))
        .join(', ');
    buffer.writeln('    case ${hostDartString(entry.key)}:');
    buffer.writeln(
      '      return const MiniProgramBluetoothPolicy(enabled: ${p['enabled']}, allowWrite: ${p['allowWrite']}, allowNotifications: ${p['allowNotifications']}, allowedServices: [$services], maxScanMs: ${p['maxScanMs']}, maxDevices: ${p['maxDevices']}, maxValueBytes: ${p['maxValueBytes']});',
    );
  }
  buffer.writeln(
    '    default: return const MiniProgramBluetoothPolicy();\n  }\n}\n',
  );
  return buffer.toString();
}
