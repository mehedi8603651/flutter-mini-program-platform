part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterAwsOperations on PublisherBackendStarter {
  Future<PublisherBackendAwsDeployResult> _awsDeployImpl(
    PublisherBackendAwsDeployRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    await _assertAwsBackendPaths(settings.backendRootPath);
    await _runSamCommand(settings, <String>[
      'build',
      '--template-file',
      p.join(settings.backendRootPath, 'template.yaml'),
    ], workingDirectory: settings.backendRootPath);
    await _runSamCommand(settings, <String>[
      'deploy',
      '--template-file',
      p.join(settings.backendRootPath, 'template.yaml'),
      '--stack-name',
      settings.stackName,
      '--region',
      settings.region,
      '--capabilities',
      'CAPABILITY_IAM',
      '--s3-bucket',
      settings.samS3Bucket,
      '--parameter-overrides',
      'StageName=${settings.stageName}',
      '--no-confirm-changeset',
      '--no-fail-on-empty-changeset',
    ], workingDirectory: settings.backendRootPath);

    final stack = await _describeStack(settings);
    if (stack == null) {
      throw const PublisherBackendException(
        'SAM deploy finished but the publisher backend stack could not be described.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    final healthUrl = outputs['PublisherBackendHealthUrl'];
    final health = healthUrl == null || healthUrl.trim().isEmpty
        ? const _PublisherBackendHealth(healthy: false)
        : await _waitForHealthCheck(
            Uri.parse(healthUrl),
            timeout: _awsDeployHealthWaitTimeout,
            attemptTimeout: _awsDeployHealthAttemptTimeout,
            retryDelay: _awsDeployHealthRetryDelay,
          );
    final deployedAtUtc = _clock().toUtc().toIso8601String();
    final state = PublisherBackendAwsState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: settings.backendRootPath,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      samS3Bucket: settings.samS3Bucket,
      outputs: outputs,
      deployedAtUtc: deployedAtUtc,
    );
    await _writeAwsState(rootPath, state);
    return PublisherBackendAwsDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      samS3Bucket: settings.samS3Bucket,
      backendRootPath: settings.backendRootPath,
      miniProgramRootPath: rootPath,
      outputs: outputs,
      backendBaseUrl: outputs['PublisherBackendBaseUrl'],
      healthUrl: outputs['PublisherBackendHealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      deployedAtUtc: deployedAtUtc,
    );
  }

  Future<PublisherBackendAwsStatusResult> _awsStatusImpl(
    PublisherBackendAwsStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final state = await _readAwsState(rootPath);
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        state: state,
        outputs: const <String, String>{},
      );
    }
    final outputs = _extractStackOutputs(stack);
    final healthUrl = outputs['PublisherBackendHealthUrl'];
    final health = healthUrl == null || healthUrl.trim().isEmpty
        ? const _PublisherBackendHealth(healthy: false)
        : await _probeHealth(Uri.parse(healthUrl));
    return PublisherBackendAwsStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      state: state,
      stackStatus: stack['StackStatus']?.toString(),
      stackStatusReason: stack['StackStatusReason']?.toString(),
      outputs: outputs,
      backendBaseUrl: outputs['PublisherBackendBaseUrl'],
      healthUrl: outputs['PublisherBackendHealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
    );
  }

  Future<PublisherBackendAwsOutputsResult> _awsOutputsImpl(
    PublisherBackendAwsOutputsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      throw PublisherBackendException(
        'AWS publisher backend stack "${settings.stackName}" was not found in '
        'region "${settings.region}". Run `miniprogram publisher-backend aws deploy` first.',
      );
    }
    return PublisherBackendAwsOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      outputs: _extractStackOutputs(stack),
    );
  }

  Future<PublisherBackendAwsSmokeResult> _awsSmokeImpl(
    PublisherBackendAwsSmokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        passed: false,
        routes: const <PublisherBackendAwsSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final backendBaseUrl = outputs['PublisherBackendBaseUrl']?.trim();
    if (backendBaseUrl == null || backendBaseUrl.isEmpty) {
      return PublisherBackendAwsSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        backendBaseUrl: backendBaseUrl,
        passed: false,
        routes: const <PublisherBackendAwsSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        error: 'PublisherBackendBaseUrl output is missing.',
      );
    }

    final baseUri = Uri.parse(backendBaseUrl);
    final routes = <PublisherBackendAwsSmokeRouteResult>[];
    for (final path in _publisherBackendAwsSmokeRoutePaths) {
      routes.add(
        await _probeSmokeRoute(
          method: 'GET',
          path: path,
          uri: _resolveBackendRoute(baseUri, path),
        ),
      );
    }
    if (request.includeWrite) {
      routes.add(
        await _probeSmokeWriteRoute(
          uri: _resolveBackendRoute(baseUri, '/coupon/redeem'),
          couponId: request.writeCouponId,
          userId: request.writeUserId,
        ),
      );
    }
    final passed = routes.every((route) => route.passed);
    return PublisherBackendAwsSmokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      backendBaseUrl: backendBaseUrl,
      passed: passed,
      routes: routes,
      includeWrite: request.includeWrite,
    );
  }

  Future<PublisherBackendAwsSeedResult> _awsSeedImpl(
    PublisherBackendAwsSeedRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        seeded: false,
        itemCount: 0,
        miniProgramId: settings.miniProgramId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        seeded: false,
        itemCount: 0,
        miniProgramId: settings.miniProgramId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final seedData = await _readAwsSeedData(settings);
    final items = _buildDynamoDbSeedItems(settings, seedData);
    await _batchWriteDynamoDbItems(
      settings: settings,
      tableName: tableName,
      items: items,
    );
    return PublisherBackendAwsSeedResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      seeded: true,
      itemCount: items.length,
      miniProgramId: settings.miniProgramId,
    );
  }

  Future<PublisherBackendAwsDataStatusResult> _awsDataStatusImpl(
    PublisherBackendAwsDataStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        available: false,
        miniProgramId: settings.miniProgramId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        available: false,
        miniProgramId: settings.miniProgramId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final table = await _describeDynamoDbTable(settings, tableName);
    final appRecordCount = await _queryDynamoDbCount(
      settings: settings,
      tableName: tableName,
      partitionKey: _appPartitionKey(settings.miniProgramId),
    );
    final redemptionCount = await _queryDynamoDbCount(
      settings: settings,
      tableName: tableName,
      partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
    );
    return PublisherBackendAwsDataStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      tableStatus: table['TableStatus']?.toString(),
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      available: true,
      miniProgramId: settings.miniProgramId,
    );
  }

  Future<PublisherBackendAwsDataExportResult> _awsDataExportImpl(
    PublisherBackendAwsDataExportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        exported: false,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        exported: false,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final appItems = await _queryDynamoDbItems(
      settings: settings,
      tableName: tableName,
      partitionKey: _appPartitionKey(settings.miniProgramId),
    );
    final redemptionItems = request.includeRedemptions
        ? await _queryDynamoDbItems(
            settings: settings,
            tableName: tableName,
            partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
          )
        : <Map<String, Object?>>[];
    final exportedAtUtc = _clock().toUtc().toIso8601String();
    final outputPath = _resolveAwsDataExportPath(settings, request.outputPath);
    final items = <Map<String, Object?>>[
      ..._sortedDynamoDbExportItems(appItems),
      ..._sortedDynamoDbExportItems(redemptionItems),
    ];
    final exportFile = File(outputPath);
    await exportFile.parent.create(recursive: true);
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'command': 'publisher-backend aws data export',
        'provider': request.environment.provider,
        'environmentName': request.environment.name,
        'stackName': settings.stackName,
        'region': settings.region,
        'miniProgramId': settings.miniProgramId,
        'storageMode': storageMode,
        'tableName': tableName,
        'exportedAtUtc': exportedAtUtc,
        'includeRedemptions': request.includeRedemptions,
        'appRecordCount': appItems.length,
        'redemptionCount': redemptionItems.length,
        'itemCount': items.length,
        'items': items,
      }),
    );
    return PublisherBackendAwsDataExportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      exported: true,
      miniProgramId: settings.miniProgramId,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: appItems.length,
      redemptionCount: redemptionItems.length,
      itemCount: items.length,
      outputPath: outputPath,
      exportedAtUtc: exportedAtUtc,
    );
  }

  Future<PublisherBackendAwsDataImportResult> _awsDataImportImpl(
    PublisherBackendAwsDataImportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final inputPath = p.normalize(p.absolute(request.inputPath));
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final importPlan = await _readAwsDataImportPlan(
      settings: settings,
      inputPath: inputPath,
      includeRedemptions: request.includeRedemptions,
    );
    if (!request.dryRun && importPlan.items.isNotEmpty) {
      await _batchWriteDynamoDbItems(
        settings: settings,
        tableName: tableName,
        items: importPlan.items,
      );
    }
    return PublisherBackendAwsDataImportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      succeeded: true,
      imported: !request.dryRun,
      dryRun: request.dryRun,
      miniProgramId: settings.miniProgramId,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: importPlan.appRecordCount,
      redemptionCount: importPlan.redemptionCount,
      skippedRedemptionCount: importPlan.skippedRedemptionCount,
      itemCount: importPlan.items.length,
      inputPath: inputPath,
    );
  }

  Future<PublisherBackendAwsDataRedemptionsResult> _awsDataRedemptionsImpl(
    PublisherBackendAwsDataRedemptionsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        available: false,
        miniProgramId: settings.miniProgramId,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        available: false,
        miniProgramId: settings.miniProgramId,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final records = await _queryDynamoDbItems(
      settings: settings,
      tableName: tableName,
      partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
    );
    final matched = _filterRedemptionRecords(
      records,
      couponId: request.couponId,
      userId: request.userId,
    );
    final returned = matched.take(request.limit).toList();
    return PublisherBackendAwsDataRedemptionsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      available: true,
      miniProgramId: settings.miniProgramId,
      limit: request.limit,
      matchedCount: matched.length,
      returnedCount: returned.length,
      records: returned,
      couponId: request.couponId,
      userId: request.userId,
    );
  }

  Future<PublisherBackendAwsLogsResult> _awsLogsImpl(
    PublisherBackendAwsLogsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final functionName = await _resolveLambdaFunctionName(settings);
    if (functionName == null) {
      throw PublisherBackendException(
        'No Lambda function resource was found for publisher backend stack '
        '"${settings.stackName}". Run `miniprogram publisher-backend aws deploy` first.',
      );
    }
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      'logs',
      'tail',
      '/aws/lambda/$functionName',
      '--since',
      request.since,
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    return PublisherBackendAwsLogsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      lambdaFunctionName: functionName,
      since: request.since,
      stdoutText: '${result.stdout}'.trim(),
      stderrText: '${result.stderr}'.trim(),
    );
  }

  Future<PublisherBackendAwsDestroyResult> _awsDestroyImpl(
    PublisherBackendAwsDestroyRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    String? tableName;
    int? appRecordCount;
    int? redemptionCount;
    if (stack == null) {
      return PublisherBackendAwsDestroyResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        region: settings.region,
        deleted: false,
        dataLossConfirmed: request.confirmDataLoss,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    tableName = outputs['PublisherBackendDataTableName']?.trim();
    if (tableName != null && tableName.isNotEmpty) {
      try {
        appRecordCount = await _queryDynamoDbCount(
          settings: settings,
          tableName: tableName,
          partitionKey: _appPartitionKey(settings.miniProgramId),
        );
        redemptionCount = await _queryDynamoDbCount(
          settings: settings,
          tableName: tableName,
          partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
        );
      } on Object catch (error) {
        if (!request.confirmDataLoss) {
          return PublisherBackendAwsDestroyResult(
            provider: request.environment.provider,
            environmentName: request.environment.name,
            stackName: settings.stackName,
            region: settings.region,
            deleted: false,
            dataLossConfirmed: false,
            tableName: tableName,
            appRecordCount: appRecordCount,
            redemptionCount: redemptionCount,
            blockedByData: true,
            error:
                'Could not inspect DynamoDB table "$tableName" before deletion. '
                'Export data first or pass --confirm-data-loss to continue. '
                'Detail: $error',
          );
        }
      }
      final totalRecords = (appRecordCount ?? 0) + (redemptionCount ?? 0);
      if (totalRecords > 0 && !request.confirmDataLoss) {
        return PublisherBackendAwsDestroyResult(
          provider: request.environment.provider,
          environmentName: request.environment.name,
          stackName: settings.stackName,
          region: settings.region,
          deleted: false,
          dataLossConfirmed: false,
          tableName: tableName,
          appRecordCount: appRecordCount,
          redemptionCount: redemptionCount,
          blockedByData: true,
          error:
              'DynamoDB table "$tableName" has $totalRecords record(s). '
              'Run `miniprogram publisher-backend aws data export` first, '
              'then pass --confirm-data-loss if you still want to delete it.',
        );
      }
    }
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
    await _clearAwsState(rootPath);
    return PublisherBackendAwsDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      deleted: true,
      dataLossConfirmed: request.confirmDataLoss,
      tableName: tableName?.isEmpty == true ? null : tableName,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      deletedAtUtc: _clock().toUtc().toIso8601String(),
    );
  }
}
