part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendOutputHelpers on MiniprogramCli {
  String _formatPublisherBackendScaffoldResult(
    PublisherBackendScaffoldResult result,
  ) {
    final lines = <String>[
      'Scaffolded publisher backend starter.',
      'Template: ${result.template}',
      if (result.storageMode != null) 'Storage: ${result.storageMode}',
      'Mini-program root: ${result.miniProgramRootPath}',
      'Backend root: ${result.backendRootPath}',
      'Created files: ${result.createdPaths.length}',
    ];
    lines.addAll(result.createdPaths.map((filePath) => '- $filePath'));
    if (result.template == 'mock') {
      lines.addAll(<String>[
        '',
        'Run locally:',
        'miniprogram publisher-backend run --mini-program-root "${result.miniProgramRootPath}" --port 9090',
      ]);
    } else if (result.template == 'aws-lambda') {
      lines.addAll(<String>[
        '',
        'Next AWS step:',
        'miniprogram publisher-backend aws deploy --env <env-name> --mini-program-root "${result.miniProgramRootPath}"',
      ]);
    } else if (result.template == 'firebase-functions') {
      lines.addAll(<String>[
        '',
        'Next Firebase steps:',
        'cd "${p.join(result.backendRootPath, 'functions')}"',
        'npm install',
        'npm run serve',
      ]);
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendRunResult(PublisherBackendRunResult result) {
    final state = result.state;
    return <String>[
      result.alreadyRunning
          ? 'Publisher backend was already running.'
          : 'Started publisher backend.',
      'Mini-program root: ${state.miniProgramRootPath}',
      'Backend root: ${state.backendRootPath}',
      'PID: ${state.pid}',
      'Health: ${state.healthCheckUrl}',
      ..._formatPublisherBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ].join('\n');
  }

  String _formatPublisherBackendStatusResult(
    PublisherBackendStatusResult result,
  ) {
    if (!result.hasState) {
      return 'Publisher backend is not running. No publisher_backend.local.json state was found.';
    }
    final state = result.state!;
    return <String>[
      'Publisher backend state found.',
      'Mini-program root: ${state.miniProgramRootPath}',
      'Backend root: ${state.backendRootPath}',
      'PID: ${state.pid}',
      'Process alive: ${result.processAlive}',
      'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      ..._formatPublisherBackendTargetUrls(state.port),
    ].join('\n');
  }

  String _formatPublisherBackendStopResult(PublisherBackendStopResult result) {
    if (!result.hadState) {
      return 'No publisher backend state was found.';
    }
    if (result.clearedStaleState) {
      return 'Cleared stale publisher backend state. The recorded process was already gone.';
    }
    if (result.stopped) {
      return 'Stopped the publisher backend and cleared publisher_backend.local.json.';
    }
    return 'Publisher backend was not running.';
  }

  String _formatPublisherBackendUrlsResult(PublisherBackendUrlsResult result) {
    return <String>[
      'Publisher backend local URLs:',
      ..._formatPublisherBackendTargetUrls(result.port),
      '',
      'Host endpoint example:',
      'miniprogram host endpoint add <appId> --api-base-url <delivery-url> --public --backend-local-mock',
      'miniprogram host endpoint add <appId> --api-base-url <delivery-url> --public --backend-base-url ${result.desktopBaseUrl}',
      '',
      'Use --backend-local-mock for generated host config. With mini_program_sdk 0.3.5+,',
      'the SDK falls back between 127.0.0.1/localhost and Android emulator 10.0.2.2.',
      'Real Android/iOS devices need a LAN IP URL or adb reverse.',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDeployResult(
    PublisherBackendAwsDeployResult result,
  ) {
    final lines = <String>[
      'Deployed AWS Lambda publisher backend.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'SAM bucket: ${result.samS3Bucket}',
      'Backend root: ${result.backendRootPath}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      'Deployed at UTC: ${result.deployedAtUtc}',
    ];
    if (result.outputs.isNotEmpty) {
      lines
        ..add('Outputs:')
        ..addAll(
          result.outputs.entries.map((entry) => '${entry.key}: ${entry.value}'),
        );
    }
    if (result.backendBaseUrl != null) {
      lines.addAll(<String>[
        '',
        'Host endpoint command:',
        'miniprogram host endpoint add <appId> --api-base-url <delivery-url> --public --backend-base-url ${result.backendBaseUrl}',
        '',
        'Next commands:',
        if (result.outputs['PublisherBackendStorageMode'] == 'dynamodb')
          'miniprogram publisher-backend aws seed --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
        if (result.outputs['PublisherBackendStorageMode'] == 'dynamodb')
          'miniprogram publisher-backend aws data status --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
        'miniprogram publisher-backend aws smoke --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
        'miniprogram publisher-backend aws logs --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)} --since 1h',
      ]);
    }
    return lines.join('\n');
  }

  String _publisherBackendRootOption(String? miniProgramRootPath) {
    if (miniProgramRootPath == null || miniProgramRootPath.trim().isEmpty) {
      return '';
    }
    return ' --mini-program-root ${_quoteCommandArgument(miniProgramRootPath)}';
  }

  String _quoteCommandArgument(String value) {
    if (!value.contains(RegExp(r'\s'))) {
      return value;
    }
    return "'${value.replaceAll("'", "''")}'";
  }

  String _formatPublisherBackendAwsStatusResult(
    PublisherBackendAwsStatusResult result,
  ) {
    final lines = <String>[
      'AWS Lambda publisher backend status.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.stackStatusReason != null)
        'Stack reason: ${result.stackStatusReason}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
    ];
    if (result.state != null) {
      lines.add('Last deploy state: ${result.state!.deployedAtUtc}');
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendAwsOutputsResult(
    PublisherBackendAwsOutputsResult result,
  ) {
    final lines = <String>[
      'AWS Lambda publisher backend outputs.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
    ];
    lines.addAll(
      result.outputs.entries.map((entry) => '${entry.key}: ${entry.value}'),
    );
    return lines.join('\n');
  }

  String _formatPublisherBackendAwsSmokeResult(
    PublisherBackendAwsSmokeResult result,
  ) {
    final lines = <String>[
      'AWS Lambda publisher backend smoke test.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      'Write smoke: ${result.includeWrite}',
      'Passed: ${result.passed}',
      if (result.error != null) 'Detail: ${result.error}',
    ];
    if (result.routes.isNotEmpty) {
      lines.add('');
      for (final route in result.routes) {
        final status = route.statusCode == null
            ? 'failed'
            : route.passed
            ? '${route.statusCode} OK'
            : '${route.statusCode} FAIL';
        final responseStatus = route.responseStatus == null
            ? ''
            : ' (${route.responseStatus})';
        lines.add('${route.method} ${route.path}: $status$responseStatus');
        if (route.error != null) {
          lines.add('  ${route.error}');
        }
      }
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendAwsSeedResult(
    PublisherBackendAwsSeedResult result,
  ) {
    return <String>[
      'AWS DynamoDB publisher backend seed.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Mini-program ID: ${result.miniProgramId}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.storageMode != null) 'Storage mode: ${result.storageMode}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      'Seeded: ${result.seeded}',
      'Items written: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDataStatusResult(
    PublisherBackendAwsDataStatusResult result,
  ) {
    return <String>[
      'AWS DynamoDB publisher backend data status.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Mini-program ID: ${result.miniProgramId}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.storageMode != null) 'Storage mode: ${result.storageMode}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      if (result.tableStatus != null) 'Table status: ${result.tableStatus}',
      if (result.appRecordCount != null)
        'App records: ${result.appRecordCount}',
      if (result.redemptionCount != null)
        'Redemptions: ${result.redemptionCount}',
      'Available: ${result.available}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDataExportResult(
    PublisherBackendAwsDataExportResult result,
  ) {
    return <String>[
      'AWS DynamoDB publisher backend data export.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Mini-program ID: ${result.miniProgramId}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.storageMode != null) 'Storage mode: ${result.storageMode}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      'Include redemptions: ${result.includeRedemptions}',
      'Exported: ${result.exported}',
      if (result.outputPath != null) 'Output file: ${result.outputPath}',
      if (result.exportedAtUtc != null)
        'Exported at UTC: ${result.exportedAtUtc}',
      'App records: ${result.appRecordCount}',
      'Redemptions: ${result.redemptionCount}',
      'Items exported: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDataImportResult(
    PublisherBackendAwsDataImportResult result,
  ) {
    return <String>[
      'AWS DynamoDB publisher backend data import.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Mini-program ID: ${result.miniProgramId}',
      'Input file: ${result.inputPath}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.storageMode != null) 'Storage mode: ${result.storageMode}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      'Include redemptions: ${result.includeRedemptions}',
      'Dry run: ${result.dryRun}',
      'Succeeded: ${result.succeeded}',
      'Imported: ${result.imported}',
      'App records: ${result.appRecordCount}',
      'Redemptions: ${result.redemptionCount}',
      'Redemptions skipped: ${result.skippedRedemptionCount}',
      'Items ready: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDataRedemptionsResult(
    PublisherBackendAwsDataRedemptionsResult result,
  ) {
    final lines = <String>[
      'AWS DynamoDB publisher backend redemptions.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Mini-program ID: ${result.miniProgramId}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.storageMode != null) 'Storage mode: ${result.storageMode}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      if (result.couponId != null) 'Coupon filter: ${result.couponId}',
      if (result.userId != null) 'User filter: ${result.userId}',
      'Limit: ${result.limit}',
      'Matched: ${result.matchedCount}',
      'Returned: ${result.returnedCount}',
      'Available: ${result.available}',
      if (result.error != null) 'Detail: ${result.error}',
    ];
    if (result.records.isNotEmpty) {
      lines.add('');
      for (final record in result.records) {
        final couponId = _redemptionValue(record, 'couponId') ?? 'unknown';
        final userId = _redemptionValue(record, 'userId') ?? 'unknown';
        final status = _redemptionValue(record, 'status') ?? 'redemption';
        final createdAt =
            _redemptionValue(record, 'createdAtUtc') ??
            _redemptionValue(record, 'redeemedAtUtc') ??
            'unknown time';
        lines.add('- $createdAt $status coupon=$couponId user=$userId');
      }
    }
    return lines.join('\n');
  }

  String? _redemptionValue(Map<String, Object?> record, String key) {
    final direct = record[key]?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final data = record['data'];
    if (data is Map) {
      final nested = data[key]?.toString();
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    final payload = record['payload'];
    if (payload is Map) {
      final nested = payload[key]?.toString();
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  String _formatPublisherBackendAwsLogsResult(
    PublisherBackendAwsLogsResult result,
  ) {
    return <String>[
      'AWS Lambda publisher backend logs.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      'Function: ${result.lambdaFunctionName}',
      'Since: ${result.since}',
      if (result.stdoutText.isNotEmpty) result.stdoutText,
      if (result.stderrText.isNotEmpty) 'stderr:\n${result.stderrText}',
    ].join('\n');
  }

  String _formatPublisherBackendAwsDestroyResult(
    PublisherBackendAwsDestroyResult result,
  ) {
    return <String>[
      result.deleted
          ? 'Deleted AWS Lambda publisher backend stack.'
          : 'AWS Lambda publisher backend stack was not deleted.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      if (result.tableName != null) 'DynamoDB table: ${result.tableName}',
      if (result.appRecordCount != null)
        'App records: ${result.appRecordCount}',
      if (result.redemptionCount != null)
        'Redemptions: ${result.redemptionCount}',
      'Data loss confirmed: ${result.dataLossConfirmed}',
      'Blocked by data: ${result.blockedByData}',
      'Deleted: ${result.deleted}',
      if (result.deletedAtUtc != null) 'Deleted at UTC: ${result.deletedAtUtc}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseDeployResult(
    PublisherBackendFirebaseDeployResult result,
  ) {
    final lines = <String>[
      'Deployed Firebase Functions publisher backend.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Backend root: ${result.backendRootPath}',
      'Functions root: ${result.functionsRootPath}',
      'Installed dependencies: ${result.dependenciesInstalled}',
      'Public invoker configured: ${result.publicInvokerConfigured}',
      'Public invoker changed: ${result.publicInvokerChanged}',
      if (result.publicInvokerError != null)
        'Public invoker detail: ${result.publicInvokerError}',
      'Auth token creator configured: ${result.authTokenCreatorConfigured}',
      'Auth token creator changed: ${result.authTokenCreatorChanged}',
      if (result.authTokenCreatorServiceAccount != null)
        'Auth token creator service account: ${result.authTokenCreatorServiceAccount}',
      if (result.authTokenCreatorError != null)
        'Auth token creator detail: ${result.authTokenCreatorError}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      'Deployed at UTC: ${result.deployedAtUtc}',
      '',
      'Generate host endpoint command:',
      'miniprogram publisher-backend firebase host-command --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)} --api-base-url <delivery-url> --public',
      'miniprogram publisher-backend firebase handoff --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)} --delivery-url <delivery-url> --public',
      '',
      'Next commands:',
      'miniprogram publisher-backend firebase seed --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
      'miniprogram publisher-backend firebase data status --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
      'miniprogram publisher-backend firebase status --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
      'miniprogram publisher-backend firebase smoke --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)}',
      'miniprogram publisher-backend firebase smoke --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)} --include-write',
      'miniprogram publisher-backend firebase smoke --env ${result.environmentName}${_publisherBackendRootOption(result.miniProgramRootPath)} --include-auth --auth-email <email> --auth-password <password>',
    ];
    if (result.outputs.isNotEmpty) {
      lines
        ..add('')
        ..add('Outputs:')
        ..addAll(
          result.outputs.entries.map((entry) => '${entry.key}: ${entry.value}'),
        );
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseSeedResult(
    PublisherBackendFirebaseSeedResult result,
  ) {
    return <String>[
      'Firebase Firestore publisher backend seed.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Storage mode: ${result.storageMode}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      'Seeded: ${result.seeded}',
      'App records: ${result.appRecordCount}',
      'Home records: ${result.seeded ? 1 : 0}',
      'Auth sessions: ${result.authSessionCount}',
      'Coupons: ${result.couponCount}',
      'Items written: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseDataStatusResult(
    PublisherBackendFirebaseDataStatusResult result,
  ) {
    return <String>[
      'Firebase Firestore publisher backend data status.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Storage mode: ${result.storageMode}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      if (result.homeRecordCount != null)
        'Home records: ${result.homeRecordCount}',
      if (result.authSessionCount != null)
        'Auth sessions: ${result.authSessionCount}',
      if (result.couponCount != null) 'Coupons: ${result.couponCount}',
      if (result.redemptionCount != null)
        'Redemptions: ${result.redemptionCount}',
      if (result.appRecordCount != null)
        'App records: ${result.appRecordCount}',
      'Available: ${result.available}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseDataExportResult(
    PublisherBackendFirebaseDataExportResult result,
  ) {
    return <String>[
      'Firebase Firestore publisher backend data export.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Storage mode: ${result.storageMode}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      'Include redemptions: ${result.includeRedemptions}',
      'Exported: ${result.exported}',
      if (result.outputPath != null) 'Output file: ${result.outputPath}',
      if (result.exportedAtUtc != null)
        'Exported at UTC: ${result.exportedAtUtc}',
      'App records: ${result.appRecordCount}',
      'Redemptions: ${result.redemptionCount}',
      'Items exported: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseDataImportResult(
    PublisherBackendFirebaseDataImportResult result,
  ) {
    return <String>[
      'Firebase Firestore publisher backend data import.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Storage mode: ${result.storageMode}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      'Input file: ${result.inputPath}',
      'Include redemptions: ${result.includeRedemptions}',
      'Dry run: ${result.dryRun}',
      'Succeeded: ${result.succeeded}',
      'Imported: ${result.imported}',
      'App records: ${result.appRecordCount}',
      'Redemptions: ${result.redemptionCount}',
      'Redemptions skipped: ${result.skippedRedemptionCount}',
      'Items ready: ${result.itemCount}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseDataRedemptionsResult(
    PublisherBackendFirebaseDataRedemptionsResult result,
  ) {
    final lines = <String>[
      'Firebase Firestore publisher backend redemptions.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Storage mode: ${result.storageMode}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      if (result.couponId != null) 'Coupon filter: ${result.couponId}',
      if (result.userId != null) 'User filter: ${result.userId}',
      'Limit: ${result.limit}',
      'Matched: ${result.matchedCount}',
      'Returned: ${result.returnedCount}',
      'Available: ${result.available}',
      if (result.error != null) 'Detail: ${result.error}',
    ];
    if (result.records.isNotEmpty) {
      lines.add('');
      for (final record in result.records) {
        final couponId = _redemptionValue(record, 'couponId') ?? 'unknown';
        final userId = _redemptionValue(record, 'userId') ?? 'unknown';
        final status = _redemptionValue(record, 'status') ?? 'redemption';
        final createdAt =
            _redemptionValue(record, 'createdAt') ??
            _redemptionValue(record, 'createdAtUtc') ??
            _redemptionValue(record, 'redeemedAtUtc') ??
            'unknown time';
        lines.add('- $createdAt $status coupon=$couponId user=$userId');
      }
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseDestroyResult(
    PublisherBackendFirebaseDestroyResult result,
  ) {
    return <String>[
      result.deleted
          ? 'Deleted Firebase Functions publisher backend function.'
          : 'Firebase Functions publisher backend function was not deleted.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      if (result.backendBaseUrl != null)
        'Publisher backend base URL: ${result.backendBaseUrl}',
      if (result.appRecordCount != null)
        'App records: ${result.appRecordCount}',
      if (result.redemptionCount != null)
        'Redemptions: ${result.redemptionCount}',
      'Data loss confirmed: ${result.dataLossConfirmed}',
      'Blocked by data: ${result.blockedByData}',
      'Deleted: ${result.deleted}',
      if (result.deletedAtUtc != null) 'Deleted at UTC: ${result.deletedAtUtc}',
      if (result.error != null) 'Detail: ${result.error}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseStatusResult(
    PublisherBackendFirebaseStatusResult result,
  ) {
    return <String>[
      'Firebase Functions publisher backend status.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Backend root: ${result.backendRootPath}',
      'Scaffold exists: ${result.scaffoldExists}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      if (result.state != null)
        'Last deploy state: ${result.state!.deployedAtUtc}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseOutputsResult(
    PublisherBackendFirebaseOutputsResult result,
  ) {
    final lines = <String>[
      'Firebase Functions publisher backend outputs.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
    ];
    lines.addAll(
      result.outputs.entries.map((entry) => '${entry.key}: ${entry.value}'),
    );
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseAuthStatusResult(
    _PublisherBackendFirebaseAuthStatusCliResult result,
  ) {
    final authStatus = result.authStatus;
    final lines = <String>[
      'Firebase publisher backend auth status.',
      'Provider: ${authStatus.provider}',
      'Environment: ${authStatus.environmentName}',
      'Project: ${authStatus.projectId}',
      'Region: ${authStatus.region}',
      'Function: ${authStatus.functionName}',
      'Mini-program ID: ${authStatus.miniProgramId}',
      'Backend root: ${authStatus.backendRootPath}',
      'Functions root: ${authStatus.functionsRootPath}',
      'Auth Web API key configured: ${authStatus.authWebApiKeyConfigured}',
      'Scaffold exists: ${authStatus.scaffoldExists}',
      'Auth service file exists: ${authStatus.authServiceFileExists}',
      'Router auth routes ready: ${authStatus.routerAuthRoutesReady}',
      'Router allows Authorization header: ${authStatus.routerAllowsAuthorizationHeader}',
      'Functions package has firebase-admin: ${authStatus.packageJsonHasFirebaseAdmin}',
      'Functions package has firebase-functions: ${authStatus.packageJsonHasFirebaseFunctions}',
      'Functions .env path: ${authStatus.envFilePath}',
      'Functions .env auth key configured: ${authStatus.envAuthKeyConfigured}',
      'Functions .env uses reserved auth key: ${authStatus.envUsesReservedAuthKey}',
      'Deploy env ready: ${authStatus.deployEnvReady}',
      'Ready: ${authStatus.ready}',
    ];
    final hostAuthReadiness = result.hostAuthReadiness;
    if (result.hostProjectRootPath != null) {
      lines.addAll(<String>[
        'Host project root: ${result.hostProjectRootPath}',
        'Host auth checked: true',
        'Host auth controller ready: ${hostAuthReadiness?.ready ?? false}',
        if (hostAuthReadiness?.runtimeSetupPath != null)
          'Host runtime setup: ${hostAuthReadiness!.runtimeSetupPath}',
      ]);
    } else {
      lines.add('Host auth checked: false');
    }
    if (authStatus.issues.isNotEmpty) {
      lines
        ..add('Issues:')
        ..addAll(authStatus.issues.map((issue) => '- $issue'));
    }
    if (hostAuthReadiness != null && hostAuthReadiness.issues.isNotEmpty) {
      lines
        ..add('Host auth issues:')
        ..addAll(hostAuthReadiness.issues.map((issue) => '- $issue'));
    }
    if (authStatus.warnings.isNotEmpty) {
      lines
        ..add('Warnings:')
        ..addAll(authStatus.warnings.map((warning) => '- $warning'));
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseHostCommandResult(
    _PublisherBackendFirebaseHostCommandResult result,
  ) {
    final lines = <String>[
      'Firebase host endpoint command.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program root: ${result.miniProgramRootPath}',
      'Mini-program ID: ${result.miniProgramId}',
      'Title: ${result.title}',
      'Delivery API base URL: ${result.deliveryApiBaseUrl}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Access mode: ${result.accessMode}',
    ];
    if (result.hostProjectRootPath != null) {
      final readiness = result.readiness;
      final hostAuthReadiness = result.hostAuthReadiness;
      lines.addAll(<String>[
        'Host project root: ${result.hostProjectRootPath}',
        'Host endpoint checked: true',
        'Host endpoint ready: ${readiness?.ready ?? false}',
        if (readiness?.endpointMapPath != null)
          'Host endpoint map: ${readiness!.endpointMapPath}',
        if (readiness?.apiBaseUrl != null)
          'Host endpoint delivery API base URL: ${readiness!.apiBaseUrl}',
        if (readiness?.backendBaseUrl != null)
          'Host endpoint backend base URL: ${readiness!.backendBaseUrl}',
        if (readiness?.accessMode != null)
          'Host endpoint access mode: ${readiness!.accessMode}',
        'Host auth checked: true',
        'Host auth controller ready: ${hostAuthReadiness?.ready ?? false}',
        if (hostAuthReadiness?.runtimeSetupPath != null)
          'Host runtime setup: ${hostAuthReadiness!.runtimeSetupPath}',
      ]);
      if (readiness != null && readiness.issues.isNotEmpty) {
        lines
          ..add('Host endpoint issues:')
          ..addAll(readiness.issues.map((issue) => '- $issue'));
      }
      if (hostAuthReadiness != null && hostAuthReadiness.issues.isNotEmpty) {
        lines
          ..add('Host auth issues:')
          ..addAll(hostAuthReadiness.issues.map((issue) => '- $issue'));
      }
    } else {
      lines.add('Host endpoint checked: false');
      lines.add('Host auth checked: false');
    }
    lines.addAll(<String>[
      '',
      'Host endpoint command:',
      result.hostEndpointCommandText,
    ]);
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseHandoffResult(
    _PublisherBackendFirebaseHandoffResult result,
  ) {
    final handoff = result.packageResult.handoff;
    return <String>[
      'Firebase publisher backend handoff package created.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program root: ${result.miniProgramRootPath}',
      'Mini-program ID: ${handoff.appId}',
      'Title: ${handoff.title}',
      'Delivery API base URL: ${handoff.apiBaseUri}',
      if (handoff.backendBaseUri != null)
        'Publisher backend base URL: ${handoff.backendBaseUri}',
      'Access mode: ${handoff.accessMode}',
      'Access key included: ${handoff.accessKey != null}',
      'Package file: ${result.packageResult.filePath}',
      'Generated at UTC: ${handoff.generatedAtUtc}',
      '',
      'Host import command:',
      result.hostImportCommandText,
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseAccessKeyCreateResult(
    PublisherBackendFirebaseAccessKeyCreateResult result,
  ) {
    return <String>[
      'Created Firebase publisher backend access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Key ID: ${result.keyId}',
      'Access key (shown once): ${result.accessKey}',
      'Created at UTC: ${result.createdAtUtc}',
      if (result.expiresAtUtc != null) 'Expires at UTC: ${result.expiresAtUtc}',
      '',
      'Protected handoff command:',
      'miniprogram publisher-backend firebase handoff --env ${result.environmentName} --delivery-url <delivery-url> --access-key ${result.accessKey}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseAccessKeyListResult(
    PublisherBackendFirebaseAccessKeyListResult result,
  ) {
    final lines = <String>[
      'Firebase publisher backend access keys.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Active keys: ${result.activeKeyCount}',
      'Total keys: ${result.keyCount}',
    ];
    if (result.keys.isNotEmpty) {
      lines.add('');
      for (final key in result.keys) {
        final state = key.currentlyActive ? 'active' : 'inactive';
        lines.add(
          '- ${key.keyId}: $state'
          '${key.lastFour == null ? '' : ' (last4 ${key.lastFour})'}'
          '${key.expiresAtUtc == null ? '' : ' expires ${key.expiresAtUtc}'}',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatPublisherBackendFirebaseAccessKeyRevokeResult(
    PublisherBackendFirebaseAccessKeyRevokeResult result,
  ) {
    return <String>[
      'Revoked Firebase publisher backend access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Key ID: ${result.keyId}',
      'Revoked at UTC: ${result.revokedAtUtc}',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseAccessKeyRotateResult(
    PublisherBackendFirebaseAccessKeyRotateResult result,
  ) {
    return <String>[
      'Rotated Firebase publisher backend access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Mini-program ID: ${result.miniProgramId}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Revoked key ID: ${result.revokedKeyId}',
      'New key ID: ${result.newKeyId}',
      'Access key (shown once): ${result.accessKey}',
      'Rotated at UTC: ${result.rotatedAtUtc}',
      if (result.expiresAtUtc != null) 'Expires at UTC: ${result.expiresAtUtc}',
      '',
      'Update protected handoff packages with the new access key.',
    ].join('\n');
  }

  String _formatPublisherBackendFirebaseSmokeResult(
    PublisherBackendFirebaseSmokeResult result,
  ) {
    final lines = <String>[
      'Firebase Functions publisher backend smoke test.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Project: ${result.projectId}',
      'Region: ${result.region}',
      'Function: ${result.functionName}',
      'Publisher backend base URL: ${result.backendBaseUrl}',
      'Write smoke: ${result.includeWrite}',
      if (result.includeWrite) 'Write coupon ID: ${result.writeCouponId}',
      if (result.includeWrite) 'Write user ID: ${result.writeUserId}',
      'Auth smoke: ${result.includeAuth}',
      'Access key provided: ${result.accessKeyProvided}',
      if (result.includeAuth && result.authEmail != null)
        'Auth email: ${result.authEmail}',
      if (result.includeAuth) 'Auth create user: ${result.authCreateUser}',
      'Passed: ${result.passed}',
      if (result.error != null) 'Detail: ${result.error}',
    ];
    if (result.routes.isNotEmpty) {
      lines.add('');
      for (final route in result.routes) {
        final status = route.statusCode == null
            ? 'failed'
            : route.passed
            ? '${route.statusCode} OK'
            : '${route.statusCode} FAIL';
        final responseStatus = route.responseStatus == null
            ? ''
            : ' (${route.responseStatus})';
        final verificationStatus = route.redemptionVerified == null
            ? ''
            : route.redemptionVerified == true
            ? ' [Firestore verified]'
            : ' [Firestore verification failed]';
        lines.add(
          '${route.method} ${route.path}: $status$responseStatus$verificationStatus',
        );
        if (route.redemptionDocumentPath != null) {
          lines.add('  Redemption: ${route.redemptionDocumentPath}');
        }
        if (route.verificationError != null) {
          lines.add('  Verification detail: ${route.verificationError}');
        }
        if (route.error != null) {
          lines.add('  ${route.error}');
        }
      }
    }
    return lines.join('\n');
  }

  List<String> _formatPublisherBackendTargetUrls(int port) {
    final urls = PublisherBackendUrlsResult(port: port);
    return <String>[
      'Desktop/web host: ${urls.desktopBaseUrl}',
      'Android emulator host: ${urls.androidEmulatorBaseUrl}',
      'Android USB via adb reverse: ${urls.androidUsbBaseUrl}',
    ];
  }
}
