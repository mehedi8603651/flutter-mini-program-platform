import '../errors.dart';

Map<String, Object?> normalizePartnerHandoffJsonObject(
  Map<dynamic, dynamic> raw,
  String path,
) {
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || key.trim().isEmpty) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff $path keys must be strings.',
      );
    }
    final keyName = key.trim();
    validatePartnerHandoffNonSensitivePolicyKey(keyName, '$path.$keyName');
    normalized[keyName] = normalizePartnerHandoffJsonValue(
      entry.value,
      '$path.$keyName',
    );
  }
  return Map<String, Object?>.unmodifiable(normalized);
}

Object? normalizePartnerHandoffJsonValue(Object? value, String path) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value
          .map((item) => normalizePartnerHandoffJsonValue(item, '$path[]'))
          .toList(growable: false),
    );
  }
  if (value is Map) {
    return normalizePartnerHandoffJsonObject(value, path);
  }
  throw MiniProgramPartnerHandoffException(
    'MiniProgram partner handoff $path must be JSON-safe.',
  );
}

void validatePartnerHandoffNonSensitivePolicyKey(String key, String path) {
  if (!isSensitivePartnerHandoffPolicyKey(key)) {
    return;
  }
  throw MiniProgramPartnerHandoffException(
    'MiniProgram partner handoff $path is not allowed.',
  );
}

bool isSensitivePartnerHandoffPolicyKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized == 'session' ||
      normalized == 'logindata' ||
      normalized.contains('token') ||
      normalized.contains('password') ||
      normalized.contains('secret');
}
