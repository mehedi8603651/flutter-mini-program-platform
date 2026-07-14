import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_cli_state.dart';

class MiniProgramWorkflowStatusRequest {
  const MiniProgramWorkflowStatusRequest({
    required this.workspacePath,
    this.environmentName,
    this.remote = false,
  });

  final String workspacePath;
  final String? environmentName;
  final bool remote;
}

class MiniProgramWorkflowStatusResult {
  const MiniProgramWorkflowStatusResult(this.json);

  final Map<String, Object?> json;

  bool get ready => json['ready'] == true;

  String get severity => json['severity']?.toString() ?? 'warning';
}

class MiniProgramWorkflowStatusController {
  const MiniProgramWorkflowStatusController({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
    LocalBackendController backendController = const LocalBackendController(),
  }) : _stateStore = stateStore,
       _validator = validator,
       _backendController = backendController;

  final LocalCliStateStore _stateStore;
  final DeliveryRepositoryValidator _validator;
  final LocalBackendController _backendController;

  Future<MiniProgramWorkflowStatusResult> inspect(
    MiniProgramWorkflowStatusRequest request,
  ) async {
    final workspacePath = p.normalize(p.absolute(request.workspacePath));
    final generatedAtUtc = DateTime.now().toUtc().toIso8601String();
    final workspace = await _inspectWorkspace(workspacePath);
    final miniProgram = await _inspectMiniProgram(workspacePath, workspace);
    final hostApp = await _inspectHostApp(workspacePath, workspace);
    final environment = await _inspectEnvironment(
      workspacePath: workspacePath,
      explicitEnvironmentName: request.environmentName,
    );
    final backend = await _inspectBackend(workspacePath);
    await _inspectValidation(
      workspacePath: workspacePath,
      workspace: workspace,
      miniProgram: miniProgram,
      backend: backend,
    );
    final remote = _inspectRemote(request.remote);
    final nextActions = _buildNextActions(
      workspace: workspace,
      miniProgram: miniProgram,
      hostApp: hostApp,
      environment: environment,
      remote: remote,
    );
    final severity = _computeSeverity(
      workspace: workspace,
      miniProgram: miniProgram,
      hostApp: hostApp,
      environment: environment,
      remote: remote,
    );
    final ready = severity == 'ok';

    return MiniProgramWorkflowStatusResult(<String, Object?>{
      'schemaVersion': 1,
      'command': 'workflow status',
      'generatedAtUtc': generatedAtUtc,
      'workspace': workspace,
      'environment': environment,
      'miniProgram': miniProgram,
      'hostApp': hostApp,
      'backend': backend,
      'remote': remote,
      'ready': ready,
      'severity': severity,
      'nextActions': nextActions,
    });
  }

  Future<Map<String, Object?>> _inspectWorkspace(String workspacePath) async {
    final directory = Directory(workspacePath);
    final exists = await directory.exists();
    final manifestExists = await File(
      p.join(workspacePath, 'manifest.json'),
    ).exists();
    final pubspecExists = await File(
      p.join(workspacePath, 'pubspec.yaml'),
    ).exists();
    final runtimeSetupExists = await File(
      p.join(
        workspacePath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    ).exists();
    final type = !exists
        ? 'unknown'
        : manifestExists
        ? 'mini_program'
        : pubspecExists && runtimeSetupExists
        ? 'host_app'
        : 'unknown';
    return <String, Object?>{
      'path': workspacePath,
      'exists': exists,
      'type': type,
    };
  }

  Future<Map<String, Object?>> _inspectMiniProgram(
    String workspacePath,
    Map<String, Object?> workspace,
  ) async {
    if (workspace['type'] != 'mini_program') {
      return <String, Object?>{'detected': false};
    }

    final manifestPath = p.join(workspacePath, 'manifest.json');
    Map<String, dynamic>? manifest;
    Object? manifestError;
    try {
      manifest = await _readJsonObject(File(manifestPath));
    } catch (error) {
      manifestError = error;
    }
    final appId = manifest?['id']?.toString();
    final entry = manifest?['entry']?.toString();
    final version = manifest?['version']?.toString();
    final screenFormat = _resolveMiniProgramScreenFormat(manifest);
    final screenSchemaVersion = _resolveMiniProgramScreenSchemaVersion(
      manifest,
    );
    final sourceRootPath = p.join(workspacePath, 'mp');
    final outputRootPath = _resolveMiniProgramBuildOutputPath(
      workspacePath: workspacePath,
      screenFormat: screenFormat,
    );
    final screensDirectory = Directory(p.join(outputRootPath, 'screens'));
    final buildScreens = await screensDirectory.exists()
        ? await screensDirectory
              .list()
              .where(
                (entity) => entity is File && entity.path.endsWith('.json'),
              )
              .length
        : 0;
    final entryScreenPath = entry == null
        ? null
        : p.join(screensDirectory.path, '$entry.json');
    final entryScreenExists = entryScreenPath == null
        ? false
        : await File(entryScreenPath).exists();
    final partnerPackages = await _findPartnerPackages(workspacePath);
    final backendUsage = await _detectMiniProgramBackendUsage(workspacePath);
    final publisherBackendStarter = await _inspectPublisherBackendStarter(
      workspacePath,
    );

    return <String, Object?>{
      'detected': true,
      'manifestPath': manifestPath,
      'manifestExists': manifest != null,
      if (manifestError != null) 'manifestError': manifestError.toString(),
      'appId': appId,
      'version': version,
      'entry': entry,
      'screenFormat': screenFormat,
      'screenSchemaVersion': screenSchemaVersion,
      'sourceRootPath': sourceRootPath,
      'sourceRootExists': await Directory(sourceRootPath).exists(),
      'outputRootPath': outputRootPath,
      'build': <String, Object?>{
        'screensDirectory': screensDirectory.path,
        'exists': buildScreens > 0,
        'screenCount': buildScreens,
        'entryScreenPath': entryScreenPath,
        'entryScreenExists': entryScreenExists,
      },
      'validation': <String, Object?>{
        'status': 'not_run',
        'reason': 'Validation has not been checked yet.',
      },
      'partnerPackages': partnerPackages,
      'backendUsage': backendUsage,
      'publisherBackendStarter': publisherBackendStarter,
    };
  }

  String _resolveMiniProgramScreenFormat(Map<String, dynamic>? manifest) {
    final rawScreenFormat = manifest?['screenFormat'];
    if (rawScreenFormat == null) {
      return 'mp';
    }
    final screenFormat = rawScreenFormat.toString().trim();
    return screenFormat.isEmpty ? 'mp' : screenFormat;
  }

  int? _resolveMiniProgramScreenSchemaVersion(Map<String, dynamic>? manifest) {
    final rawVersion = manifest?['screenSchemaVersion'];
    if (rawVersion is int) {
      return rawVersion;
    }
    if (rawVersion is num) {
      return rawVersion.toInt();
    }
    if (rawVersion is String) {
      return int.tryParse(rawVersion.trim());
    }
    return null;
  }

  String _resolveMiniProgramBuildOutputPath({
    required String workspacePath,
    required String screenFormat,
  }) {
    if (screenFormat != 'mp') {
      return p.join(workspacePath, screenFormat, '.build');
    }
    return p.join(workspacePath, 'mp', '.build');
  }

  Future<Map<String, Object?>> _inspectHostApp(
    String workspacePath,
    Map<String, Object?> workspace,
  ) async {
    if (workspace['type'] != 'host_app') {
      return <String, Object?>{'detected': false};
    }

    final runtimeSetupPath = p.join(
      workspacePath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    );
    final launcherPath = p.join(
      workspacePath,
      'lib',
      'mini_program',
      'mini_program_launcher.dart',
    );
    final endpointPath = p.join(
      workspacePath,
      'lib',
      'mini_program',
      'mini_program_endpoints.dart',
    );
    final registryPath = p.join(
      workspacePath,
      'lib',
      'mini_program',
      'mini_program_registry.dart',
    );
    final pubspecPath = p.join(workspacePath, 'pubspec.yaml');
    final endpoints = await _readEndpointMetadata(File(endpointPath));
    final registryEntries = await _readRegistryMetadata(File(registryPath));
    return <String, Object?>{
      'detected': true,
      'pubspecPath': pubspecPath,
      'runtimeSetupExists': await File(runtimeSetupPath).exists(),
      'runtimeSetupPath': runtimeSetupPath,
      'launcherExists': await File(launcherPath).exists(),
      'launcherPath': launcherPath,
      'endpointMapExists': await File(endpointPath).exists(),
      'endpointMapPath': endpointPath,
      'endpointCount': endpoints.length,
      'endpointAppIds': endpoints.keys.toList()..sort(),
      'registryExists': await File(registryPath).exists(),
      'registryPath': registryPath,
      'registryCount': registryEntries.length,
      'registryAppIds': registryEntries.keys.toList()..sort(),
      'registry': registryEntries.entries
          .map(
            (entry) => <String, Object?>{
              'appId': entry.key,
              'title': entry.value,
            },
          )
          .toList(),
      'endpoints': endpoints.entries
          .map(
            (entry) => <String, Object?>{
              'appId': entry.key,
              'apiBaseUri': entry.value['apiBaseUri'],
            },
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _inspectEnvironment({
    required String workspacePath,
    required String? explicitEnvironmentName,
  }) async {
    final resolved = await _stateStore.discoverEnvironmentState(
      currentWorkingDirectory: workspacePath,
      additionalSearchRoots: <String>[workspacePath],
    );
    if (resolved == null) {
      return <String, Object?>{'configured': false};
    }
    final activeEnvironment = resolved.state.activeEnvironment;
    final requestedEnvironmentName =
        explicitEnvironmentName?.trim().isNotEmpty == true
        ? explicitEnvironmentName!.trim()
        : activeEnvironment;
    return <String, Object?>{
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'activeEnvironment': activeEnvironment,
      'selectedEnvironment': requestedEnvironmentName,
    };
  }

  Future<Map<String, Object?>> _inspectBackend(String workspacePath) async {
    final resolved = await _stateStore.discoverBackendWorkspaceState(
      currentWorkingDirectory: workspacePath,
      additionalSearchRoots: <String>[workspacePath],
    );
    if (resolved == null) {
      return <String, Object?>{'configured': false, 'statusChecked': false};
    }
    try {
      final status = await _backendController.status(
        repoRootPath: resolved.state.backendRootPath,
      );
      return <String, Object?>{
        'configured': true,
        'scope': resolved.scope,
        'rootPath': resolved.rootPath,
        'filePath': resolved.filePath,
        'backendRootPath': resolved.state.backendRootPath,
        'apiRootPath': resolved.state.apiRootPath,
        'statusChecked': true,
        ..._backendStatusJson(status),
      };
    } catch (error) {
      return <String, Object?>{
        'configured': true,
        'scope': resolved.scope,
        'rootPath': resolved.rootPath,
        'filePath': resolved.filePath,
        'backendRootPath': resolved.state.backendRootPath,
        'apiRootPath': resolved.state.apiRootPath,
        'statusChecked': false,
        'error': error.toString(),
      };
    }
  }

  Future<void> _inspectValidation({
    required String workspacePath,
    required Map<String, Object?> workspace,
    required Map<String, Object?> miniProgram,
    required Map<String, Object?> backend,
  }) async {
    if (workspace['type'] != 'mini_program') {
      return;
    }
    final appId = miniProgram['appId']?.toString();
    final backendRootPath = backend['backendRootPath']?.toString();
    if (appId == null || appId.isEmpty || backendRootPath == null) {
      miniProgram['validation'] = <String, Object?>{
        'status': 'not_run',
        'reason': 'No local artifact host workspace was found for validation.',
      };
      return;
    }
    try {
      final report = await _validator.validate(
        repoRootPath: backendRootPath,
        authoredRepoRootPath: workspacePath,
        backendRootPath: backendRootPath,
        miniProgramId: appId,
        externalMiniProgramRootPath: workspacePath,
      );
      miniProgram['validation'] = <String, Object?>{
        'status': report.hasErrors
            ? 'error'
            : report.warningCount > 0
            ? 'warning'
            : 'ok',
        'errorCount': report.errorCount,
        'warningCount': report.warningCount,
      };
    } catch (error) {
      miniProgram['validation'] = <String, Object?>{
        'status': 'error',
        'reason': error.toString(),
      };
    }
  }

  Map<String, Object?> _inspectRemote(bool requested) {
    if (!requested) {
      return <String, Object?>{'checked': false};
    }
    return <String, Object?>{
      'checked': true,
      'supported': false,
      'message':
          'Provider remote artifact checks were removed. Host static artifacts from artifactBaseUrl and use optional middle-server runtime APIs.',
      'errors': <String>[],
    };
  }

  List<String> _buildNextActions({
    required Map<String, Object?> workspace,
    required Map<String, Object?> miniProgram,
    required Map<String, Object?> hostApp,
    required Map<String, Object?> environment,
    required Map<String, Object?> remote,
  }) {
    final actions = <String>[];
    switch (workspace['type']) {
      case 'mini_program':
        if (((miniProgram['build'] as Map?)?['exists']) != true) {
          actions.add('Run `miniprogram build`.');
        }
        final validation = miniProgram['validation'] as Map<String, Object?>;
        if (validation['status'] != 'ok' && validation['status'] != 'warning') {
          actions.add('Run `miniprogram validate`.');
        }
        actions.add(
          'Build and verify portable artifacts with `miniprogram artifact build` and `miniprogram artifact verify`.',
        );
      case 'host_app':
        if (hostApp['runtimeSetupExists'] != true) {
          actions.add('Run `miniprogram embed init`.');
        }
        if ((hostApp['endpointCount'] as int? ?? 0) == 0) {
          actions.add('Run `miniprogram host endpoint import <partner.json>`.');
        }
      default:
        actions.add('Open a mini-program or Flutter host app workspace.');
    }
    return actions;
  }

  String _computeSeverity({
    required Map<String, Object?> workspace,
    required Map<String, Object?> miniProgram,
    required Map<String, Object?> hostApp,
    required Map<String, Object?> environment,
    required Map<String, Object?> remote,
  }) {
    switch (workspace['type']) {
      case 'mini_program':
        if (((miniProgram['build'] as Map?)?['exists']) != true) {
          return 'warning';
        }
        final validation = miniProgram['validation'] as Map<String, Object?>;
        if (validation['status'] == 'error') {
          return 'error';
        }
        if ((remote['errors'] as List?)?.isNotEmpty == true) {
          return 'warning';
        }
        return 'ok';
      case 'host_app':
        if (hostApp['runtimeSetupExists'] != true ||
            (hostApp['endpointCount'] as int? ?? 0) == 0) {
          return 'warning';
        }
        return 'ok';
      default:
        return 'warning';
    }
  }

  Future<Map<String, dynamic>?> _readJsonObject(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  }

  Future<List<Map<String, Object?>>> _findPartnerPackages(
    String workspacePath,
  ) async {
    final directory = Directory(workspacePath);
    if (!await directory.exists()) {
      return <Map<String, Object?>>[];
    }
    final files = await directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).endsWith('.partner.json'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final packages = <Map<String, Object?>>[];
    for (final file in files) {
      try {
        final json = await _readJsonObject(file);
        packages.add(<String, Object?>{
          'filePath': file.path,
          'appId': json?['appId']?.toString(),
          'title': json?['title']?.toString(),
          'artifactBaseUrl':
              json?['artifactBaseUrl']?.toString() ??
              json?['apiBaseUrl']?.toString(),
        });
      } catch (error) {
        packages.add(<String, Object?>{
          'filePath': file.path,
          'error': error.toString(),
        });
      }
    }
    return packages;
  }

  Future<Map<String, Map<String, Object?>>> _readEndpointMetadata(
    File file,
  ) async {
    if (!await file.exists()) {
      return <String, Map<String, Object?>>{};
    }
    final source = await file.readAsString();
    final match = RegExp(
      r'// BEGIN MINI_PROGRAM_ENDPOINTS_JSON\s*// ([\s\S]*?)\s*// END MINI_PROGRAM_ENDPOINTS_JSON',
    ).firstMatch(source);
    if (match == null) {
      return <String, Map<String, Object?>>{};
    }
    final decoded = jsonDecode(match.group(1)!.trim());
    if (decoded is! Map) {
      return <String, Map<String, Object?>>{};
    }
    return decoded.map((key, value) {
      final record = value is Map ? value : <String, Object?>{};
      return MapEntry(key.toString(), <String, Object?>{
        'apiBaseUri': record['apiBaseUri']?.toString(),
      });
    });
  }

  Future<Map<String, String>> _readRegistryMetadata(File file) async {
    if (!await file.exists()) {
      return <String, String>{};
    }
    final source = await file.readAsString();
    if (!source.contains('class MiniPrograms') ||
        !source.contains('MiniProgramInfo')) {
      return <String, String>{};
    }
    final entries = <String, String>{};
    final pattern = RegExp(
      r'''static\s+const\s+[A-Za-z_$][A-Za-z0-9_$]*\s*=\s*MiniProgramInfo\s*\(\s*appId:\s*(['"])(.*?)\1\s*,\s*title:\s*(['"])(.*?)\3\s*,?\s*\)''',
      dotAll: true,
    );
    for (final match in pattern.allMatches(source)) {
      final appId = match.group(2)?.trim() ?? '';
      final title = match.group(4)?.trim() ?? '';
      if (appId.isNotEmpty && title.isNotEmpty) {
        entries[appId] = title;
      }
    }
    return entries;
  }

  Future<Map<String, Object?>> _detectMiniProgramBackendUsage(
    String workspacePath,
  ) async {
    final roots = <Directory>[
      Directory(p.join(workspacePath, 'lib')),
      Directory(p.join(workspacePath, 'mp')),
    ];
    final sources = <String>[];
    for (final root in roots) {
      if (!await root.exists()) {
        continue;
      }
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final basename = p.basename(entity.path);
        if (!basename.endsWith('.dart') && !basename.endsWith('.json')) {
          continue;
        }
        try {
          sources.add(await entity.readAsString());
        } catch (_) {
          // Ignore unreadable generated/build files; workflow status should
          // remain best-effort and local-first.
        }
      }
    }
    final joined = sources.join('\n');
    final requestIds = <String>{};
    final requestIdPattern = RegExp(
      r'''requestId\s*:\s*(['"])(.*?)\1|"requestId"\s*:\s*"(.*?)"''',
      dotAll: true,
    );
    for (final match in requestIdPattern.allMatches(joined)) {
      final value = match.group(2) ?? match.group(3) ?? '';
      if (value.trim().isNotEmpty) {
        requestIds.add(value.trim());
      }
    }
    final usesAction =
        joined.contains('miniProgramBackendAction(') ||
        joined.contains('Mp.backend.call(') ||
        joined.contains('"actionType":"miniProgramBackend"') ||
        joined.contains('"actionType": "miniProgramBackend"') ||
        joined.contains('"type":"backend.call"') ||
        joined.contains('"type": "backend.call"');
    final usesQueryAction =
        joined.contains('miniProgramBackendQueryAction(') ||
        joined.contains('Mp.backend.query(') ||
        joined.contains('"actionType":"miniProgramBackendQuery"') ||
        joined.contains('"actionType": "miniProgramBackendQuery"') ||
        joined.contains('"type":"backend.query"') ||
        joined.contains('"type": "backend.query"');
    final usesBuilder =
        joined.contains('miniProgramBackendBuilder(') ||
        joined.contains('Mp.backendBuilder(') ||
        joined.contains('"type":"miniProgramBackendBuilder"') ||
        joined.contains('"type": "miniProgramBackendBuilder"') ||
        joined.contains('"type":"backendBuilder"') ||
        joined.contains('"type": "backendBuilder"');
    final usesPagedBuilder =
        joined.contains('miniProgramPagedBackendBuilder(') ||
        joined.contains('Mp.pagedBackendBuilder(') ||
        joined.contains('"type":"miniProgramPagedBackendBuilder"') ||
        joined.contains('"type": "miniProgramPagedBackendBuilder"') ||
        joined.contains('"type":"pagedBackendBuilder"') ||
        joined.contains('"type": "pagedBackendBuilder"');
    final usesLazyChunk =
        joined.contains('Mp.lazy.chunk(') ||
        joined.contains('"type":"lazyChunk"') ||
        joined.contains('"type": "lazyChunk"');
    final usesLoadMore =
        joined.contains('miniProgramLoadMore(') ||
        joined.contains('Mp.backend.loadMore(') ||
        joined.contains('"actionType":"miniProgramLoadMore"') ||
        joined.contains('"actionType": "miniProgramLoadMore"') ||
        joined.contains('"type":"backend.loadMore"') ||
        joined.contains('"type": "backend.loadMore"');
    final usesAuthBuilder =
        joined.contains('Mp.authBuilder(') ||
        joined.contains('"type":"authBuilder"') ||
        joined.contains('"type": "authBuilder"');
    return <String, Object?>{
      'usesBackendAction': usesAction,
      'usesBackendQueryAction': usesQueryAction,
      'usesBackendBuilder': usesBuilder,
      'usesPagedBackendBuilder': usesPagedBuilder,
      'usesLazyChunk': usesLazyChunk,
      'usesLoadMore': usesLoadMore,
      'usesAuthBuilder': usesAuthBuilder,
      'usesBackendState':
          usesQueryAction ||
          usesBuilder ||
          usesPagedBuilder ||
          usesLazyChunk ||
          usesLoadMore,
      'usesPublisherBackend':
          usesAction ||
          usesQueryAction ||
          usesBuilder ||
          usesPagedBuilder ||
          usesLazyChunk ||
          usesLoadMore,
      'requestIds': requestIds.toList()..sort(),
    };
  }

  Future<Map<String, Object?>> _inspectPublisherBackendStarter(
    String workspacePath,
  ) async {
    final mockBackendRootPath = p.join(workspacePath, 'backend', 'mock');
    final serverPath = p.join(mockBackendRootPath, 'bin', 'server.dart');
    final dataRootPath = p.join(mockBackendRootPath, 'data');
    final dataFiles = <String>[
      'home_bootstrap.json',
      'coupons_list.json',
      'session.json',
    ];
    final existingDataFiles = <String>[];
    for (final dataFile in dataFiles) {
      final file = File(p.join(dataRootPath, dataFile));
      if (await file.exists()) {
        existingDataFiles.add(dataFile);
      }
    }
    final mockDetected =
        await File(serverPath).exists() &&
        await Directory(dataRootPath).exists();
    return <String, Object?>{
      'detected': mockDetected,
      'template': mockDetected ? 'mock' : null,
      'storageMode': mockDetected ? 'bundled' : null,
      'backendRootPath': mockBackendRootPath,
      'serverPath': serverPath,
      'dataRootPath': dataRootPath,
      'dataFiles': existingDataFiles,
      'mock': <String, Object?>{
        'detected': mockDetected,
        'backendRootPath': mockBackendRootPath,
        'serverPath': serverPath,
        'dataRootPath': dataRootPath,
        'dataFiles': existingDataFiles,
      },
      'expectedRoutes': <String>[
        'GET /health',
        'GET /home/bootstrap',
        'GET /coupons/list',
        'GET /coupons/page',
        'GET /auth/session',
        'POST /coupon/redeem',
      ],
    };
  }
}

Map<String, Object?> miniProgramWorkflowStatusBackendJson(
  LocalBackendStatusResult result,
) => _backendStatusJson(result);

Map<String, Object?> _backendStatusJson(LocalBackendStatusResult result) {
  return <String, Object?>{
    'hasState': result.hasState,
    'processAlive': result.processAlive,
    'healthy': result.healthy,
    'healthStatusCode': result.healthStatusCode,
    'healthError': result.healthError,
    'state': result.state == null
        ? null
        : <String, Object?>{
            'pid': result.state!.pid,
            'port': result.state!.port,
            'bindHost': result.state!.bindHost,
            'healthCheckUrl': result.state!.healthCheckUrl,
            'stdoutLogPath': result.state!.stdoutLogPath,
            'stderrLogPath': result.state!.stderrLogPath,
            'startedAtUtc': result.state!.startedAtUtc,
          },
  };
}
