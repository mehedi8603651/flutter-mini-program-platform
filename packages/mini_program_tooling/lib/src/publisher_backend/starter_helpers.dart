part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterSharedHelpers on PublisherBackendStarter {
  Future<String> _requireMiniProgramRoot(String rawRootPath) async {
    final rootPath = p.normalize(p.absolute(rawRootPath));
    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $rootPath',
      );
    }
    return rootPath;
  }

  Future<void> _assertMockBackendPaths(String backendRootPath) async {
    final serverFile = File(p.join(backendRootPath, 'bin', 'server.dart'));
    final dataDirectory = Directory(p.join(backendRootPath, 'data'));
    if (!await serverFile.exists() || !await dataDirectory.exists()) {
      throw PublisherBackendException(
        'Publisher mock backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template mock` first.',
      );
    }
  }

  Future<void> _assertAwsBackendPaths(String backendRootPath) async {
    final templateFile = File(p.join(backendRootPath, 'template.yaml'));
    final handlerFile = File(p.join(backendRootPath, 'src', 'handler.mjs'));
    if (!await templateFile.exists() || !await handlerFile.exists()) {
      throw const PublisherBackendException(
        'AWS Lambda publisher backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template aws-lambda` first.',
      );
    }
  }

  Future<void> _assertFirebaseBackendPaths(String backendRootPath) async {
    if (!await _firebaseBackendPathsExist(backendRootPath)) {
      throw const PublisherBackendException(
        'Firebase Functions publisher backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }
  }

  Future<void> _writeManagedFile({
    required String filePath,
    required String contents,
    required bool force,
    required List<String> createdPaths,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final existing = await file.readAsString();
      if (existing == contents) {
        return;
      }
      if (!force) {
        throw PublisherBackendException(
          'Publisher backend scaffold would overwrite an existing file. '
          'Re-run with --force if you want to replace scaffold-managed files.\n'
          '$filePath',
        );
      }
    } else {
      createdPaths.add(filePath);
    }
    await file.writeAsString(contents);
  }

  Future<void> _writeLauncherScript({
    required String launcherScriptPath,
    required String backendRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final serverScriptPath = p.join(backendRootPath, 'bin', 'server.dart');
    final content = Platform.isWindows
        ? <String>[
            '@echo off',
            'setlocal',
            'cd /d ${_quoteForCmd(backendRootPath)}',
            '${_quoteForCmd(Platform.resolvedExecutable)} '
                '${_quoteForCmd(serverScriptPath)} '
                '${_quoteForCmd('--host=0.0.0.0')} '
                '${_quoteForCmd('--port=$port')} '
                '1>>${_quoteForCmd(stdoutLogPath)} '
                '2>>${_quoteForCmd(stderrLogPath)}',
          ].join('\r\n')
        : <String>[
            '#!/usr/bin/env sh',
            'set -eu',
            'cd ${_quoteForSh(backendRootPath)}',
            'exec ${_quoteForSh(Platform.resolvedExecutable)} '
                '${_quoteForSh(serverScriptPath)} '
                '${_quoteForSh('--host=0.0.0.0')} '
                '${_quoteForSh('--port=$port')} '
                '>>${_quoteForSh(stdoutLogPath)} '
                '2>>${_quoteForSh(stderrLogPath)}',
            '',
          ].join('\n');
    await File(launcherScriptPath).writeAsString(content);
  }

  Future<Directory> _ensureStateDirectory(String miniProgramRootPath) async {
    final directory = Directory(p.join(miniProgramRootPath, '.mini_program'));
    await directory.create(recursive: true);
    return directory;
  }

  String _statePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.local.json',
  );

  Future<PublisherBackendState?> _readState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.local.json must contain a JSON object.',
      );
    }
    return PublisherBackendState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeState(
    String miniProgramRootPath,
    PublisherBackendState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.local.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _awsStatePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.aws.json',
  );

  Future<void> _writeAwsState(
    String miniProgramRootPath,
    PublisherBackendAwsState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.aws.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearAwsState(String miniProgramRootPath) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _writeFirebaseState(
    String miniProgramRootPath,
    PublisherBackendFirebaseState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(
      p.join(directory.path, 'publisher_backend.firebase.json'),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearFirebaseState(String miniProgramRootPath) async {
    final file = File(_firebaseStatePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _writeFirebaseEnvFile(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final file = File(p.join(settings.functionsRootPath, '.env'));
    final lines = <String>[];
    if (await file.exists()) {
      for (final line in const LineSplitter().convert(
        await file.readAsString(),
      )) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('FUNCTION_REGION=') ||
            trimmed.startsWith('PUBLISHER_BACKEND_REGION=') ||
            trimmed.startsWith('MINI_PROGRAM_ID=') ||
            trimmed.startsWith('PUBLISHER_AUTH_WEB_API_KEY=') ||
            trimmed.startsWith('FIREBASE_AUTH_WEB_API_KEY=')) {
          continue;
        }
        lines.add(line);
      }
    } else {
      await file.parent.create(recursive: true);
    }
    lines
      ..add('PUBLISHER_BACKEND_REGION=${settings.region}')
      ..add('MINI_PROGRAM_ID=${settings.miniProgramId}');
    if (settings.authWebApiKey?.trim().isNotEmpty == true) {
      lines.add('PUBLISHER_AUTH_WEB_API_KEY=${settings.authWebApiKey!.trim()}');
    }
    await file.writeAsString('${lines.join('\n')}\n');
  }

  int _compareFirestoreLogicalRecords(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final collectionCompare = (left['collection']?.toString() ?? '').compareTo(
      right['collection']?.toString() ?? '',
    );
    if (collectionCompare != 0) {
      return collectionCompare;
    }
    return (left['documentId']?.toString() ?? '').compareTo(
      right['documentId']?.toString() ?? '',
    );
  }

  String? _firestoreDocumentPathFromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    const marker = '/documents/';
    final markerIndex = name.indexOf(marker);
    if (markerIndex == -1) {
      return null;
    }
    return name.substring(markerIndex + marker.length);
  }

  String? _firestoreDocumentIdFromName(String? name) {
    final path = _firestoreDocumentPathFromName(name);
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return path.split('/').last;
  }

  String _resolveFirebaseDataExportPath(
    _PublisherBackendFirebaseSettings settings,
    String? outputPath,
  ) {
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(outputPath.trim()));
    }
    final timestamp = _compactUtcTimestamp(_clock().toUtc());
    final fileName =
        '${_safeFileSegment(settings.miniProgramId)}-'
        '${_safeFileSegment(settings.environmentName)}-'
        'data-export-$timestamp.json';
    return p.normalize(
      p.absolute(p.join(settings.backendRootPath, 'exports', fileName)),
    );
  }

  Uri _firestoreDocumentUri({
    required String projectId,
    required String documentPath,
  }) {
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/'
          '${_encodeFirestorePath(documentPath)}',
    );
  }

  Uri _firestoreCollectionUri({
    required String projectId,
    required String collectionPath,
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/'
          '${_encodeFirestorePath(collectionPath)}',
      queryParameters,
    );
  }

  String _encodeFirestorePath(String path) {
    return path
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
  }

  Future<Map<String, Object?>> _readJsonObjectFile(
    String filePath, {
    required String label,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw PublisherBackendException(
        'Publisher backend sample data is missing: $label',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'Publisher backend sample data must be a JSON object: $label',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String _resolveAwsDataExportPath(
    _PublisherBackendAwsSettings settings,
    String? outputPath,
  ) {
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(outputPath.trim()));
    }
    final timestamp = _compactUtcTimestamp(_clock().toUtc());
    final fileName =
        '${_safeFileSegment(settings.miniProgramId)}-'
        '${_safeFileSegment(settings.environmentName)}-'
        'data-export-$timestamp.json';
    return p.normalize(
      p.absolute(p.join(settings.backendRootPath, 'exports', fileName)),
    );
  }

  String _compactUtcTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}'
        '${two(value.month)}'
        '${two(value.day)}'
        'T'
        '${two(value.hour)}'
        '${two(value.minute)}'
        '${two(value.second)}'
        'Z';
  }

  String _safeFileSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    return sanitized.isEmpty ? 'mini_program' : sanitized;
  }

  String _safeFirestoreDocumentId(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }

  String? _redemptionRecordValue(Map<String, Object?> record, String key) {
    final direct = record[key]?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final data = record['data'];
    if (data is Map) {
      final value = data[key]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    final payload = record['payload'];
    if (payload is Map) {
      final value = payload[key]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _hasDynamoDbRequestItems(Map<String, Object?> requestItems) {
    for (final value in requestItems.values) {
      if (value is List && value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String? _responseStatus(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final status = decoded['status']?.toString().trim();
        return status == null || status.isEmpty ? null : status;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _resolveBackendRoute(Uri baseUri, String path) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBaseUrl).resolve(relativePath);
  }

  String _quoteForCmd(String value) => '"${value.replaceAll('"', '""')}"';

  String _quoteForSh(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
