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
    required Uri apiBaseUri,
    required String accessKey,
    required String generatedAtUtc,
  }) : appId = appId.trim(),
       title = title.trim(),
       apiBaseUri = _normalizeApiBaseUri(apiBaseUri),
       accessKey = accessKey.trim(),
       generatedAtUtc = generatedAtUtc.trim() {
    if (schemaVersion != currentSchemaVersion) {
      throw MiniProgramPartnerHandoffException(
        'Unsupported MiniProgram partner handoff schema version: '
        '$schemaVersion.',
      );
    }
    _validateSafeIdentifier(appId, 'appId');
    _validateTitle(title);
    _validateAccessKey(accessKey);
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
    final apiBaseUri = Uri.tryParse(_readString(decoded, 'apiBaseUrl'));
    if (apiBaseUri == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff apiBaseUrl is invalid.',
      );
    }
    return MiniProgramPartnerHandoff(
      schemaVersion: _readInt(decoded, 'schemaVersion'),
      appId: _readString(decoded, 'appId'),
      title: _readString(decoded, 'title'),
      apiBaseUri: apiBaseUri,
      accessKey: _readString(decoded, 'accessKey'),
      generatedAtUtc: _readString(decoded, 'generatedAtUtc'),
    );
  }

  static const int currentSchemaVersion = 1;
  static const String documentType = 'mini_program_partner_handoff';

  final int schemaVersion;
  final String appId;
  final String title;
  final Uri apiBaseUri;
  final String accessKey;
  final String generatedAtUtc;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'type': documentType,
      'appId': appId,
      'title': title,
      'apiBaseUrl': apiBaseUri.toString(),
      'accessKey': accessKey,
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

  static int _readInt(Map<dynamic, dynamic> decoded, String key) {
    final value = decoded[key];
    if (value is! int) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff "$key" must be an integer.',
      );
    }
    return value;
  }

  static Uri _normalizeApiBaseUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw MiniProgramPartnerHandoffException(
        'Mini-program endpoint API base URL must be absolute: $uri',
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

  static void _validateAccessKey(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 24 || trimmed.length > 128) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram access keys must be between 24 and 128 characters.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram access keys may only contain letters, numbers, dot, '
        'underscore, and dash.',
      );
    }
  }
}

class MiniProgramPartnerPackageRequest {
  const MiniProgramPartnerPackageRequest({
    required this.appId,
    required this.title,
    required this.apiBaseUri,
    required this.accessKey,
    this.outputPath,
    this.generatedAtUtc,
  });

  final String appId;
  final String title;
  final Uri apiBaseUri;
  final String accessKey;
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
      appId: request.appId.trim(),
      title: request.title.trim(),
      apiBaseUri: request.apiBaseUri,
      accessKey: request.accessKey.trim(),
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
