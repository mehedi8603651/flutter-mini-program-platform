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
    this.title,
    this.backendBaseUri,
    this.backendMode,
    this.policySourcePath,
    this.requestedCache = const <String, Object?>{},
    this.acceptRequestedPolicy = false,
    this.force = false,
  });

  final String projectRootPath;
  final String appId;
  final Uri apiBaseUri;
  final String? title;
  final Uri? backendBaseUri;
  final String? backendMode;
  final String? policySourcePath;
  final Map<String, Object?> requestedCache;
  final bool acceptRequestedPolicy;
  final bool force;
}

class MiniProgramHostEndpointAddResult {
  const MiniProgramHostEndpointAddResult({
    required this.projectRootPath,
    required this.filePath,
    required this.registryFilePath,
    required this.policyFilePath,
    required this.policyResolverFilePath,
    required this.appId,
    required this.title,
    required this.apiBaseUri,
    this.backendBaseUri,
    required this.backendMode,
    required this.endpointCount,
    required this.registryCount,
    required this.created,
    required this.updated,
  });

  final String projectRootPath;
  final String filePath;
  final String registryFilePath;
  final String policyFilePath;
  final String policyResolverFilePath;
  final String appId;
  final String title;
  final Uri apiBaseUri;
  final Uri? backendBaseUri;
  final String backendMode;
  final int endpointCount;
  final int registryCount;
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

    final invocation = <String>[
      'run',
      '-d',
      request.deviceId,
      if (trimmedBackendApiBaseUrl.isNotEmpty)
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
    if (!request.apiBaseUri.hasScheme || request.apiBaseUri.host.isEmpty) {
      throw MiniProgramHostException(
        'Mini-program endpoint API base URL must be absolute: '
        '${request.apiBaseUri}',
      );
    }
    final backendBaseUri = request.backendBaseUri;
    final backendMode = _normalizeBackendMode(
      request.backendMode,
      hasBackendBaseUri: backendBaseUri != null,
    );
    if (backendBaseUri != null &&
        (!backendBaseUri.hasScheme || backendBaseUri.host.isEmpty)) {
      throw MiniProgramHostException(
        'Mini-program backend base URL must be absolute: $backendBaseUri',
      );
    }

    final miniProgramDirectory = Directory(
      p.join(projectRootPath, 'lib', 'mini_program'),
    );
    await miniProgramDirectory.create(recursive: true);
    final file = File(
      p.join(miniProgramDirectory.path, 'mini_program_endpoints.dart'),
    );
    final registryFile = File(
      p.join(miniProgramDirectory.path, 'mini_program_registry.dart'),
    );
    final policyFile = File(
      p.join(miniProgramDirectory.path, 'mini_program_policies.json'),
    );
    final policyResolverFile = File(
      p.join(miniProgramDirectory.path, 'mini_program_policy_resolver.dart'),
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
      backendBaseUri: backendBaseUri == null
          ? null
          : _normalizeUri(backendBaseUri),
      backendMode: backendMode,
    );

    final registryCreated = !await registryFile.exists();
    final existingRegistry = registryCreated
        ? <String, _RegistryRecord>{}
        : _parseGeneratedRegistry(
            await registryFile.readAsString(),
            registryFile.path,
          );
    if (!registryCreated && existingRegistry.isEmpty && !request.force) {
      throw MiniProgramHostException(
        'Existing registry file is not managed by miniprogram tooling: '
        '${registryFile.path}. Pass --force to replace it.',
      );
    }
    final registry = <String, _RegistryRecord>{...existingRegistry};
    for (final appId in endpoints.keys) {
      registry.putIfAbsent(
        appId,
        () => _newRegistryRecord(
          appId: appId,
          title: _titleFromAppId(appId),
          existing: registry,
        ),
      );
    }
    final title = _normalizeTitle(
      request.title ??
          registry[request.appId]?.title ??
          _titleFromAppId(request.appId),
    );
    registry[request.appId] = _RegistryRecord(
      appId: request.appId,
      title: title,
      constantName:
          registry[request.appId]?.constantName ??
          _uniqueFieldName(
            preferred: _dartFieldNameFromAppId(request.appId),
            appId: request.appId,
            existing: registry,
          ),
    );

    final policies = await _upsertPolicyFile(
      policyFile: policyFile,
      appId: request.appId,
      sourcePath: request.policySourcePath,
      requestedCache: request.requestedCache,
      acceptRequestedPolicy: request.acceptRequestedPolicy,
      forceAcceptedPolicy: request.force,
    );
    await policyResolverFile.writeAsString(_buildPolicyResolverFile(policies));
    await registryFile.writeAsString(_buildRegistryFile(registry));
    await file.writeAsString(_buildEndpointFile(endpoints, registry));

    return MiniProgramHostEndpointAddResult(
      projectRootPath: projectRootPath,
      filePath: file.path,
      registryFilePath: registryFile.path,
      policyFilePath: policyFile.path,
      policyResolverFilePath: policyResolverFile.path,
      appId: request.appId,
      title: title,
      apiBaseUri: request.apiBaseUri,
      backendBaseUri: backendBaseUri,
      backendMode: backendMode,
      endpointCount: endpoints.length,
      registryCount: registry.length,
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
      final backendBaseUri = value['backendBaseUri']?.toString().trim();
      final backendMode = _normalizeBackendMode(
        value['backendMode']?.toString(),
        hasBackendBaseUri: backendBaseUri != null && backendBaseUri.isNotEmpty,
      );
      if (apiBaseUri.isEmpty) {
        throw MiniProgramHostException(
          'Generated endpoint entry "$key" is incomplete in $filePath.',
        );
      }
      return MapEntry(
        key.toString(),
        _EndpointRecord(
          apiBaseUri: apiBaseUri,
          backendBaseUri: backendBaseUri == null || backendBaseUri.isEmpty
              ? null
              : backendBaseUri,
          backendMode: backendMode,
        ),
      );
    });
  }

  Map<String, _RegistryRecord> _parseGeneratedRegistry(
    String source,
    String filePath,
  ) {
    if (!source.contains('class MiniPrograms') ||
        !source.contains('MiniProgramInfo')) {
      return <String, _RegistryRecord>{};
    }
    final records = <String, _RegistryRecord>{};
    final pattern = RegExp(
      r'''static\s+const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*MiniProgramInfo\s*\(\s*appId:\s*(['"])(.*?)\2\s*,\s*title:\s*(['"])(.*?)\4\s*,?\s*\)''',
      dotAll: true,
    );
    for (final match in pattern.allMatches(source)) {
      final constantName = match.group(1)!;
      final appId = match.group(3)!.trim();
      final title = match.group(5)!.trim();
      if (appId.isEmpty || title.isEmpty) {
        throw MiniProgramHostException(
          'Generated registry entry "$constantName" is incomplete in '
          '$filePath.',
        );
      }
      records[appId] = _RegistryRecord(
        appId: appId,
        title: title,
        constantName: constantName,
      );
    }
    return records;
  }

  Future<Map<String, Object?>> _upsertPolicyFile({
    required File policyFile,
    required String appId,
    required String? sourcePath,
    required Map<String, Object?> requestedCache,
    required bool acceptRequestedPolicy,
    required bool forceAcceptedPolicy,
  }) async {
    final existing = await policyFile.exists()
        ? _readPolicyDocument(await policyFile.readAsString(), policyFile.path)
        : <String, Object?>{'schemaVersion': 1, 'apps': <String, Object?>{}};
    final apps = _jsonObjectOrEmpty(existing['apps']);
    final existingApp = _jsonObjectOrEmpty(apps[appId]);
    final existingAccepted = existingApp['accepted'] is Map
        ? _jsonObjectOrEmpty(existingApp['accepted'])
        : null;

    apps[appId] = <String, Object?>{
      'requested': <String, Object?>{
        'source': _policySourceName(sourcePath),
        'cache': _deepJsonObjectCopy(requestedCache),
        'permissions': <String, Object?>{},
      },
      'accepted': _acceptedPolicyFor(
        requestedCache: requestedCache,
        existingAccepted: existingAccepted,
        acceptRequestedPolicy: acceptRequestedPolicy,
        forceAcceptedPolicy: forceAcceptedPolicy,
      ),
    };

    final document = <String, Object?>{
      'schemaVersion': 1,
      'apps': _sortedObject(apps),
    };
    await policyFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
    );
    return document;
  }

  Map<String, Object?> _readPolicyDocument(String source, String filePath) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw MiniProgramHostException(
        'Mini-program policy file is invalid in $filePath.',
      );
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != null && schemaVersion != 1) {
      throw MiniProgramHostException(
        'Unsupported mini-program policy schema version in $filePath: '
        '$schemaVersion.',
      );
    }
    return _deepJsonObjectCopy(decoded);
  }

  String _policySourceName(String? sourcePath) {
    final trimmed = sourcePath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'manual';
    }
    return p.basename(trimmed);
  }

  Map<String, Object?> _acceptedPolicyFor({
    required Map<String, Object?> requestedCache,
    required Map<String, Object?>? existingAccepted,
    required bool acceptRequestedPolicy,
    required bool forceAcceptedPolicy,
  }) {
    if (forceAcceptedPolicy || existingAccepted == null) {
      return <String, Object?>{
        'cache': _acceptedCacheFromRequested(requestedCache),
        'permissions': <String, Object?>{},
      };
    }

    final accepted = _deepJsonObjectCopy(existingAccepted);
    final acceptedCache = _jsonObjectOrEmpty(accepted['cache']);
    for (final entry in requestedCache.entries) {
      if (acceptRequestedPolicy || !acceptedCache.containsKey(entry.key)) {
        acceptedCache[entry.key] = _acceptedCacheBucketFromRequest(
          entry.key,
          entry.value,
        );
      }
    }
    return <String, Object?>{
      'cache': _sortedObject(acceptedCache),
      'permissions': accepted['permissions'] is Map
          ? _jsonObjectOrEmpty(accepted['permissions'])
          : <String, Object?>{},
    };
  }

  Map<String, Object?> _acceptedCacheFromRequested(
    Map<String, Object?> requestedCache,
  ) {
    final acceptedCache = <String, Object?>{};
    for (final entry in requestedCache.entries) {
      acceptedCache[entry.key] = _acceptedCacheBucketFromRequest(
        entry.key,
        entry.value,
      );
    }
    return _sortedObject(acceptedCache);
  }

  Map<String, Object?> _acceptedCacheBucketFromRequest(
    String bucket,
    Object? requested,
  ) {
    final requestedPolicy = requested is Map
        ? _jsonObjectOrEmpty(requested)
        : <String, Object?>{};
    return <String, Object?>{
      'enabled': requestedPolicy['enabled'] is bool
          ? requestedPolicy['enabled'] as bool
          : true,
      'maxBytes':
          _positiveInt(requestedPolicy['recommendedMaxBytes']) ??
          _defaultPolicyMaxBytes(bucket),
      'ttlDays':
          _positiveInt(requestedPolicy['recommendedTtlDays']) ??
          _defaultPolicyTtlDays(bucket),
    };
  }

  int _defaultPolicyMaxBytes(String bucket) {
    return switch (bucket) {
      'memory' => 1024 * 1024,
      'data' => 10 * 1024 * 1024,
      'image' => 20 * 1024 * 1024,
      'state' => 1024 * 1024,
      'video' => 50 * 1024 * 1024,
      _ => 1024 * 1024,
    };
  }

  int _defaultPolicyTtlDays(String bucket) {
    return switch (bucket) {
      'memory' => 1,
      'data' => 30,
      'image' => 14,
      'state' => 30,
      'video' => 1,
      _ => 30,
    };
  }

  String _buildPolicyResolverFile(Map<String, Object?> policies) {
    final apps = _jsonObjectOrEmpty(policies['apps']);
    final sortedEntries = apps.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer()
      ..writeln('// Generated by miniprogram tooling.')
      ..writeln('// Runtime uses accepted host policy only.')
      ..writeln()
      ..writeln("import 'package:mini_program_sdk/mini_program_sdk.dart';")
      ..writeln()
      ..writeln('MiniProgramCachePolicy cachePolicyForMiniProgram(')
      ..writeln('  String appId,')
      ..writeln(') {')
      ..writeln('  switch (appId) {');
    for (final entry in sortedEntries) {
      final appPolicy = _jsonObjectOrEmpty(entry.value);
      final accepted = _jsonObjectOrEmpty(appPolicy['accepted']);
      final cache = _jsonObjectOrEmpty(accepted['cache']);
      buffer
        ..writeln('    case ${_dartString(entry.key)}:')
        ..writeln('      return ${_cachePolicyExpression(cache)};');
    }
    buffer
      ..writeln('    default:')
      ..writeln('      return const MiniProgramCachePolicy();')
      ..writeln('  }')
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  String _cachePolicyExpression(Map<String, Object?> acceptedCache) {
    if (acceptedCache.isEmpty) {
      return 'const MiniProgramCachePolicy()';
    }
    final args = <String>[];
    final allowedBuckets = <String>[];
    var totalBytes = 0;

    for (final bucket in _policyCacheBucketOrder) {
      final rawBucketPolicy = acceptedCache[bucket];
      if (rawBucketPolicy is! Map) {
        continue;
      }
      final bucketPolicy = _jsonObjectOrEmpty(rawBucketPolicy);
      final enabled = bucketPolicy['enabled'] is bool
          ? bucketPolicy['enabled'] as bool
          : true;
      if (!enabled) {
        continue;
      }
      final maxBytes = _positiveInt(bucketPolicy['maxBytes']);
      if (maxBytes != null) {
        totalBytes += maxBytes;
        final maxField = _cacheMaxField(bucket);
        if (maxField != null) {
          args.add('$maxField: $maxBytes');
        }
      }
      final ttlDays = _positiveInt(bucketPolicy['ttlDays']);
      final ttlField = _cacheTtlField(bucket);
      if (ttlDays != null && ttlField != null) {
        args.add('$ttlField: Duration(days: $ttlDays)');
      }
      if (_miniProgramRuntimeCacheBuckets.contains(bucket)) {
        allowedBuckets.add(bucket);
      }
    }

    if (totalBytes > 0) {
      args.insert(0, 'maxBytes: $totalBytes');
    }
    final allowedExpressions = allowedBuckets
        .map((bucket) => 'MiniProgramCacheBucket.$bucket')
        .join(', ');
    args.add(
      'allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{'
      '$allowedExpressions}',
    );
    return 'const MiniProgramCachePolicy(${args.join(', ')})';
  }

  String? _cacheMaxField(String bucket) {
    return switch (bucket) {
      'data' => 'maxDataBytes',
      'image' => 'maxImageBytes',
      'state' => 'maxStateBytes',
      'video' => 'maxVideoBytes',
      _ => null,
    };
  }

  String? _cacheTtlField(String bucket) {
    return switch (bucket) {
      'memory' => 'memoryTtl',
      'data' => 'dataTtl',
      'image' => 'imageTtl',
      'state' => 'stateInactiveTtl',
      'video' => 'videoTtl',
      _ => null,
    };
  }

  int? _positiveInt(Object? value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is num && value > 0 && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  Map<String, Object?> _jsonObjectOrEmpty(Object? value) {
    if (value is! Map) {
      return <String, Object?>{};
    }
    return _deepJsonObjectCopy(value);
  }

  Map<String, Object?> _deepJsonObjectCopy(Map<dynamic, dynamic> value) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = _deepJsonValueCopy(entry.value);
    }
    return result;
  }

  Object? _deepJsonValueCopy(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return _deepJsonObjectCopy(value);
    }
    if (value is List) {
      return value.map(_deepJsonValueCopy).toList(growable: false);
    }
    return value.toString();
  }

  Map<String, Object?> _sortedObject(Map<String, Object?> value) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String, Object?>{
      for (final entry in entries) entry.key: entry.value,
    };
  }

  String _buildEndpointFile(
    Map<String, _EndpointRecord> endpoints,
    Map<String, _RegistryRecord> registry,
  ) {
    final sortedEntries = endpoints.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final jsonMetadata = jsonEncode(<String, Object?>{
      for (final entry in sortedEntries)
        entry.key: <String, Object?>{
          'apiBaseUri': entry.value.apiBaseUri,
          if (entry.value.backendBaseUri != null)
            'backendBaseUri': entry.value.backendBaseUri,
          'backendMode': entry.value.backendMode,
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
      ..writeln("import 'mini_program_policy_resolver.dart';")
      ..writeln("import 'mini_program_registry.dart';")
      ..writeln()
      ..writeln(
        'Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {',
      )
      ..writeln('  return <String, MiniProgramEndpoint>{');
    for (final entry in sortedEntries) {
      final registryEntry = registry[entry.key];
      final mapKey = registryEntry == null
          ? _dartString(entry.key)
          : 'MiniPrograms.${registryEntry.constantName}.appId';
      buffer
        ..writeln('    $mapKey: MiniProgramEndpoint.public(')
        ..writeln(
          '      apiBaseUri: Uri.parse(${_dartString(entry.value.apiBaseUri)}),',
        )
        ..writeln('      cachePolicy: cachePolicyForMiniProgram($mapKey),')
        ..writeln('      requestTimeout: const Duration(seconds: 20),');
      if (entry.value.backendBaseUri != null) {
        buffer
          ..writeln('      backend: MiniProgramBackendEndpoint(')
          ..writeln(
            '        baseUri: Uri.parse(${_dartString(entry.value.backendBaseUri!)}),',
          )
          ..writeln('        requestTimeout: const Duration(seconds: 30),')
          ..writeln('      ),');
      }
      buffer.writeln('    ),');
    }
    buffer
      ..writeln('  };')
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  String _buildRegistryFile(Map<String, _RegistryRecord> registry) {
    final sortedEntries = registry.values.toList()
      ..sort((a, b) => a.appId.compareTo(b.appId));
    final buffer = StringBuffer()
      ..writeln('// Generated by miniprogram tooling.')
      ..writeln(
        '// Keep mini-program appId/title pairs in one place when a host app opens',
      )
      ..writeln('// multiple mini-programs.')
      ..writeln()
      ..writeln('class MiniProgramInfo {')
      ..writeln('  const MiniProgramInfo({')
      ..writeln('    required this.appId,')
      ..writeln('    required this.title,')
      ..writeln('  });')
      ..writeln()
      ..writeln('  final String appId;')
      ..writeln('  final String title;')
      ..writeln('}')
      ..writeln()
      ..writeln('class MiniPrograms {')
      ..writeln('  const MiniPrograms._();')
      ..writeln();
    for (final entry in sortedEntries) {
      buffer
        ..writeln('  static const ${entry.constantName} = MiniProgramInfo(')
        ..writeln('    appId: ${_dartString(entry.appId)},')
        ..writeln('    title: ${_dartString(entry.title)},')
        ..writeln('  );')
        ..writeln();
    }
    buffer.writeln('  static const values = <MiniProgramInfo>[');
    for (final entry in sortedEntries) {
      buffer.writeln('    ${entry.constantName},');
    }
    buffer
      ..writeln('  ];')
      ..writeln()
      ..writeln('  static const byAppId = <String, MiniProgramInfo>{');
    for (final entry in sortedEntries) {
      buffer.writeln('    ${_dartString(entry.appId)}: ${entry.constantName},');
    }
    buffer
      ..writeln('  };')
      ..writeln('}')
      ..writeln();
    return buffer.toString();
  }

  String _normalizeUri(Uri uri) =>
      uri.toString().replaceFirst(RegExp(r'/+$'), '');

  String _normalizeBackendMode(
    String? rawMode, {
    required bool hasBackendBaseUri,
  }) {
    final mode = rawMode?.trim().toLowerCase();
    if (mode == null || mode.isEmpty) {
      return hasBackendBaseUri ? 'remote' : 'none';
    }
    if (mode == 'none' || mode == 'remote' || mode == 'local_mock') {
      if (mode == 'none' && hasBackendBaseUri) {
        return 'remote';
      }
      if (mode != 'none' && !hasBackendBaseUri) {
        return 'none';
      }
      return mode;
    }
    throw MiniProgramHostException(
      'Unsupported mini-program backend mode: $rawMode',
    );
  }

  String _dartString(String value) => jsonEncode(value);

  String _normalizeTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const MiniProgramHostException(
        'Mini-program title must not be blank.',
      );
    }
    return trimmed;
  }

  _RegistryRecord _newRegistryRecord({
    required String appId,
    required String title,
    required Map<String, _RegistryRecord> existing,
  }) {
    return _RegistryRecord(
      appId: appId,
      title: _normalizeTitle(title),
      constantName: _uniqueFieldName(
        preferred: _dartFieldNameFromAppId(appId),
        appId: appId,
        existing: existing,
      ),
    );
  }

  String _uniqueFieldName({
    required String preferred,
    required String appId,
    required Map<String, _RegistryRecord> existing,
  }) {
    final used = existing.values
        .where((entry) => entry.appId != appId)
        .map((entry) => entry.constantName)
        .toSet();
    if (!used.contains(preferred)) {
      return preferred;
    }
    var suffix = 2;
    while (used.contains('$preferred$suffix')) {
      suffix += 1;
    }
    return '$preferred$suffix';
  }

  String _dartFieldNameFromAppId(String appId) {
    final parts = appId
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'miniProgram';
    }
    final first = parts.first.toLowerCase();
    final rest = parts
        .skip(1)
        .map(
          (part) =>
              part.substring(0, 1).toUpperCase() +
              part.substring(1).toLowerCase(),
        );
    final candidate = <String>[first, ...rest].join();
    final normalized = RegExp(r'^[A-Za-z_$]').hasMatch(candidate)
        ? candidate
        : 'miniProgram$candidate';
    return _dartKeywords.contains(normalized)
        ? '${normalized}MiniProgram'
        : normalized;
  }

  String _titleFromAppId(String appId) {
    final words = appId
        .split(RegExp(r'[._-]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .toList();
    return words.isEmpty ? appId : words.join(' ');
  }

  void _validateSafeIdentifier(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw MiniProgramHostException('$label is invalid: $value');
    }
  }
}

const List<String> _policyCacheBucketOrder = <String>[
  'memory',
  'data',
  'image',
  'state',
  'video',
];

const Set<String> _miniProgramRuntimeCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
};

const Set<String> _dartKeywords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'with',
  'while',
  'yield',
};

class _EndpointRecord {
  const _EndpointRecord({
    required this.apiBaseUri,
    this.backendBaseUri,
    required this.backendMode,
  });

  final String apiBaseUri;
  final String? backendBaseUri;
  final String backendMode;
}

class _RegistryRecord {
  const _RegistryRecord({
    required this.appId,
    required this.title,
    required this.constantName,
  });

  final String appId;
  final String title;
  final String constantName;
}
