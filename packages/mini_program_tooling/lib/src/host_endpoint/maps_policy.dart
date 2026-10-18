import 'json_values.dart';
import 'models.dart';

Map<String, Object?> validateAcceptedMapsPermission(Map<String, Object?> raw) {
  final next = deepHostJsonObjectCopy(raw);
  for (final field in ['enabled', 'allowOpenLocation', 'allowDirections']) {
    final value = next[field] ?? (field != 'enabled');
    if (value is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.maps.$field must be boolean.',
      );
    }
    next[field] = value;
  }
  if (next['enabled'] == true &&
      next['allowOpenLocation'] != true &&
      next['allowDirections'] != true) {
    throw const MiniProgramHostException(
      'Enabled maps policy must accept at least one operation.',
    );
  }
  return sortedHostJsonObject(next);
}

String buildMapsPolicyResolver(Map<String, Object?> apps) {
  final entries = apps.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final buffer = StringBuffer(
    'MiniProgramMapsPolicy mapsPolicyForMiniProgram(String appId) {\n  switch (appId) {\n',
  );
  for (final entry in entries) {
    final accepted = hostJsonObjectOrEmpty(
      hostJsonObjectOrEmpty(entry.value)['accepted'],
    );
    final raw = hostJsonObjectOrEmpty(accepted['permissions'])['maps'];
    if (raw != null && raw is! Map) {
      throw const MiniProgramHostException(
        'Accepted permissions.maps must be an object.',
      );
    }
    final policy = validateAcceptedMapsPermission(hostJsonObjectOrEmpty(raw));
    buffer.writeln('    case ${hostDartString(entry.key)}:');
    buffer.writeln(
      '      return const MiniProgramMapsPolicy(enabled: ${policy['enabled']}, allowOpenLocation: ${policy['allowOpenLocation']}, allowDirections: ${policy['allowDirections']});',
    );
  }
  buffer.writeln(
    '    default: return const MiniProgramMapsPolicy();\n  }\n}\n',
  );
  return buffer.toString();
}
