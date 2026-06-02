part of '../mini_program_cloud_controller.dart';

class MiniProgramCloudController {
  MiniProgramCloudController({
    MiniProgramCloudProcessRunner processRunner =
        _defaultMiniProgramCloudProcessRunner,
    http.Client? httpClient,
  }) : _processRunner = processRunner,
       _httpClient = httpClient ?? http.Client();

  final MiniProgramCloudProcessRunner _processRunner;
  final http.Client _httpClient;

  Future<MiniProgramCloudDeployResult> deploy(
    MiniProgramCloudDeployRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final backendProjectRootPath = await _ensureAwsBackendProject(
      request.resolvedEnvironmentState,
    );

    await _runSamCommand(settings, <String>[
      'build',
      '--template-file',
      p.join(backendProjectRootPath, 'template.yaml'),
    ], workingDirectory: backendProjectRootPath);

    final parameterOverrides = <String>[
      'ArtifactBucketName=${settings.bucketName}',
      'ArtifactsPrefix=${settings.artifactsPrefix}',
      'MetadataPrefix=${settings.metadataPrefix}',
      'StageName=${settings.stageName}',
      'FunctionTimeoutSeconds=${settings.functionTimeoutSeconds}',
      'FunctionMemorySize=${settings.functionMemorySize}',
      'LogLevel=${settings.logLevel}',
      'RequireMiniProgramAccessKeys=${settings.requireAccessKeys}',
    ];
    await _runSamCommand(settings, <String>[
      'deploy',
      '--template-file',
      p.join(backendProjectRootPath, 'template.yaml'),
      '--stack-name',
      settings.stackName,
      '--region',
      settings.region,
      '--capabilities',
      'CAPABILITY_IAM',
      '--s3-bucket',
      settings.samS3Bucket,
      '--parameter-overrides',
      ...parameterOverrides,
      '--no-confirm-changeset',
      '--no-fail-on-empty-changeset',
    ], workingDirectory: backendProjectRootPath);

    final stack = await _describeStack(settings);
    if (stack == null) {
      throw const MiniProgramCloudException(
        'SAM deploy finished but the AWS CloudFormation stack could not be described.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    final health = await _probeHealth(outputs['HealthUrl']);

    return MiniProgramCloudDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      bucketName: settings.bucketName,
      backendProjectRootPath: backendProjectRootPath,
      outputs: outputs,
      apiBaseUrl: outputs['BackendApiBaseUrl'],
      healthUrl: outputs['HealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      deployedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<MiniProgramCloudStatusResult> status(
    MiniProgramCloudStatusRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final stack = await _describeStack(settings);
    if (stack == null) {
      return MiniProgramCloudStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        outputs: const <String, String>{},
      );
    }

    final outputs = _extractStackOutputs(stack);
    final health = await _probeHealth(outputs['HealthUrl']);
    return MiniProgramCloudStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      stackStatusReason: stack['StackStatusReason']?.toString(),
      outputs: outputs,
      apiBaseUrl: outputs['BackendApiBaseUrl'],
      healthUrl: outputs['HealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
    );
  }

  Future<MiniProgramCloudOutputsResult> outputs(
    MiniProgramCloudOutputsRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final stack = await _describeStack(settings);
    if (stack == null) {
      throw MiniProgramCloudException(
        'AWS stack "${settings.stackName}" was not found in region '
        '"${settings.region}". Run `miniprogram cloud deploy` first.',
      );
    }

    return MiniProgramCloudOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      outputs: _extractStackOutputs(stack),
    );
  }

  Future<MiniProgramCloudLogsResult> logs(
    MiniProgramCloudLogsRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final lambdaFunctionName = await _resolveLambdaFunctionName(settings);
    if (lambdaFunctionName == null) {
      throw MiniProgramCloudException(
        'No Lambda function resource was found for stack "${settings.stackName}". '
        'Run `miniprogram cloud deploy` first.',
      );
    }

    final result = await _runCommand('aws', <String>[
      ..._awsGlobalArguments(settings),
      'logs',
      'tail',
      '/aws/lambda/$lambdaFunctionName',
      '--since',
      request.since,
    ]);
    _requireSuccess(
      executable: 'aws',
      arguments: <String>[
        ..._awsGlobalArguments(settings),
        'logs',
        'tail',
        '/aws/lambda/$lambdaFunctionName',
        '--since',
        request.since,
      ],
      result: result,
      toolLabel: 'AWS CLI',
    );

    return MiniProgramCloudLogsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      lambdaFunctionName: lambdaFunctionName,
      since: request.since,
      stdoutText: '${result.stdout}'.trim(),
      stderrText: '${result.stderr}'.trim(),
    );
  }

  Future<MiniProgramCloudDestroyResult> destroy(
    MiniProgramCloudDestroyRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'delete-stack',
      '--stack-name',
      settings.stackName,
    ], allowEmptyJsonOutput: true);
    await _runAwsCommand(settings, <String>[
      'cloudformation',
      'wait',
      'stack-delete-complete',
      '--stack-name',
      settings.stackName,
    ]);

    return MiniProgramCloudDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      deletedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<MiniProgramCloudDoctorResult> doctor(
    MiniProgramCloudDoctorRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final checks = <MiniprogramDoctorCheck>[];

    checks.add(await _checkCommandAvailable('aws', <String>['--version']));
    checks.add(await _checkCommandAvailable('sam', <String>['--version']));
    checks.add(await _checkCommandAvailable('node', <String>['--version']));

    checks.add(await _checkAwsIdentity(settings));
    checks.add(await _checkBucketVersioning(settings));
    checks.add(await _checkCloudStack(settings));

    return MiniProgramCloudDoctorResult(checks: checks);
  }

  Future<MiniProgramCloudRollbackResult> rollback(
    MiniProgramCloudRollbackRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateRollbackVersion(request.version);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final releaseKey = _objectJoin(
      settings.metadataPrefix,
      'releases',
      request.miniProgramId,
      '${request.version}.json',
    );
    final catalogKey = _objectJoin(
      settings.metadataPrefix,
      'catalog',
      '${request.miniProgramId}.json',
    );

    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_rollback_',
    );
    try {
      final releaseFile = p.join(tempDirectory.path, 'release.json');
      final catalogFile = p.join(tempDirectory.path, 'catalog.json');
      final updatedCatalogFile = p.join(
        tempDirectory.path,
        'catalog.updated.json',
      );

      await _downloadObject(
        settings,
        key: releaseKey,
        destinationPath: releaseFile,
      );
      await _downloadObject(
        settings,
        key: catalogKey,
        destinationPath: catalogFile,
      );

      final catalogJson = _readJsonFile(catalogFile);
      catalogJson['latestVersion'] = request.version;
      catalogJson['releaseKey'] = releaseKey;
      catalogJson['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
      await File(
        updatedCatalogFile,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(catalogJson));

      await _putJsonObject(
        settings,
        key: catalogKey,
        localSourcePath: updatedCatalogFile,
        cacheControl: 'no-cache, no-store, must-revalidate',
      );

      return MiniProgramCloudRollbackResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        miniProgramId: request.miniProgramId,
        version: request.version,
        bucketName: settings.bucketName,
        region: settings.region,
        catalogKey: catalogKey,
        releaseKey: releaseKey,
        rolledBackAtUtc: DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<MiniProgramAccessKeyCreateResult> createAccessKey(
    MiniProgramAccessKeyCreateRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    _validateSafeSegment(request.keyId, 'keyId');
    final accessKey = _normalizeAccessKey(
      request.accessKey ?? _generateMiniProgramAccessKey(),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final policyKey = _accessPolicyKey(settings, request.miniProgramId);
    final policy = await _readAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
    );
    final keys = _accessPolicyKeys(policy);
    if (keys.any((entry) => entry.id == request.keyId && entry.active)) {
      throw MiniProgramCloudException(
        'MiniProgram access key "${request.keyId}" already exists for '
        '${request.miniProgramId}. Revoke or rotate it first.',
      );
    }
    keys.add(
      MiniProgramAccessKeyEntry(
        id: request.keyId,
        sha256: _sha256Hex(accessKey),
        enabled: true,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    await _writeAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
      keys: keys,
      updatedAtUtc: now,
    );

    return MiniProgramAccessKeyCreateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      policyKey: policyKey,
      keyId: request.keyId,
      accessKey: accessKey,
      createdAtUtc: now,
    );
  }

  Future<MiniProgramAccessKeyListResult> listAccessKeys(
    MiniProgramAccessKeyListRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final policy = await _readAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
    );
    final keys = _accessPolicyKeys(policy)
      ..sort((a, b) => a.id.compareTo(b.id));
    return MiniProgramAccessKeyListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      policyKey: _accessPolicyKey(settings, request.miniProgramId),
      policyExists: policy != null,
      keys: keys,
    );
  }

  Future<MiniProgramAccessKeyRevokeResult> revokeAccessKey(
    MiniProgramAccessKeyRevokeRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    _validateSafeSegment(request.keyId, 'keyId');
    final policy = await _requireAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
    );
    final keys = _accessPolicyKeys(policy);
    final index = keys.indexWhere((entry) => entry.id == request.keyId);
    if (index == -1) {
      throw MiniProgramCloudException(
        'No MiniProgram access key "${request.keyId}" was found for '
        '${request.miniProgramId}.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = keys[index];
    keys[index] = MiniProgramAccessKeyEntry(
      id: existing.id,
      sha256: existing.sha256,
      enabled: false,
      createdAtUtc: existing.createdAtUtc,
      updatedAtUtc: now,
      revokedAtUtc: existing.revokedAtUtc ?? now,
    );
    await _writeAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
      keys: keys,
      updatedAtUtc: now,
    );

    return MiniProgramAccessKeyRevokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      policyKey: _accessPolicyKey(settings, request.miniProgramId),
      keyId: request.keyId,
      revokedAtUtc: now,
    );
  }

  Future<MiniProgramAccessKeyRotateResult> rotateAccessKey(
    MiniProgramAccessKeyRotateRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    _validateSafeSegment(request.keyId, 'keyId');
    final now = DateTime.now().toUtc().toIso8601String();
    final newKeyId = request.newKeyId?.trim().isNotEmpty == true
        ? request.newKeyId!.trim()
        : '${request.keyId}-${_compactTimestamp(DateTime.now().toUtc())}';
    _validateSafeSegment(newKeyId, 'newKeyId');
    if (newKeyId == request.keyId) {
      throw const MiniProgramCloudException(
        'Rotating a MiniProgram access key requires a different --new-key-id.',
      );
    }

    final policy = await _requireAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
    );
    final keys = _accessPolicyKeys(policy);
    final oldIndex = keys.indexWhere((entry) => entry.id == request.keyId);
    if (oldIndex == -1) {
      throw MiniProgramCloudException(
        'No MiniProgram access key "${request.keyId}" was found for '
        '${request.miniProgramId}.',
      );
    }
    if (keys.any((entry) => entry.id == newKeyId && entry.active)) {
      throw MiniProgramCloudException(
        'MiniProgram access key "$newKeyId" already exists for '
        '${request.miniProgramId}.',
      );
    }

    final accessKey = _normalizeAccessKey(
      request.accessKey ?? _generateMiniProgramAccessKey(),
    );
    final existing = keys[oldIndex];
    keys[oldIndex] = MiniProgramAccessKeyEntry(
      id: existing.id,
      sha256: existing.sha256,
      enabled: false,
      createdAtUtc: existing.createdAtUtc,
      updatedAtUtc: now,
      revokedAtUtc: existing.revokedAtUtc ?? now,
    );
    keys.add(
      MiniProgramAccessKeyEntry(
        id: newKeyId,
        sha256: _sha256Hex(accessKey),
        enabled: true,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    await _writeAccessPolicy(
      settings,
      miniProgramId: request.miniProgramId,
      keys: keys,
      updatedAtUtc: now,
    );

    return MiniProgramAccessKeyRotateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      policyKey: _accessPolicyKey(settings, request.miniProgramId),
      revokedKeyId: request.keyId,
      newKeyId: newKeyId,
      accessKey: accessKey,
      rotatedAtUtc: now,
    );
  }

  Future<MiniProgramCloudAppListResult> listApps(
    MiniProgramCloudAppListRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final catalogPrefix = _objectJoin(settings.metadataPrefix, 'catalog');
    final keys = await _listObjectKeys(settings, '$catalogPrefix/');
    final apps = <MiniProgramCloudAppSummary>[];
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_apps_',
    );
    try {
      for (final key in keys.where((key) => key.endsWith('.json'))) {
        final miniProgramId = _catalogKeyToMiniProgramId(
          settings,
          catalogKey: key,
        );
        if (miniProgramId == null) {
          continue;
        }
        Map<String, dynamic>? catalog;
        final destinationPath = p.join(
          tempDirectory.path,
          '${miniProgramId.hashCode}.json',
        );
        if (await _tryDownloadObject(
          settings,
          key: key,
          destinationPath: destinationPath,
        )) {
          catalog = _readJsonFile(destinationPath);
        }
        apps.add(
          MiniProgramCloudAppSummary(
            miniProgramId: miniProgramId,
            catalogKey: key,
            latestVersion: catalog?['latestVersion']?.toString(),
            updatedAtUtc: catalog?['updatedAtUtc']?.toString(),
          ),
        );
      }
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
    apps.sort((a, b) => a.miniProgramId.compareTo(b.miniProgramId));
    return MiniProgramCloudAppListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      bucketName: settings.bucketName,
      region: settings.region,
      apps: apps,
    );
  }

  Future<MiniProgramCloudAppInfoResult> appInfo(
    MiniProgramCloudAppInfoRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final catalogKey = _catalogKey(settings, request.miniProgramId);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_app_info_',
    );
    try {
      final catalogFile = p.join(tempDirectory.path, 'catalog.json');
      final catalogFound = await _tryDownloadObject(
        settings,
        key: catalogKey,
        destinationPath: catalogFile,
      );
      if (!catalogFound) {
        throw MiniProgramCloudException(
          'No active cloud app catalog was found for ${request.miniProgramId}.',
        );
      }
      final catalog = _readJsonFile(catalogFile);
      final releaseKey = catalog['releaseKey']?.toString().trim();
      Map<String, dynamic>? release;
      if (releaseKey != null && releaseKey.isNotEmpty) {
        final releaseFile = p.join(tempDirectory.path, 'release.json');
        if (await _tryDownloadObject(
          settings,
          key: releaseKey,
          destinationPath: releaseFile,
        )) {
          release = _readJsonFile(releaseFile);
        }
      }
      final accessPolicy = await _readAccessPolicy(
        settings,
        miniProgramId: request.miniProgramId,
      );
      final accessKeys = _accessPolicyKeys(accessPolicy);
      return MiniProgramCloudAppInfoResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        miniProgramId: request.miniProgramId,
        bucketName: settings.bucketName,
        region: settings.region,
        catalogKey: catalogKey,
        catalog: catalog,
        releaseKey: releaseKey?.isEmpty == true ? null : releaseKey,
        release: release,
        accessPolicyKey: accessPolicy == null
            ? null
            : _accessPolicyKey(settings, request.miniProgramId),
        accessKeyCount: accessKeys.length,
        activeAccessKeyCount: accessKeys.where((entry) => entry.active).length,
      );
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<MiniProgramCloudAppDisableResult> disableApp(
    MiniProgramCloudAppDisableRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final catalogKey = _catalogKey(settings, request.miniProgramId);
    final disabledCatalogKey = _objectJoin(
      settings.metadataPrefix,
      'disabled',
      '${request.miniProgramId}.json',
    );
    final disabledAtUtc = DateTime.now().toUtc().toIso8601String();
    if (!request.confirmed) {
      return MiniProgramCloudAppDisableResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        miniProgramId: request.miniProgramId,
        bucketName: settings.bucketName,
        region: settings.region,
        catalogKey: catalogKey,
        disabledCatalogKey: disabledCatalogKey,
        disabledAtUtc: disabledAtUtc,
        dryRun: true,
      );
    }

    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_app_disable_',
    );
    try {
      final catalogFile = p.join(tempDirectory.path, 'catalog.json');
      final disabledCatalogFile = p.join(
        tempDirectory.path,
        'catalog.disabled.json',
      );
      final catalogFound = await _tryDownloadObject(
        settings,
        key: catalogKey,
        destinationPath: catalogFile,
      );
      if (!catalogFound) {
        throw MiniProgramCloudException(
          'No active cloud app catalog was found for ${request.miniProgramId}.',
        );
      }
      final catalog = _readJsonFile(catalogFile);
      catalog['disabledAtUtc'] = disabledAtUtc;
      catalog['disabledBy'] = 'mini_program_tooling';
      await File(
        disabledCatalogFile,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(catalog));
      await _putJsonObject(
        settings,
        key: disabledCatalogKey,
        localSourcePath: disabledCatalogFile,
        cacheControl: 'no-cache, no-store, must-revalidate',
      );
      await _deleteObject(settings, key: catalogKey);
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }

    return MiniProgramCloudAppDisableResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      catalogKey: catalogKey,
      disabledCatalogKey: disabledCatalogKey,
      disabledAtUtc: disabledAtUtc,
      dryRun: false,
    );
  }

  Future<MiniProgramCloudAppDeleteResult> deleteApp(
    MiniProgramCloudAppDeleteRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final keys = <String>{
      ...await _listObjectKeys(
        settings,
        '${_objectJoin(settings.artifactsPrefix, request.miniProgramId)}/',
      ),
      ...await _listObjectKeys(
        settings,
        '${_objectJoin(settings.metadataPrefix, 'releases', request.miniProgramId)}/',
      ),
      _catalogKey(settings, request.miniProgramId),
      _accessPolicyKey(settings, request.miniProgramId),
      _objectJoin(
        settings.metadataPrefix,
        'disabled',
        '${request.miniProgramId}.json',
      ),
    }.toList()..sort();

    if (request.confirmed) {
      for (final key in keys) {
        await _deleteObject(settings, key: key);
      }
    }

    return MiniProgramCloudAppDeleteResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: settings.bucketName,
      region: settings.region,
      deletedKeys: keys,
      dryRun: !request.confirmed,
      deletedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<MiniprogramDoctorCheck> _checkCommandAvailable(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await _runCommand(executable, arguments);
      if (result.exitCode == 0) {
        final output = '${result.stdout}'.trim();
        final errorOutput = '${result.stderr}'.trim();
        final summary = output.isNotEmpty ? output : errorOutput;
        return MiniprogramDoctorCheck(
          label: '$executable available',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: summary.isEmpty ? 'available' : summary,
        );
      }
      return MiniprogramDoctorCheck(
        label: '$executable available',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'failed to run',
        detail: '${result.stderr}'.trim(),
      );
    } on ProcessException catch (error) {
      return MiniprogramDoctorCheck(
        label: '$executable available',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'not found on PATH',
        detail: error.toString(),
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkAwsIdentity(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final identity = await _runAwsJsonCommand(settings, <String>[
        'sts',
        'get-caller-identity',
        '--output',
        'json',
      ]);
      final account = identity['Account']?.toString() ?? 'unknown';
      final arn = identity['Arn']?.toString() ?? 'unknown';
      return MiniprogramDoctorCheck(
        label: 'AWS credentials',
        status: MiniprogramDoctorCheckStatus.ok,
        summary: 'resolved caller identity',
        detail: 'Account: $account\nARN: $arn',
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS credentials',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not resolve caller identity',
        detail: error.message,
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkBucketVersioning(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final response = await _runAwsJsonCommand(settings, <String>[
        's3api',
        'get-bucket-versioning',
        '--bucket',
        settings.bucketName,
        '--output',
        'json',
      ]);
      final status = response['Status']?.toString().trim();
      if (status == 'Enabled') {
        return MiniprogramDoctorCheck(
          label: 'AWS artifact bucket',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: 'versioning enabled',
          detail: 'Bucket: ${settings.bucketName}\nRegion: ${settings.region}',
        );
      }
      return MiniprogramDoctorCheck(
        label: 'AWS artifact bucket',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'versioning not enabled',
        detail: 'Bucket: ${settings.bucketName}\nRegion: ${settings.region}',
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS artifact bucket',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not inspect bucket',
        detail: error.message,
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkCloudStack(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final stack = await _describeStack(settings);
      if (stack == null) {
        return MiniprogramDoctorCheck(
          label: 'AWS cloud stack',
          status: MiniprogramDoctorCheckStatus.warning,
          summary: 'stack not deployed yet',
          detail: 'Stack: ${settings.stackName}\nRegion: ${settings.region}',
        );
      }
      final outputs = _extractStackOutputs(stack);
      final health = await _probeHealth(outputs['HealthUrl']);
      final status = stack['StackStatus']?.toString() ?? 'unknown';
      return MiniprogramDoctorCheck(
        label: 'AWS cloud stack',
        status: health.healthy == false
            ? MiniprogramDoctorCheckStatus.warning
            : MiniprogramDoctorCheckStatus.ok,
        summary: status,
        detail: [
          'Stack: ${settings.stackName}',
          if (outputs['BackendApiBaseUrl'] != null)
            'BackendApiBaseUrl: ${outputs['BackendApiBaseUrl']}',
          if (health.healthy != null) 'Healthy: ${health.healthy}',
          if (health.statusCode != null)
            'Health status code: ${health.statusCode}',
          if (health.error != null) 'Health detail: ${health.error}',
        ].join('\n'),
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS cloud stack',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not inspect stack',
        detail: error.message,
      );
    }
  }

  Future<String> _ensureAwsBackendProject(
    ResolvedLocalCliEnvironmentState resolvedEnvironmentState,
  ) async {
    final projectRootPath = p.join(
      resolvedEnvironmentState.rootPath,
      '.mini_program',
      'cloud',
      'aws_backend',
    );
    await Directory(p.join(projectRootPath, 'src')).create(recursive: true);

    final repoInfraRoot = resolvedEnvironmentState.state.repoRootPath == null
        ? null
        : p.join(
            resolvedEnvironmentState.state.repoRootPath!,
            'infra',
            'aws',
            'mini_program_cloud_api',
          );
    final copiedFromRepo =
        repoInfraRoot != null &&
        await _copyRepoAwsBackendProject(
          sourceRootPath: repoInfraRoot,
          destinationRootPath: projectRootPath,
        );
    if (!copiedFromRepo) {
      await File(
        p.join(projectRootPath, 'template.yaml'),
      ).writeAsString(_bundledAwsTemplateYaml);
      await File(
        p.join(projectRootPath, 'src', 'handler.mjs'),
      ).writeAsString(_bundledAwsHandlerSource);
      await File(
        p.join(projectRootPath, 'src', 'package.json'),
      ).writeAsString(_bundledAwsPackageJson);
    }

    return projectRootPath;
  }

  Future<bool> _copyRepoAwsBackendProject({
    required String sourceRootPath,
    required String destinationRootPath,
  }) async {
    final sourceTemplate = File(p.join(sourceRootPath, 'template.yaml'));
    final sourceHandler = File(p.join(sourceRootPath, 'src', 'handler.mjs'));
    final sourcePackage = File(p.join(sourceRootPath, 'src', 'package.json'));
    if (!await sourceTemplate.exists() ||
        !await sourceHandler.exists() ||
        !await sourcePackage.exists()) {
      return false;
    }

    await File(
      p.join(destinationRootPath, 'template.yaml'),
    ).writeAsString(await sourceTemplate.readAsString());
    await File(
      p.join(destinationRootPath, 'src', 'handler.mjs'),
    ).writeAsString(await sourceHandler.readAsString());
    await File(
      p.join(destinationRootPath, 'src', 'package.json'),
    ).writeAsString(await sourcePackage.readAsString());
    return true;
  }

  Future<ProcessResult> _runCommand(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      return await _processRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw MiniProgramCloudException(
        'Failed to launch $executable. Make sure it is installed and on your PATH.\n$error',
      );
    }
  }

  Future<void> _runSamCommand(
    AwsCloudStackSettings settings,
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final arguments = <String>[
      ...commandArguments,
      if (settings.awsProfile != null) '--profile',
      if (settings.awsProfile != null) settings.awsProfile!,
    ];
    final result = await _runCommand(
      'sam',
      arguments,
      workingDirectory: workingDirectory,
    );
    _requireSuccess(
      executable: 'sam',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS SAM CLI',
    );
  }

  Future<void> _runAwsCommand(
    AwsCloudStackSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _runCommand('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    AwsCloudStackSettings settings,
    List<String> commandArguments, {
    bool allowEmptyJsonOutput = false,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _runCommand('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      if (allowEmptyJsonOutput) {
        return <String, dynamic>{};
      }
      throw MiniProgramCloudException(
        'AWS CLI returned no JSON output for command: aws ${arguments.join(' ')}',
      );
    }

    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw MiniProgramCloudException(
        'AWS CLI returned non-object JSON for command: aws ${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _downloadObject(
    AwsCloudStackSettings settings, {
    required String key,
    required String destinationPath,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      's3api',
      'get-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      destinationPath,
      '--output',
      'json',
    ];
    final result = await _runCommand('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<void> _putJsonObject(
    AwsCloudStackSettings settings, {
    required String key,
    required String localSourcePath,
    required String cacheControl,
  }) async {
    await _runAwsJsonCommand(settings, <String>[
      's3api',
      'put-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      '--body',
      localSourcePath,
      '--cache-control',
      cacheControl,
      '--content-type',
      'application/json',
      '--output',
      'json',
    ]);
  }

  Future<void> _deleteObject(
    AwsCloudStackSettings settings, {
    required String key,
  }) async {
    await _runAwsJsonCommand(settings, <String>[
      's3api',
      'delete-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      '--output',
      'json',
    ], allowEmptyJsonOutput: true);
  }

  Future<bool> _tryDownloadObject(
    AwsCloudStackSettings settings, {
    required String key,
    required String destinationPath,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      's3api',
      'get-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      destinationPath,
      '--output',
      'json',
    ];
    final result = await _runCommand('aws', arguments);
    if (result.exitCode == 0) {
      return true;
    }
    final stderrText = '${result.stderr}';
    if (stderrText.contains('NoSuchKey') ||
        stderrText.contains('Not Found') ||
        stderrText.contains('404')) {
      return false;
    }
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    return false;
  }

  Future<List<String>> _listObjectKeys(
    AwsCloudStackSettings settings,
    String prefix,
  ) async {
    final keys = <String>[];
    String? continuationToken;
    do {
      final response = await _runAwsJsonCommand(settings, <String>[
        's3api',
        'list-objects-v2',
        '--bucket',
        settings.bucketName,
        '--prefix',
        prefix,
        if (continuationToken != null) '--continuation-token',
        if (continuationToken != null) continuationToken,
        '--output',
        'json',
      ]);
      final contents = response['Contents'];
      if (contents is List) {
        for (final object in contents) {
          if (object is! Map) {
            continue;
          }
          final key = object['Key']?.toString().trim();
          if (key != null && key.isNotEmpty) {
            keys.add(key);
          }
        }
      }
      continuationToken = response['NextContinuationToken']?.toString();
      if (continuationToken != null && continuationToken.trim().isEmpty) {
        continuationToken = null;
      }
    } while (continuationToken != null);
    keys.sort();
    return keys;
  }

  Future<Map<String, dynamic>?> _readAccessPolicy(
    AwsCloudStackSettings settings, {
    required String miniProgramId,
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_access_policy_',
    );
    try {
      final policyFile = p.join(tempDirectory.path, 'access_keys.json');
      final found = await _tryDownloadObject(
        settings,
        key: _accessPolicyKey(settings, miniProgramId),
        destinationPath: policyFile,
      );
      if (!found) {
        return null;
      }
      return _readJsonFile(policyFile);
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<Map<String, dynamic>> _requireAccessPolicy(
    AwsCloudStackSettings settings, {
    required String miniProgramId,
  }) async {
    final policy = await _readAccessPolicy(
      settings,
      miniProgramId: miniProgramId,
    );
    if (policy == null) {
      throw MiniProgramCloudException(
        'No MiniProgram access-key policy was found for $miniProgramId. Run '
        '`miniprogram access-key create $miniProgramId --key-id <id>` first.',
      );
    }
    return policy;
  }

  Future<void> _writeAccessPolicy(
    AwsCloudStackSettings settings, {
    required String miniProgramId,
    required List<MiniProgramAccessKeyEntry> keys,
    required String updatedAtUtc,
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_access_policy_write_',
    );
    try {
      final policyFile = p.join(tempDirectory.path, 'access_keys.json');
      final sortedKeys = keys.toList()..sort((a, b) => a.id.compareTo(b.id));
      await File(policyFile).writeAsString(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'schemaVersion': 1,
          'miniProgramId': miniProgramId,
          'updatedAtUtc': updatedAtUtc,
          'keys': sortedKeys.map(_accessKeyEntryToJson).toList(),
        }),
      );
      await _putJsonObject(
        settings,
        key: _accessPolicyKey(settings, miniProgramId),
        localSourcePath: policyFile,
        cacheControl: 'no-cache, no-store, must-revalidate',
      );
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Map<String, Object?> _accessKeyEntryToJson(MiniProgramAccessKeyEntry entry) {
    return <String, Object?>{
      'id': entry.id,
      'sha256': entry.sha256,
      'enabled': entry.enabled,
      'createdAtUtc': entry.createdAtUtc,
      'updatedAtUtc': entry.updatedAtUtc,
      if (entry.revokedAtUtc != null) 'revokedAtUtc': entry.revokedAtUtc,
    };
  }

  List<MiniProgramAccessKeyEntry> _accessPolicyKeys(
    Map<String, dynamic>? policy,
  ) {
    final rawKeys = policy?['keys'];
    if (rawKeys == null) {
      return <MiniProgramAccessKeyEntry>[];
    }
    if (rawKeys is! List) {
      throw const MiniProgramCloudException(
        'MiniProgram access-key policy must contain a "keys" list.',
      );
    }
    return rawKeys.map((rawEntry) {
      if (rawEntry is! Map) {
        throw const MiniProgramCloudException(
          'MiniProgram access-key policy contains a non-object key entry.',
        );
      }
      final entry = rawEntry.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      String requiredString(String key) {
        final value = entry[key]?.toString().trim();
        if (value == null || value.isEmpty) {
          throw MiniProgramCloudException(
            'MiniProgram access-key policy entry is missing "$key".',
          );
        }
        return value;
      }

      return MiniProgramAccessKeyEntry(
        id: requiredString('id'),
        sha256: requiredString('sha256'),
        enabled: entry['enabled'] != false,
        createdAtUtc: requiredString('createdAtUtc'),
        updatedAtUtc: requiredString('updatedAtUtc'),
        revokedAtUtc: entry['revokedAtUtc']?.toString(),
      );
    }).toList();
  }

  String _normalizeAccessKey(String rawAccessKey) {
    final accessKey = rawAccessKey.trim();
    if (accessKey.length < 24 || accessKey.length > 128) {
      throw const MiniProgramCloudException(
        'MiniProgram access keys must be between 24 and 128 characters.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(accessKey)) {
      throw const MiniProgramCloudException(
        'MiniProgram access keys may only contain letters, numbers, dot, '
        'underscore, and dash.',
      );
    }
    return accessKey;
  }

  String _generateMiniProgramAccessKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'mpk_live_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String _accessPolicyKey(
    AwsCloudStackSettings settings,
    String miniProgramId,
  ) => _objectJoin(
    settings.metadataPrefix,
    'access_keys',
    '$miniProgramId.json',
  );

  String _catalogKey(AwsCloudStackSettings settings, String miniProgramId) =>
      _objectJoin(settings.metadataPrefix, 'catalog', '$miniProgramId.json');

  String? _catalogKeyToMiniProgramId(
    AwsCloudStackSettings settings, {
    required String catalogKey,
  }) {
    final prefix = '${_objectJoin(settings.metadataPrefix, 'catalog')}/';
    if (!catalogKey.startsWith(prefix) || !catalogKey.endsWith('.json')) {
      return null;
    }
    final miniProgramId = catalogKey.substring(
      prefix.length,
      catalogKey.length - '.json'.length,
    );
    return miniProgramId.isEmpty ? null : miniProgramId;
  }

  String _compactTimestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }

  Future<Map<String, dynamic>?> _describeStack(
    AwsCloudStackSettings settings,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      'cloudformation',
      'describe-stacks',
      '--stack-name',
      settings.stackName,
      '--output',
      'json',
    ];
    final result = await _runCommand('aws', arguments);
    if (result.exitCode != 0) {
      final stderrText = '${result.stderr}'.trim();
      if (stderrText.contains('does not exist') ||
          stderrText.contains('Stack with id') ||
          stderrText.contains('ValidationError')) {
        return null;
      }
      _requireSuccess(
        executable: 'aws',
        arguments: arguments,
        result: result,
        toolLabel: 'AWS CLI',
      );
    }

    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw MiniProgramCloudException(
        'AWS CLI returned non-object JSON for stack describe command.',
      );
    }
    final stacks = decoded['Stacks'];
    if (stacks is! List || stacks.isEmpty || stacks.first is! Map) {
      return null;
    }
    return (stacks.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<String?> _resolveLambdaFunctionName(
    AwsCloudStackSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'describe-stack-resources',
      '--stack-name',
      settings.stackName,
      '--output',
      'json',
    ]);
    final resources = response['StackResources'];
    if (resources is! List) {
      return null;
    }
    for (final resource in resources) {
      if (resource is! Map) {
        continue;
      }
      final mapped = resource.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (mapped['ResourceType'] == 'AWS::Lambda::Function') {
        final physicalId = mapped['PhysicalResourceId']?.toString().trim();
        if (physicalId != null && physicalId.isNotEmpty) {
          return physicalId;
        }
      }
    }
    return null;
  }

  Future<_HealthProbeResult> _probeHealth(String? healthUrl) async {
    if (healthUrl == null || healthUrl.trim().isEmpty) {
      return const _HealthProbeResult();
    }

    try {
      final response = await _httpClient
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));
      return _HealthProbeResult(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      return _HealthProbeResult(healthy: false, error: error.toString());
    }
  }

  Map<String, String> _extractStackOutputs(Map<String, dynamic> stack) {
    final outputs = <String, String>{};
    final rawOutputs = stack['Outputs'];
    if (rawOutputs is! List) {
      return outputs;
    }

    for (final output in rawOutputs) {
      if (output is! Map) {
        continue;
      }
      final mapped = output.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final key = mapped['OutputKey']?.toString().trim();
      final value = mapped['OutputValue']?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      outputs[key] = value;
    }
    final sortedKeys = outputs.keys.toList()..sort();
    return <String, String>{for (final key in sortedKeys) key: outputs[key]!};
  }

  List<String> _awsGlobalArguments(AwsCloudStackSettings settings) {
    final arguments = <String>['--region', settings.region];
    if (settings.awsProfile case final profile?
        when profile.trim().isNotEmpty) {
      arguments.addAll(<String>['--profile', profile]);
    }
    return arguments;
  }

  void _requireSuccess({
    required String executable,
    required List<String> arguments,
    required ProcessResult result,
    required String toolLabel,
  }) {
    if (result.exitCode == 0) {
      return;
    }
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    throw MiniProgramCloudException(
      '$toolLabel command failed.\n'
      'Command: $executable ${arguments.join(' ')}\n'
      'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
      'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
    );
  }

  Map<String, dynamic> _readJsonFile(String filePath) {
    final decoded = jsonDecode(File(filePath).readAsStringSync());
    if (decoded is! Map) {
      throw MiniProgramCloudException('Expected a JSON object in $filePath.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  void _validateRollbackVersion(String version) {
    try {
      Version.parse(version.trim());
    } on FormatException {
      throw MiniProgramCloudException(
        'Rollback version "$version" is not a valid semantic version.',
      );
    }
  }

  void _validateSafeSegment(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw MiniProgramCloudException('Path segment "$label" is invalid.');
    }
  }
}
