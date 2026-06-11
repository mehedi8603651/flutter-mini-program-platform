import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_cli_state.dart';
import 'mini_program_cloud_controller.dart';
import 'publisher_backend_starter.dart';

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
    MiniProgramCloudController? cloudController,
    PublisherBackendStarter publisherBackendStarter =
        const PublisherBackendStarter(),
  }) : _stateStore = stateStore,
       _validator = validator,
       _backendController = backendController,
       _cloudController = cloudController,
       _publisherBackendStarter = publisherBackendStarter;

  final LocalCliStateStore _stateStore;
  final DeliveryRepositoryValidator _validator;
  final LocalBackendController _backendController;
  final MiniProgramCloudController? _cloudController;
  final PublisherBackendStarter _publisherBackendStarter;

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
    final remote = request.remote
        ? await _inspectRemote(
            workspacePath: workspacePath,
            environment: environment,
            miniProgram: miniProgram,
          )
        : <String, Object?>{'checked': false};
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
    final hostCloud = await _stateStore.readHostCloudConfiguration(
      workspacePath,
    );
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
              'accessMode': entry.value['accessMode'],
              'hasAccessKey': entry.value['hasAccessKey'],
              'backendBaseUri': entry.value['backendBaseUri'],
              'backendConfigured': entry.value['backendConfigured'],
              'backendMode': entry.value['backendMode'],
            },
          )
          .toList(),
      'hostCloud': hostCloud == null
          ? <String, Object?>{'configured': false}
          : <String, Object?>{
              'configured': true,
              'environmentName': hostCloud.environmentName,
              'provider': hostCloud.provider,
              'backendApiBaseUrl': hostCloud.backendApiBaseUrl,
              'configuredAtUtc': hostCloud.configuredAtUtc,
              'updatedAtUtc': hostCloud.updatedAtUtc,
            },
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
    final cloudEnvironment =
        requestedEnvironmentName == 'local' ||
            requestedEnvironmentName == 'cloud'
        ? null
        : resolved.state.cloudEnvironmentNamed(requestedEnvironmentName);
    return <String, Object?>{
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'activeEnvironment': activeEnvironment,
      'selectedEnvironment': requestedEnvironmentName,
      'cloudEnvironmentCount': resolved.state.cloudEnvironments.length,
      'provider': cloudEnvironment?.provider,
      'apiBaseUrl': cloudEnvironment?.values['apiBaseUrl']?.toString(),
      'bucket': cloudEnvironment?.values['bucket']?.toString(),
      'region': cloudEnvironment?.values['region']?.toString(),
      'projectId': cloudEnvironment?.values['projectId']?.toString(),
      'functionName': cloudEnvironment?.values['functionName']?.toString(),
      'functionUrl': cloudEnvironment?.values['functionUrl']?.toString(),
      'artifactsPrefix': cloudEnvironment?.values['artifactsPrefix']
          ?.toString(),
      'metadataPrefix': cloudEnvironment?.values['metadataPrefix']?.toString(),
      'awsProfile': cloudEnvironment?.values['awsProfile']?.toString(),
      'stackName': cloudEnvironment?.values['stackName']?.toString(),
      'stageName': cloudEnvironment?.values['stageName']?.toString(),
      'samS3Bucket': cloudEnvironment?.values['samS3Bucket']?.toString(),
      'requireAccessKeys':
          cloudEnvironment?.values['requireAccessKeys'] == true,
      'cloudConfigured': cloudEnvironment != null,
      'configuredAtUtc': cloudEnvironment?.configuredAtUtc,
      'updatedAtUtc': cloudEnvironment?.updatedAtUtc,
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
        'reason': 'No backend workspace was found for validation.',
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

  Future<Map<String, Object?>> _inspectRemote({
    required String workspacePath,
    required Map<String, Object?> environment,
    required Map<String, Object?> miniProgram,
  }) async {
    final errors = <String>[];
    final remote = <String, Object?>{
      'checked': true,
      'provider': environment['provider']?.toString(),
      'cloudStatus': null,
      'app': null,
      'accessKeys': null,
      'errors': errors,
    };
    final provider = environment['provider']?.toString();
    if (provider == 'firebase') {
      return _inspectFirebaseRemote(
        workspacePath: workspacePath,
        environment: environment,
        miniProgram: miniProgram,
        remote: remote,
        errors: errors,
      );
    }
    final cloudController = _cloudController;
    if (cloudController == null) {
      errors.add('No cloud controller is available.');
      return remote;
    }
    final selectedEnvironment = environment['selectedEnvironment']?.toString();
    final rootPath = environment['rootPath']?.toString();
    final filePath = environment['filePath']?.toString();
    if (selectedEnvironment == null ||
        selectedEnvironment.isEmpty ||
        provider == null ||
        rootPath == null ||
        filePath == null) {
      errors.add('No named cloud environment is configured.');
      return remote;
    }
    final env = CloudEnvironmentConfiguration(
      name: selectedEnvironment,
      provider: provider,
      values: <String, dynamic>{
        if (environment['bucket'] != null) 'bucket': environment['bucket'],
        if (environment['region'] != null) 'region': environment['region'],
        if (environment['artifactsPrefix'] != null)
          'artifactsPrefix': environment['artifactsPrefix'],
        if (environment['metadataPrefix'] != null)
          'metadataPrefix': environment['metadataPrefix'],
        if (environment['apiBaseUrl'] != null)
          'apiBaseUrl': environment['apiBaseUrl'],
        if (environment['awsProfile'] != null)
          'awsProfile': environment['awsProfile'],
        if (environment['stackName'] != null)
          'stackName': environment['stackName'],
        if (environment['stageName'] != null)
          'stageName': environment['stageName'],
        if (environment['samS3Bucket'] != null)
          'samS3Bucket': environment['samS3Bucket'],
        if (environment['requireAccessKeys'] != null)
          'requireAccessKeys': environment['requireAccessKeys'],
      },
      configuredAtUtc: environment['configuredAtUtc']?.toString() ?? '',
      updatedAtUtc: environment['updatedAtUtc']?.toString() ?? '',
    );
    final resolved = ResolvedLocalCliEnvironmentState(
      rootPath: rootPath,
      filePath: filePath,
      state: LocalCliEnvironmentState(
        schemaVersion: 2,
        repoRootPath: null,
        activeEnvironment: selectedEnvironment,
        cloudEnvironments: <CloudEnvironmentConfiguration>[env],
        initializedAtUtc: environment['configuredAtUtc']?.toString() ?? '',
        updatedAtUtc: environment['updatedAtUtc']?.toString() ?? '',
      ),
      scope: environment['scope']?.toString() ?? 'local',
    );

    try {
      final status = await cloudController.status(
        MiniProgramCloudStatusRequest(
          resolvedEnvironmentState: resolved,
          environment: env,
        ),
      );
      remote['cloudStatus'] = _cloudStatusJson(status);
    } catch (error) {
      errors.add('Cloud status failed: $error');
    }

    final appId = miniProgram['appId']?.toString();
    if (appId == null || appId.isEmpty) {
      return remote;
    }
    try {
      final appInfo = await cloudController.appInfo(
        MiniProgramCloudAppInfoRequest(
          resolvedEnvironmentState: resolved,
          environment: env,
          miniProgramId: appId,
        ),
      );
      remote['app'] = _cloudAppInfoJson(appInfo);
    } catch (error) {
      errors.add('Cloud app info failed: $error');
    }
    try {
      final keys = await cloudController.listAccessKeys(
        MiniProgramAccessKeyListRequest(
          resolvedEnvironmentState: resolved,
          environment: env,
          miniProgramId: appId,
        ),
      );
      remote['accessKeys'] = _accessKeyListJson(keys);
    } catch (error) {
      errors.add('Access-key list failed: $error');
    }
    return remote;
  }

  Future<Map<String, Object?>> _inspectFirebaseRemote({
    required String workspacePath,
    required Map<String, Object?> environment,
    required Map<String, Object?> miniProgram,
    required Map<String, Object?> remote,
    required List<String> errors,
  }) async {
    final firebase = <String, Object?>{
      'checked': true,
      'status': null,
      'dataStatus': null,
    };
    remote['firebase'] = firebase;
    final starter = miniProgram['publisherBackendStarter'];
    final detected =
        starter is Map &&
        (starter['firebase'] is Map) &&
        ((starter['firebase'] as Map)['detected'] == true);
    if (!detected) {
      firebase['checked'] = false;
      firebase['reason'] = 'Firebase publisher backend scaffold was not found.';
      return remote;
    }
    final env = _firebaseEnvironmentFromWorkflowStatus(environment);
    if (env == null) {
      errors.add('No named Firebase environment is configured.');
      return remote;
    }
    try {
      final status = await _publisherBackendStarter.firebaseStatus(
        PublisherBackendFirebaseStatusRequest(
          miniProgramRootPath: workspacePath,
          environment: env,
        ),
      );
      firebase['status'] = _firebaseStatusJson(status);
    } catch (error) {
      errors.add('Firebase status failed: $error');
    }
    try {
      final dataStatus = await _publisherBackendStarter.firebaseDataStatus(
        PublisherBackendFirebaseDataStatusRequest(
          miniProgramRootPath: workspacePath,
          environment: env,
        ),
      );
      firebase['dataStatus'] = _firebaseDataStatusJson(dataStatus);
    } catch (error) {
      errors.add('Firebase data status failed: $error');
    }
    return remote;
  }

  CloudEnvironmentConfiguration? _firebaseEnvironmentFromWorkflowStatus(
    Map<String, Object?> environment,
  ) {
    final selectedEnvironment = environment['selectedEnvironment']?.toString();
    final provider = environment['provider']?.toString();
    final projectId = environment['projectId']?.toString();
    if (selectedEnvironment == null ||
        selectedEnvironment.isEmpty ||
        provider != 'firebase' ||
        projectId == null ||
        projectId.isEmpty) {
      return null;
    }
    return CloudEnvironmentConfiguration(
      name: selectedEnvironment,
      provider: 'firebase',
      values: <String, dynamic>{
        'projectId': projectId,
        if (environment['region'] != null) 'region': environment['region'],
        if (environment['functionName'] != null)
          'functionName': environment['functionName'],
        if (environment['functionUrl'] != null)
          'functionUrl': environment['functionUrl'],
      },
      configuredAtUtc: environment['configuredAtUtc']?.toString() ?? '',
      updatedAtUtc: environment['updatedAtUtc']?.toString() ?? '',
    );
  }

  Map<String, Object?> _firebaseStatusJson(
    PublisherBackendFirebaseStatusResult result,
  ) {
    return <String, Object?>{
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'backendBaseUrl': result.backendBaseUrl,
      'healthUrl': result.healthUrl,
      'scaffoldExists': result.scaffoldExists,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
    };
  }

  Map<String, Object?> _firebaseDataStatusJson(
    PublisherBackendFirebaseDataStatusResult result,
  ) {
    return <String, Object?>{
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'storageMode': result.storageMode,
      'available': result.available,
      'homeRecordCount': result.homeRecordCount,
      'authSessionCount': result.authSessionCount,
      'couponCount': result.couponCount,
      'redemptionCount': result.redemptionCount,
      'appRecordCount': result.appRecordCount,
      'error': result.error,
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
        if (environment['configured'] != true) {
          actions.add('Run `miniprogram env init` and configure a cloud env.');
        } else if (environment['cloudConfigured'] != true) {
          actions.add('Run `miniprogram env use <env-name>`.');
        } else if (remote['checked'] != true) {
          actions.add('Run `miniprogram workflow status --remote`.');
        }
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
        if (environment['cloudConfigured'] != true) {
          return 'warning';
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
          'apiBaseUrl': json?['apiBaseUrl']?.toString(),
          'backendBaseUrl': json?['backendBaseUrl']?.toString(),
          'backendConfigured':
              json?['backendBaseUrl']?.toString().trim().isNotEmpty ?? false,
          'accessMode':
              json?['accessMode']?.toString() ??
              ((json?['accessKey']?.toString().isNotEmpty ?? false)
                  ? 'protected'
                  : 'public'),
          'hasAccessKey': (json?['accessKey']?.toString().isNotEmpty ?? false),
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
      final hasAccessKey = record['accessKey']?.toString().isNotEmpty ?? false;
      final accessMode =
          record['accessMode']?.toString() ??
          (hasAccessKey ? 'protected' : 'public');
      return MapEntry(key.toString(), <String, Object?>{
        'apiBaseUri': record['apiBaseUri']?.toString(),
        'accessMode': accessMode,
        'hasAccessKey': hasAccessKey,
        'backendBaseUri': record['backendBaseUri']?.toString(),
        'backendConfigured':
            record['backendBaseUri']?.toString().trim().isNotEmpty ?? false,
        'backendMode': _readBackendMode(record),
      });
    });
  }

  String _readBackendMode(Map<Object?, Object?> record) {
    final mode = record['backendMode']?.toString().trim().toLowerCase();
    if (mode == 'local_mock' || mode == 'remote' || mode == 'none') {
      return mode!;
    }
    final backendBaseUri = record['backendBaseUri']?.toString().trim() ?? '';
    return backendBaseUri.isEmpty ? 'none' : 'remote';
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
    final awsBackendRootPath = p.join(workspacePath, 'backend', 'aws_lambda');
    final awsTemplatePath = p.join(awsBackendRootPath, 'template.yaml');
    final awsHandlerPath = p.join(awsBackendRootPath, 'src', 'handler.mjs');
    final awsDetected =
        await File(awsTemplatePath).exists() &&
        await File(awsHandlerPath).exists();
    final firebaseBackendRootPath = p.join(
      workspacePath,
      'backend',
      'firebase_functions',
    );
    final firebaseConfigPath = p.join(firebaseBackendRootPath, 'firebase.json');
    final firebaseIndexPath = p.join(
      firebaseBackendRootPath,
      'functions',
      'index.js',
    );
    final firebaseRouterPath = p.join(
      firebaseBackendRootPath,
      'functions',
      'router.js',
    );
    final firebaseDataRootPath = p.join(
      firebaseBackendRootPath,
      'functions',
      'data',
    );
    final existingFirebaseDataFiles = <String>[];
    for (final dataFile in dataFiles) {
      final file = File(p.join(firebaseDataRootPath, dataFile));
      if (await file.exists()) {
        existingFirebaseDataFiles.add(dataFile);
      }
    }
    final firebaseDetected =
        await File(firebaseConfigPath).exists() &&
        await File(firebaseIndexPath).exists() &&
        await File(firebaseRouterPath).exists();
    final awsStatePath = p.join(
      workspacePath,
      '.mini_program',
      'publisher_backend.aws.json',
    );
    final awsState = await _tryReadJsonObject(File(awsStatePath));
    return <String, Object?>{
      'detected': mockDetected || awsDetected || firebaseDetected,
      'template': firebaseDetected
          ? 'firebase-functions'
          : awsDetected
          ? 'aws-lambda'
          : mockDetected
          ? 'mock'
          : null,
      'storageMode': firebaseDetected ? 'firestore' : null,
      'backendRootPath': firebaseDetected
          ? firebaseBackendRootPath
          : awsDetected
          ? awsBackendRootPath
          : mockBackendRootPath,
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
      'aws': <String, Object?>{
        'detected': awsDetected,
        'backendRootPath': awsBackendRootPath,
        'templatePath': awsTemplatePath,
        'handlerPath': awsHandlerPath,
        'statePath': awsStatePath,
        'stateExists': awsState != null,
        if (awsState != null) ...<String, Object?>{
          'environmentName': awsState['environmentName'],
          'stackName': awsState['stackName'],
          'stageName': awsState['stageName'],
          'region': awsState['region'],
          'deployedAtUtc': awsState['deployedAtUtc'],
          'backendBaseUrl': _stringOutput(
            awsState,
            'outputs',
            'PublisherBackendBaseUrl',
          ),
          'healthUrl': _stringOutput(
            awsState,
            'outputs',
            'PublisherBackendHealthUrl',
          ),
          'functionName': _stringOutput(
            awsState,
            'outputs',
            'PublisherBackendFunctionName',
          ),
        },
      },
      'firebase': <String, Object?>{
        'detected': firebaseDetected,
        'backendRootPath': firebaseBackendRootPath,
        'configPath': firebaseConfigPath,
        'indexPath': firebaseIndexPath,
        'routerPath': firebaseRouterPath,
        'dataRootPath': firebaseDataRootPath,
        'dataFiles': existingFirebaseDataFiles,
        'storageMode': 'firestore',
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

  Future<Map<String, dynamic>?> _tryReadJsonObject(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return await _readJsonObject(file);
    } catch (_) {
      return null;
    }
  }
}

String? _stringOutput(
  Map<String, dynamic> state,
  String parentKey,
  String outputKey,
) {
  final parent = state[parentKey];
  if (parent is! Map) {
    return null;
  }
  final value = parent[outputKey]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

Map<String, Object?> miniProgramWorkflowStatusBackendJson(
  LocalBackendStatusResult result,
) => _backendStatusJson(result);

Map<String, Object?> miniProgramWorkflowStatusCloudJson(
  MiniProgramCloudStatusResult result,
) => _cloudStatusJson(result);

Map<String, Object?> miniProgramWorkflowStatusAccessKeyListJson(
  MiniProgramAccessKeyListResult result,
) => _accessKeyListJson(result);

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

Map<String, Object?> _cloudStatusJson(MiniProgramCloudStatusResult result) {
  return <String, Object?>{
    'provider': result.provider,
    'environmentName': result.environmentName,
    'stackName': result.stackName,
    'stageName': result.stageName,
    'region': result.region,
    'stackExists': result.stackExists,
    'stackStatus': result.stackStatus,
    'stackStatusReason': result.stackStatusReason,
    'apiBaseUrl': result.apiBaseUrl,
    'healthUrl': result.healthUrl,
    'healthy': result.healthy,
    'healthStatusCode': result.healthStatusCode,
    'healthError': result.healthError,
    'outputs': result.outputs,
  };
}

Map<String, Object?> _cloudAppInfoJson(MiniProgramCloudAppInfoResult result) {
  return <String, Object?>{
    'provider': result.provider,
    'environmentName': result.environmentName,
    'miniProgramId': result.miniProgramId,
    'bucketName': result.bucketName,
    'region': result.region,
    'catalogKey': result.catalogKey,
    'latestVersion': result.catalog['latestVersion']?.toString(),
    'releaseKey': result.releaseKey,
    'accessPolicyKey': result.accessPolicyKey,
    'accessKeyCount': result.accessKeyCount,
    'activeAccessKeyCount': result.activeAccessKeyCount,
  };
}

Map<String, Object?> _accessKeyListJson(MiniProgramAccessKeyListResult result) {
  return <String, Object?>{
    'provider': result.provider,
    'environmentName': result.environmentName,
    'miniProgramId': result.miniProgramId,
    'bucketName': result.bucketName,
    'region': result.region,
    'policyKey': result.policyKey,
    'policyExists': result.policyExists,
    'activeCount': result.keys.where((key) => key.active).length,
    'keyCount': result.keys.length,
    'keys': result.keys
        .map(
          (key) => <String, Object?>{
            'id': key.id,
            'enabled': key.enabled,
            'active': key.active,
            'createdAtUtc': key.createdAtUtc,
            'updatedAtUtc': key.updatedAtUtc,
            'revokedAtUtc': key.revokedAtUtc,
          },
        )
        .toList(),
  };
}
