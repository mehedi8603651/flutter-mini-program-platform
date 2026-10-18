import 'json_values.dart';
import 'models.dart';

Map<String, Object?> validateAcceptedSystemPermission(
  String feature,
  Map<String, Object?> raw,
) {
  final next = deepHostJsonObjectCopy(raw);
  for (final field in [
    'enabled',
    if (feature == 'clipboard') ...['allowRead', 'allowWrite'],
  ]) {
    final value = next[field] ?? (field == 'allowWrite');
    if (value is! bool) {
      throw MiniProgramHostException(
        'Accepted permissions.$feature.$field must be boolean.',
      );
    }
    next[field] = value;
  }
  if (feature == 'clipboard') {
    final maximum = next['maxTextLength'] ?? 32768;
    if (maximum is! int || maximum < 1 || maximum > 32768) {
      throw const MiniProgramHostException(
        'Accepted clipboard maxTextLength must be an integer from 1 to 32768.',
      );
    }
    next['maxTextLength'] = maximum;
    if (next['enabled'] == true &&
        next['allowRead'] != true &&
        next['allowWrite'] != true) {
      throw const MiniProgramHostException(
        'Enabled clipboard policy must accept reading or writing.',
      );
    }
  }
  return sortedHostJsonObject(next);
}

String buildSystemPolicyResolvers(Map<String, Object?> apps) {
  final entries = apps.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final buffer = StringBuffer();
  for (final feature in ['clipboard', 'vibration', 'phone']) {
    final title = '${feature[0].toUpperCase()}${feature.substring(1)}';
    buffer.writeln(
      'MiniProgram${title}Policy ${feature}PolicyForMiniProgram(String appId) {',
    );
    buffer.writeln('  switch (appId) {');
    for (final entry in entries) {
      final accepted = hostJsonObjectOrEmpty(
        hostJsonObjectOrEmpty(entry.value)['accepted'],
      );
      final permissions = hostJsonObjectOrEmpty(accepted['permissions']);
      final raw = permissions[feature];
      if (raw != null && raw is! Map) {
        throw MiniProgramHostException(
          'Accepted permissions.$feature must be an object.',
        );
      }
      final policy = validateAcceptedSystemPermission(
        feature,
        hostJsonObjectOrEmpty(raw),
      );
      buffer.writeln('    case ${hostDartString(entry.key)}:');
      final args =
          'enabled: ${policy['enabled']}${feature == 'clipboard' ? ', allowRead: ${policy['allowRead']}, allowWrite: ${policy['allowWrite']}, maxTextLength: ${policy['maxTextLength']}' : ''}';
      buffer.writeln('      return const MiniProgram${title}Policy($args);');
    }
    buffer.writeln('    default: return const MiniProgram${title}Policy();');
    buffer.writeln('  }\n}\n');
  }
  return buffer.toString();
}
