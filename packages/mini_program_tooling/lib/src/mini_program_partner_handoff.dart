import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class MiniProgramPartnerHandoffException implements Exception {
  const MiniProgramPartnerHandoffException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramPartnerHandoff {
  MiniProgramPartnerHandoff({
    this.schemaVersion = currentSchemaVersion,
    required String appId,
    required String title,
    Uri? artifactBaseUri,
    Uri? apiBaseUri,
    required String generatedAtUtc,
  }) : appId = appId.trim(),
       title = title.trim(),
       artifactBaseUri = _normalizeArtifactBaseUri(
         artifactBaseUri ?? apiBaseUri,
       ),
       generatedAtUtc = generatedAtUtc.trim() {
    if (schemaVersion != 1 &&
        schemaVersion != legacySchemaVersion &&
        schemaVersion != currentSchemaVersion) {
      throw MiniProgramPartnerHandoffException(
        'Unsupported MiniProgram partner handoff schema version: '
        '$schemaVersion.',
      );
    }
    _validateSafeIdentifier(appId, 'appId');
    _validateTitle(title);
    if (DateTime.tryParse(this.generatedAtUtc) == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff generatedAtUtc must be an ISO timestamp.',
      );
    }
  }

  factory MiniProgramPartnerHandoff.fromJson(Object? decoded) {
    if (decoded is! Map) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff file must contain a JSON object.',
      );
    }
    final type = _readString(decoded, 'type');
    if (type != documentType) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff type must be "$documentType".',
      );
    }
    final schemaVersion = _readInt(decoded, 'schemaVersion');
    final rawArtifactBaseUrl =
        _readOptionalString(decoded, 'artifactBaseUrl') ??
        _readOptionalString(decoded, 'apiBaseUrl');
    if (rawArtifactBaseUrl == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff is missing "artifactBaseUrl".',
      );
    }
    final artifactBaseUri = Uri.tryParse(rawArtifactBaseUrl);
    if (artifactBaseUri == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff artifactBaseUrl is invalid.',
      );
    }
    return MiniProgramPartnerHandoff(
      schemaVersion: schemaVersion,
      appId: _readString(decoded, 'appId'),
      title: _readString(decoded, 'title'),
      artifactBaseUri: artifactBaseUri,
      generatedAtUtc: _readString(decoded, 'generatedAtUtc'),
    );
  }

  static const int legacySchemaVersion = 2;
  static const int currentSchemaVersion = 3;
  static const String documentType = 'mini_program_partner_handoff';

  final int schemaVersion;
  final String appId;
  final String title;
  final Uri artifactBaseUri;
  final String generatedAtUtc;

  Uri get apiBaseUri => artifactBaseUri;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'type': documentType,
      'appId': appId,
      'title': title,
      'artifactBaseUrl': artifactBaseUri.toString(),
      'generatedAtUtc': generatedAtUtc,
    };
  }

  static String _readString(Map<dynamic, dynamic> decoded, String key) {
    final value = decoded[key];
    if (value is! String || value.trim().isEmpty) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff is missing "$key".',
      );
    }
    return value.trim();
  }

  static String? _readOptionalString(
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

  static int _readInt(Map<dynamic, dynamic> decoded, String key) {
    final value = decoded[key];
    if (value is! int) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff "$key" must be an integer.',
      );
    }
    return value;
  }

  static Uri _normalizeArtifactBaseUri(Uri? uri) {
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

  static void _validateSafeIdentifier(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw MiniProgramPartnerHandoffException('$label is invalid: $value');
    }
  }

  static void _validateTitle(String value) {
    if (value.trim().isEmpty) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff title must not be blank.',
      );
    }
  }
}

class MiniProgramPartnerPackageRequest {
  const MiniProgramPartnerPackageRequest({
    required this.appId,
    required this.title,
    this.schemaVersion = MiniProgramPartnerHandoff.currentSchemaVersion,
    this.artifactBaseUri,
    this.apiBaseUri,
    this.outputPath,
    this.generatedAtUtc,
  });

  final String appId;
  final String title;
  final int schemaVersion;
  final Uri? artifactBaseUri;
  final Uri? apiBaseUri;
  final String? outputPath;
  final DateTime? generatedAtUtc;
}

class MiniProgramPartnerPackageResult {
  const MiniProgramPartnerPackageResult({
    required this.filePath,
    required this.handoff,
  });

  final String filePath;
  final MiniProgramPartnerHandoff handoff;
}

class MiniProgramPartnerHandoffController {
  const MiniProgramPartnerHandoffController();

  Future<MiniProgramPartnerPackageResult> createPackage(
    MiniProgramPartnerPackageRequest request,
  ) async {
    final handoff = MiniProgramPartnerHandoff(
      schemaVersion: request.schemaVersion,
      appId: request.appId.trim(),
      title: request.title.trim(),
      artifactBaseUri: request.artifactBaseUri,
      apiBaseUri: request.apiBaseUri,
      generatedAtUtc: (request.generatedAtUtc ?? DateTime.now().toUtc())
          .toIso8601String(),
    );
    final outputPath = p.normalize(
      p.absolute(
        request.outputPath?.trim().isNotEmpty == true
            ? request.outputPath!.trim()
            : '${handoff.appId}.partner.json',
      ),
    );
    await Directory(p.dirname(outputPath)).create(recursive: true);
    await File(outputPath).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(handoff.toJson())}\n',
    );
    return MiniProgramPartnerPackageResult(
      filePath: outputPath,
      handoff: handoff,
    );
  }

  Future<MiniProgramPartnerHandoff> readPackage(String filePath) async {
    final normalizedPath = p.normalize(p.absolute(filePath));
    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff file does not exist: $normalizedPath',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    return MiniProgramPartnerHandoff.fromJson(decoded);
  }
}
