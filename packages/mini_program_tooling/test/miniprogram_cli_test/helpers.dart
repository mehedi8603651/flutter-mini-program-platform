part of '../miniprogram_cli_test.dart';

class _FakeLocalBackendController extends LocalBackendController {
  final List<String> calls = <String>[];
  final List<String> repoRootPaths = <String>[];
  int? startedPort;

  @override
  Future<LocalBackendStartResult> start({
    required String repoRootPath,
    int port = 8080,
  }) async {
    calls.add('start');
    repoRootPaths.add(repoRootPath);
    startedPort = port;
    return LocalBackendStartResult(
      state: LocalBackendState(
        pid: 1234,
        port: port,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:$port/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      alreadyRunning: false,
    );
  }

  @override
  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    calls.add('status');
    repoRootPaths.add(repoRootPath);
    return LocalBackendStatusResult(
      state: LocalBackendState(
        pid: 1234,
        port: 9090,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:9090/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      hasState: true,
      processAlive: true,
      healthy: true,
      healthStatusCode: 200,
    );
  }

  @override
  Future<LocalBackendStopResult> stop({required String repoRootPath}) async {
    calls.add('stop');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  @override
  Future<LocalBackendResetResult> resetLocal({
    required String repoRootPath,
  }) async {
    calls.add('reset-local');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendResetResult(removedPaths: <String>[]);
  }
}

class _FakeMiniprogramDoctor extends MiniprogramDoctor {
  const _FakeMiniprogramDoctor();

  @override
  Future<MiniprogramDoctorResult> diagnose({
    String? explicitRepoRootPath,
  }) async {
    return const MiniprogramDoctorResult(
      checks: <MiniprogramDoctorCheck>[
        MiniprogramDoctorCheck(
          label: 'Fake check',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: 'all good',
        ),
      ],
    );
  }
}

class _FakeLocalBackendInitializer extends LocalBackendInitializer {
  _FakeLocalBackendInitializer({this.defaultBackendRootPath});

  String? initializedRootPath;
  final String? defaultBackendRootPath;

  @override
  Future<LocalBackendInitResult> initialize(
    LocalBackendInitRequest request,
  ) async {
    initializedRootPath = request.backendRootPath;
    final backendRootPath = p.normalize(
      p.absolute(
        request.backendRootPath ??
            defaultBackendRootPath ??
            'backend_workspace',
      ),
    );
    return LocalBackendInitResult(
      backendRootPath: backendRootPath,
      apiRootPath: p.join(backendRootPath, 'backend', 'api'),
      serviceDirectoryPath: p.join(
        backendRootPath,
        'backend',
        'local_backend_service',
      ),
      stateFilePath: p.join(
        backendRootPath,
        '.mini_program',
        'backend_workspace.json',
      ),
      globalStateFilePath: p.join(
        backendRootPath,
        '.mini_program',
        'global_backend_workspace.json',
      ),
      createdPaths: <String>[
        p.join(backendRootPath, 'backend', 'api'),
        p.join(backendRootPath, 'backend', 'local_backend_service'),
      ],
    );
  }
}

class _FakeMiniProgramPreviewController extends MiniProgramPreviewController {
  _FakeMiniProgramPreviewController();

  MiniProgramPreviewRequest? lastRequest;

  @override
  Future<int> preview(
    MiniProgramPreviewRequest request, {
    required StringSink stdoutSink,
    required StringSink stderrSink,
  }) async {
    lastRequest = request;
    return 0;
  }
}

class _FakeMiniProgramCloudPublisher extends MiniProgramCloudPublisher {
  _FakeMiniProgramCloudPublisher();

  MiniProgramCloudPublishRequest? lastRequest;

  @override
  Future<MiniProgramCloudPublishResult> publish(
    MiniProgramCloudPublishRequest request,
  ) async {
    lastRequest = request;
    return MiniProgramCloudPublishResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      version: '1.2.3',
      buildResult: MiniProgramBuildResult(
        repoRootPath: request.repoRootPath,
        miniProgramId: request.miniProgramId ?? 'coupon_center',
        miniProgramRootPath:
            request.miniProgramRootPath ??
            p.join(request.repoRootPath, 'coupon_center'),
        cliSource: 'fake',
        invocation: const <String>['dart', 'fake'],
        outputDirectoryPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'mp',
          '.build',
        ),
        screensDirectoryPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'mp',
          '.build',
          'screens',
        ),
        entryScreenJsonPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'mp',
          '.build',
          'screens',
          'coupon_center_home.json',
        ),
        pubGetRan: false,
      ),
      bucketName: 'mini-program-prod',
      region: 'us-east-1',
      artifactRootKey: 'artifacts/coupon_center/1.2.3',
      manifestKey: 'artifacts/coupon_center/1.2.3/manifest.json',
      screensPrefixKey: 'artifacts/coupon_center/1.2.3/screens',
      metadataReleaseKey: 'metadata/releases/coupon_center/1.2.3.json',
      metadataCatalogKey: 'metadata/catalog/coupon_center.json',
      publishedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
      uploadedObjects: const <CloudPublishedObjectRecord>[],
    );
  }
}

class _FakeMiniProgramStaticPublisher extends MiniProgramStaticPublisher {
  _FakeMiniProgramStaticPublisher();

  MiniProgramStaticPublishRequest? lastRequest;

  @override
  Future<MiniProgramStaticPublishResult> publish(
    MiniProgramStaticPublishRequest request,
  ) async {
    lastRequest = request;
    final miniProgramRootPath =
        request.miniProgramRootPath ??
        p.join(request.repoRootPath, request.miniProgramId ?? 'coupon_center');
    final buildResult = MiniProgramBuildResult(
      repoRootPath: request.repoRootPath,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      miniProgramRootPath: miniProgramRootPath,
      cliSource: 'fake',
      invocation: const <String>['dart', 'fake'],
      outputDirectoryPath: p.join(miniProgramRootPath, 'mp', '.build'),
      screensDirectoryPath: p.join(
        miniProgramRootPath,
        'mp',
        '.build',
        'screens',
      ),
      entryScreenJsonPath: p.join(
        miniProgramRootPath,
        'mp',
        '.build',
        'screens',
        'coupon_center_home.json',
      ),
      pubGetRan: false,
      screenFormat: 'mp',
      screenSchemaVersion: 1,
    );
    return MiniProgramStaticPublishResult(
      outputPath: request.outputPath,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      version: '1.2.3',
      buildResult: buildResult,
      manifestLatestPath: p.join(
        request.outputPath,
        'manifests',
        request.miniProgramId ?? 'coupon_center',
        'latest.json',
      ),
      manifestVersionPath: p.join(
        request.outputPath,
        'manifests',
        request.miniProgramId ?? 'coupon_center',
        'versions',
        '1.2.3.json',
      ),
      screensDirectoryPath: p.join(
        request.outputPath,
        'screens',
        request.miniProgramId ?? 'coupon_center',
        '1.2.3',
      ),
      metadataReleasePath: p.join(
        request.outputPath,
        'metadata',
        'releases',
        request.miniProgramId ?? 'coupon_center',
        '1.2.3.json',
      ),
      metadataCatalogPath: p.join(
        request.outputPath,
        'metadata',
        'catalog',
        '${request.miniProgramId ?? 'coupon_center'}.json',
      ),
      instructionsPath: p.join(request.outputPath, 'PUBLISH_INSTRUCTIONS.md'),
      nojekyllPath: p.join(request.outputPath, '.nojekyll'),
      publishedAtUtc: DateTime.utc(2026, 5, 18).toIso8601String(),
      writtenFiles: const <StaticPublishedFileRecord>[],
      cleaned: request.clean,
    );
  }
}

class _FakeMiniProgramCloudController extends MiniProgramCloudController {
  _FakeMiniProgramCloudController();

  MiniProgramCloudDeployRequest? lastDeployRequest;
  MiniProgramCloudStatusRequest? lastStatusRequest;
  MiniProgramCloudOutputsRequest? lastOutputsRequest;
  MiniProgramCloudRollbackRequest? lastRollbackRequest;
  MiniProgramAccessKeyCreateRequest? lastAccessKeyCreateRequest;
  MiniProgramAccessKeyListRequest? lastAccessKeyListRequest;
  MiniProgramAccessKeyRevokeRequest? lastAccessKeyRevokeRequest;
  MiniProgramAccessKeyRotateRequest? lastAccessKeyRotateRequest;
  MiniProgramCloudAppListRequest? lastAppListRequest;
  MiniProgramCloudAppInfoRequest? lastAppInfoRequest;
  MiniProgramCloudAppDisableRequest? lastAppDisableRequest;
  MiniProgramCloudAppDeleteRequest? lastAppDeleteRequest;

  @override
  Future<MiniProgramCloudDeployResult> deploy(
    MiniProgramCloudDeployRequest request,
  ) async {
    lastDeployRequest = request;
    return MiniProgramCloudDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      stageName: 'prod',
      region: request.environment.values['region'].toString(),
      bucketName: request.environment.values['bucket'].toString(),
      backendProjectRootPath: p.join(
        request.resolvedEnvironmentState.rootPath,
        '.mini_program',
        'cloud',
        'aws_backend',
      ),
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
      apiBaseUrl: 'https://api.example.com/api/',
      healthUrl: 'https://api.example.com/health',
      healthy: true,
      healthStatusCode: 200,
      deployedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramCloudStatusResult> status(
    MiniProgramCloudStatusRequest request,
  ) async {
    lastStatusRequest = request;
    return MiniProgramCloudStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      stageName: 'prod',
      region: request.environment.values['region'].toString(),
      stackExists: true,
      stackStatus: 'CREATE_COMPLETE',
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
      apiBaseUrl: 'https://api.example.com/api/',
      healthUrl: 'https://api.example.com/health',
      healthy: true,
      healthStatusCode: 200,
    );
  }

  @override
  Future<MiniProgramCloudOutputsResult> outputs(
    MiniProgramCloudOutputsRequest request,
  ) async {
    lastOutputsRequest = request;
    return MiniProgramCloudOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      region: request.environment.values['region'].toString(),
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
    );
  }

  @override
  Future<MiniProgramCloudRollbackResult> rollback(
    MiniProgramCloudRollbackRequest request,
  ) async {
    lastRollbackRequest = request;
    return MiniProgramCloudRollbackResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      version: request.version,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      releaseKey:
          'metadata/releases/${request.miniProgramId}/${request.version}.json',
      rolledBackAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyCreateResult> createAccessKey(
    MiniProgramAccessKeyCreateRequest request,
  ) async {
    lastAccessKeyCreateRequest = request;
    return MiniProgramAccessKeyCreateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      keyId: request.keyId,
      accessKey: 'mpk_live_fake_${request.miniProgramId}_${request.keyId}',
      createdAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyListResult> listAccessKeys(
    MiniProgramAccessKeyListRequest request,
  ) async {
    lastAccessKeyListRequest = request;
    return MiniProgramAccessKeyListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      policyExists: true,
      keys: const <MiniProgramAccessKeyEntry>[
        MiniProgramAccessKeyEntry(
          id: 'host-a',
          sha256: 'sha256_should_not_print',
          enabled: true,
          createdAtUtc: '2026-04-19T00:00:00.000Z',
          updatedAtUtc: '2026-04-19T00:00:00.000Z',
        ),
      ],
    );
  }

  @override
  Future<MiniProgramAccessKeyRevokeResult> revokeAccessKey(
    MiniProgramAccessKeyRevokeRequest request,
  ) async {
    lastAccessKeyRevokeRequest = request;
    return MiniProgramAccessKeyRevokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      keyId: request.keyId,
      revokedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyRotateResult> rotateAccessKey(
    MiniProgramAccessKeyRotateRequest request,
  ) async {
    lastAccessKeyRotateRequest = request;
    return MiniProgramAccessKeyRotateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      revokedKeyId: request.keyId,
      newKeyId: request.newKeyId ?? '${request.keyId}-v2',
      accessKey: 'mpk_live_fake_${request.miniProgramId}_${request.keyId}_v2',
      rotatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramCloudAppListResult> listApps(
    MiniProgramCloudAppListRequest request,
  ) async {
    lastAppListRequest = request;
    return MiniProgramCloudAppListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      apps: const <MiniProgramCloudAppSummary>[
        MiniProgramCloudAppSummary(
          miniProgramId: 'coupon_center',
          catalogKey: 'metadata/catalog/coupon_center.json',
          latestVersion: '1.2.3',
        ),
      ],
    );
  }

  @override
  Future<MiniProgramCloudAppInfoResult> appInfo(
    MiniProgramCloudAppInfoRequest request,
  ) async {
    lastAppInfoRequest = request;
    return MiniProgramCloudAppInfoResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      catalog: <String, Object?>{
        'latestVersion': '1.2.3',
        'releaseKey': 'metadata/releases/${request.miniProgramId}/1.2.3.json',
      },
      releaseKey: 'metadata/releases/${request.miniProgramId}/1.2.3.json',
      accessPolicyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      accessKeyCount: 1,
      activeAccessKeyCount: 1,
    );
  }

  @override
  Future<MiniProgramCloudAppDisableResult> disableApp(
    MiniProgramCloudAppDisableRequest request,
  ) async {
    lastAppDisableRequest = request;
    return MiniProgramCloudAppDisableResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      disabledCatalogKey: 'metadata/disabled/${request.miniProgramId}.json',
      disabledAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      dryRun: !request.confirmed,
    );
  }

  @override
  Future<MiniProgramCloudAppDeleteResult> deleteApp(
    MiniProgramCloudAppDeleteRequest request,
  ) async {
    lastAppDeleteRequest = request;
    return MiniProgramCloudAppDeleteResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      deletedKeys: <String>[
        'metadata/catalog/${request.miniProgramId}.json',
        'metadata/access_keys/${request.miniProgramId}.json',
      ],
      dryRun: !request.confirmed,
      deletedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }
}

class _FakeMiniProgramHostController extends MiniProgramHostController {
  _FakeMiniProgramHostController();

  MiniProgramHostRunRequest? lastRequest;

  @override
  Future<MiniProgramHostRunResult> run(
    MiniProgramHostRunRequest request,
  ) async {
    lastRequest = request;
    return MiniProgramHostRunResult(
      projectRootPath: request.projectRootPath,
      deviceId: request.deviceId,
      backendApiBaseUrl: request.backendApiBaseUrl,
      invocation: <String>[
        'run',
        '-d',
        request.deviceId,
        '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=${request.backendApiBaseUrl}',
      ],
      exitCode: 0,
    );
  }
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  required String version,
}) async {
  await Directory(p.join(miniProgramRootPath, 'tool')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "$version",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "screenFormat": "mp",
  "screenSchemaVersion": 1,
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''');

  await File(p.join(miniProgramRootPath, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0
''');

  await File(
    p.join(miniProgramRootPath, 'tool', 'build_mp.dart'),
  ).writeAsString(_fakeMpBuildScriptSource(screenId: '${miniProgramId}_home'));
}

String _fakeMpBuildScriptSource({required String screenId}) =>
    '''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  final output = outputIndex == -1 ? 'mp/.build' : arguments[outputIndex + 1];
  final screenDirectory = Directory('\$output/screens');
  await screenDirectory.create(recursive: true);
  await File('\$output/screens/$screenId.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': '$screenId',
      'root': <String, Object?>{
        'type': 'text',
        'props': <String, Object?>{'data': 'Hello'},
      },
    }),
  );
}
''';

Future<void> _writeEmbeddedHostFixture(String hostRootPath) async {
  await Directory(
    p.join(hostRootPath, 'lib', 'mini_program'),
  ).create(recursive: true);
  await File(p.join(hostRootPath, 'pubspec.yaml')).writeAsString('''
name: host_app
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.10.0
''');
  await File(
    p.join(
      hostRootPath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    ),
  ).writeAsString('// generated runtime setup');
}

Future<void> _writeAwsEnvironmentState(
  LocalCliStateStore stateStore,
  String rootPath, {
  String environmentName = 'my-aws-prod',
}) async {
  await stateStore.writeEnvironmentState(
    rootPath,
    LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: null,
      activeEnvironment: environmentName,
      cloudEnvironments: <CloudEnvironmentConfiguration>[
        CloudEnvironmentConfiguration(
          name: environmentName,
          provider: 'aws',
          values: <String, dynamic>{
            'bucket': 'mini-program-prod',
            'region': 'us-east-1',
            'artifactsPrefix': 'artifacts',
            'metadataPrefix': 'metadata',
            'apiBaseUrl': 'https://api.example.com/api/',
            'requireAccessKeys': true,
          },
          configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        ),
      ],
      initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    ),
  );
}

Future<void> _writeFirebaseEnvironmentState(
  LocalCliStateStore stateStore,
  String rootPath, {
  String environmentName = 'my-firebase-prod',
}) async {
  await stateStore.writeEnvironmentState(
    rootPath,
    LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: null,
      activeEnvironment: environmentName,
      cloudEnvironments: <CloudEnvironmentConfiguration>[
        CloudEnvironmentConfiguration(
          name: environmentName,
          provider: 'firebase',
          values: <String, dynamic>{
            'projectId': 'coupon-prod',
            'region': 'asia-south1',
          },
          configuredAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
        ),
      ],
      initializedAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
    ),
  );
}

Future<void> _initializeBackendWorkspaceState(
  LocalCliStateStore stateStore,
  String backendRoot,
) async {
  await Directory(
    p.join(backendRoot, 'backend', 'api'),
  ).create(recursive: true);
  await Directory(
    p.join(backendRoot, 'backend', 'local_backend_service', 'bin'),
  ).create(recursive: true);
  await File(
    p.join(
      backendRoot,
      'backend',
      'local_backend_service',
      'bin',
      'server.dart',
    ),
  ).writeAsString('void main() {}');
  await stateStore.writeGlobalBackendWorkspaceState(
    LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: backendRoot,
      apiRootPath: p.join(backendRoot, 'backend', 'api'),
      serviceDirectoryPath: p.join(
        backendRoot,
        'backend',
        'local_backend_service',
      ),
      initializedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
    ),
  );
}

Future<void> _writeStaleLocalBackendWorkspaceState(
  LocalCliStateStore stateStore,
  String rootPath,
) {
  return stateStore.writeBackendWorkspaceState(
    rootPath,
    LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: rootPath,
      apiRootPath: p.join(rootPath, 'backend', 'api'),
      serviceDirectoryPath: p.join(
        rootPath,
        'backend',
        'local_backend_service',
      ),
      initializedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
    ),
  );
}
