import 'constants.dart';
import 'errors.dart';

void validatePartnerHandoffSchemaVersion(int schemaVersion) {
  if (schemaVersion != 1 &&
      schemaVersion != legacyMiniProgramPartnerHandoffSchemaVersion &&
      schemaVersion != currentMiniProgramPartnerHandoffSchemaVersion) {
    throw MiniProgramPartnerHandoffException(
      'Unsupported MiniProgram partner handoff schema version: '
      '$schemaVersion.',
    );
  }
}

String readPartnerHandoffString(Map<dynamic, dynamic> decoded, String key) {
  final value = decoded[key];
  if (value is! String || value.trim().isEmpty) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff is missing "$key".',
    );
  }
  return value.trim();
}

String? readOptionalPartnerHandoffString(
  Map<dynamic, dynamic> decoded,
  String key,
) {
  final value = decoded[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff "$key" must be a string.',
    );
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int readPartnerHandoffInt(Map<dynamic, dynamic> decoded, String key) {
  final value = decoded[key];
  if (value is! int) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff "$key" must be an integer.',
    );
  }
  return value;
}

Uri normalizePartnerHandoffArtifactBaseUri(Uri? uri) {
  if (uri == null) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requires artifactBaseUrl.',
    );
  }
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw MiniProgramPartnerHandoffException(
      'Mini-program artifact base URL must be absolute: $uri',
    );
  }
  return Uri.parse(uri.toString().replaceFirst(RegExp(r'/+$'), ''));
}

void validatePartnerHandoffSafeIdentifier(String value, String label) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
    throw MiniProgramPartnerHandoffException('$label is invalid: $value');
  }
}

void validatePartnerHandoffTitle(String value) {
  if (value.trim().isEmpty) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff title must not be blank.',
    );
  }
}

void validatePartnerHandoffTimestamp(String generatedAtUtc) {
  if (DateTime.tryParse(generatedAtUtc) == null) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff generatedAtUtc must be an ISO timestamp.',
    );
  }
}
