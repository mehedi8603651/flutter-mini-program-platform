import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef MiniProgramHostProcessRunner =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

Future<int> _defaultMiniProgramHostProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

class MiniProgramHostException implements Exception {
  const MiniProgramHostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramHostRunRequest {
  const MiniProgramHostRunRequest({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
}

class MiniProgramHostRunResult {
  const MiniProgramHostRunResult({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
    required this.invocation,
    required this.exitCode,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
  final List<String> invocation;
  final int exitCode;
}

class MiniProgramHostEndpointAddRequest {
  const MiniProgramHostEndpointAddRequest({
    required this.projectRootPath,
    required this.appId,
    required this.apiBaseUri,
    required this.accessKey,
    this.force = false,
  });

  final String projectRootPath;
  final String appId;
  final Uri apiBaseUri;
  final String accessKey;
  final bool force;
}

class MiniProgramHostEndpointAddResult {
  const MiniProgramHostEndpointAddResult({
    required this.projectRootPath,
    required this.filePath,
    required this.appId,
    required this.apiBaseUri,
    required this.endpointCount,
    required this.created,
    required this.updated,
  });

  final String projectRootPath;
  final String filePath;
  final String appId;
  final Uri apiBaseUri;
  final int endpointCount;
  final bool created;
  final bool updated;
}

class MiniProgramHostController {
  MiniProgramHostController({
    MiniProgramHostProcessRunner processRunner =
        _defaultMiniProgramHostProcessRunner,
  }) : _processRunner = processRunner;

  final MiniProgramHostProcessRunner _processRunner;

  Future<MiniProgramHostRunResult> run(
    MiniProgramHostRunRequest request,
  ) async {
    final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
    final projectDirectory = Directory(projectRootPath);
    if (!await projectDirectory.exists()) {
      throw MiniProgramHostException(
        'Flutter host project root does not exist: $projectRootPath',
      );
    }

    final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostException(
        'Flutter host project is missing pubspec.yaml: $projectRootPath',
      );
    }

    final generatedRuntimeSetup = File(
      p.join(
        projectRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    );
    if (!await generatedRuntimeSetup.exists()) {
      throw const MiniProgramHostException(
        'The generated mini-program embedding adapter was not found. Run '
        '`miniprogram embed init` in the host Flutter app first.',
      );
    }

    final trimmedBackendApiBaseUrl = request.backendApiBaseUrl.trim();
    if (trimmedBackendApiBaseUrl.isEmpty) {
      throw const MiniProgramHostException(
        'A backend API base URL is required to run the embedded host app.',
      );
    }

    final invocation = <String>[
      'run',
      '-d',
      request.deviceId,
      '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=$trimmedBackendApiBaseUrl',
    ];
    final exitCode = await _processRunner(
      'flutter',
      invocation,
      workingDirectory: projectRootPath,
    );

    return MiniProgramHostRunResult(
      projectRootPath: projectRootPath,
      deviceId: request.deviceId,
      backendApiBaseUrl: trimmedBackendApiBaseUrl,
      invocation: invocation,
      exitCode: exitCode,
    );
  }

  Future<MiniProgramHostEndpointAddResult> addEndpoint(
    MiniProgramHostEndpointAddRequest request,
  ) async {
    final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
    final projectDirectory = Directory(projectRootPath);
    if (!await projectDirectory.exists()) {
      throw MiniProgramHostException(
        'Flutter host project root does not exist: $projectRootPath',
      );
    }
    final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostException(
        'Flutter host project is missing pubspec.yaml: $projectRootPath',
      );
    }
    _validateSafeIdentifier(request.appId, 'appId');
    _validateAccessKey(request.accessKey);
    if (!request.apiBaseUri.hasScheme || request.apiBaseUri.host.isEmpty) {
      throw MiniProgramHostException(
        'Mini-program endpoint API base URL must be absolute: '
        '${request.apiBaseUri}',
      );
    }

    final miniProgramDirectory = Directory(
      p.join(projectRootPath, 'lib', 'mini_program'),
    );
    await miniProgramDirectory.create(recursive: true);
    final file = File(
      p.join(miniProgramDirectory.path, 'mini_program_endpoints.dart'),
    );
    final created = !await file.exists();
    final existingEndpoints = created
        ? <String, _EndpointRecord>{}
        : _parseGeneratedEndpoints(await file.readAsString(), file.path);
    if (!created && existingEndpoints.isEmpty && !request.force) {
      throw MiniProgramHostException(
        'Existing endpoint file is not managed by miniprogram tooling: '
        '${file.path}. Pass --force to replace it.',
      );
    }
    final updated = existingEndpoints.containsKey(request.appId);
    final endpoints = request.force && !created
        ? <String, _EndpointRecord>{...existingEndpoints}
        : existingEndpoints;
    endpoints[request.appId] = _EndpointRecord(
      apiBaseUri: _normalizeUri(request.apiBaseUri),
      accessKey: request.accessKey.trim(),
    );
    await file.writeAsString(_buildEndpointFile(endpoints));

    return MiniProgramHostEndpointAddResult(
      projectRootPath: projectRootPath,
      filePath: file.path,
      appId: request.appId,
      apiBaseUri: request.apiBaseUri,
      endpointCount: endpoints.length,
      created: created,
      updated: updated,
    );
  }

  Map<String, _EndpointRecord> _parseGeneratedEndpoints(
    String source,
    String filePath,
  ) {
    final match = RegExp(
      r'// BEGIN MINI_PROGRAM_ENDPOINTS_JSON\s*// ([\s\S]*?)\s*// END MINI_PROGRAM_ENDPOINTS_JSON',
    ).firstMatch(source);
    if (match == null) {
      return <String, _EndpointRecord>{};
    }
    final encodedJson = match.group(1)!.trim();
    final decoded = jsonDecode(encodedJson);
    if (decoded is! Map) {
      throw MiniProgramHostException(
        'Generated endpoint metadata is invalid in $filePath.',
      );
    }
    return decoded.map((key, value) {
      if (value is! Map) {
        throw MiniProgramHostException(
          'Generated endpoint entry "$key" is invalid in $filePath.',
        );
      }
      final apiBaseUri = value['apiBaseUri']?.toString().trim() ?? '';
      final accessKey = value['accessKey']?.toString().trim() ?? '';
      if (apiBaseUri.isEmpty || accessKey.isEmpty) {
        throw MiniProgramHostException(
          'Generated endpoint entry "$key" is incomplete in $filePath.',
        );
      }
      return MapEntry(
        key.toString(),
        _EndpointRecord(apiBaseUri: apiBaseUri, accessKey: accessKey),
      );
    });
  }

  String _buildEndpointFile(Map<String, _EndpointRecord> endpoints) {
    final sortedEntries = endpoints.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final jsonMetadata = jsonEncode(<String, Object?>{
      for (final entry in sortedEntries)
        entry.key: <String, String>{
          'apiBaseUri': entry.value.apiBaseUri,
          'accessKey': entry.value.accessKey,
        },
    });
    final buffer = StringBuffer()
      ..writeln('// Generated by `miniprogram host endpoint add`.')
      ..writeln('// Keep endpoint ownership in host config, not button code.')
      ..writeln('// BEGIN MINI_PROGRAM_ENDPOINTS_JSON')
      ..writeln('// $jsonMetadata')
      ..writeln('// END MINI_PROGRAM_ENDPOINTS_JSON')
      ..writeln()
      ..writeln("import 'package:mini_program_sdk/mini_program_sdk.dart';")
      ..writeln()
      ..writeln(
        'Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {',
      )
      ..writeln('  return <String, MiniProgramEndpoint>{');
    for (final entry in sortedEntries) {
      buffer
        ..writeln('    ${_dartString(entry.key)}: MiniProgramEndpoint(')
        ..writeln(
          '      apiBaseUri: Uri.parse(${_dartString(entry.value.apiBaseUri)}),',
        )
        ..writeln('      accessKey: ${_dartString(entry.value.accessKey)},')
        ..writeln('    ),');
    }
    buffer
      ..writeln('  };')
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  String _normalizeUri(Uri uri) =>
      uri.toString().replaceFirst(RegExp(r'/+$'), '');

  String _dartString(String value) => jsonEncode(value);

  void _validateSafeIdentifier(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw MiniProgramHostException('$label is invalid: $value');
    }
  }

  void _validateAccessKey(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 24 || trimmed.length > 128) {
      throw const MiniProgramHostException(
        'MiniProgram access keys must be between 24 and 128 characters.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw const MiniProgramHostException(
        'MiniProgram access keys may only contain letters, numbers, dot, '
        'underscore, and dash.',
      );
    }
  }
}

class _EndpointRecord {
  const _EndpointRecord({required this.apiBaseUri, required this.accessKey});

  final String apiBaseUri;
  final String accessKey;
}
