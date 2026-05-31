part of '../miniprogram_cli.dart';

extension _MiniprogramCliJsonOutputHelpers on MiniprogramCli {
  String _prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Map<String, Object?> _doctorResultJson(MiniprogramDoctorResult result) {
    var okCount = 0;
    var warningCount = 0;
    var errorCount = 0;
    var skippedCount = 0;
    for (final check in result.checks) {
      switch (check.status) {
        case MiniprogramDoctorCheckStatus.ok:
          okCount++;
        case MiniprogramDoctorCheckStatus.warning:
          warningCount++;
        case MiniprogramDoctorCheckStatus.error:
          errorCount++;
        case MiniprogramDoctorCheckStatus.skipped:
          skippedCount++;
      }
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'doctor',
      'hasErrors': result.hasErrors,
      'summary': <String, int>{
        'ok': okCount,
        'warning': warningCount,
        'error': errorCount,
        'skipped': skippedCount,
      },
      'checks': result.checks
          .map(
            (check) => <String, Object?>{
              'label': check.label,
              'status': check.status.name,
              'summary': check.summary,
              'detail': check.detail,
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _capabilitiesJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'capabilities',
      'packageName': 'mini_program_tooling',
      'toolingVersion': _miniProgramToolingVersion,
      'capabilityIds': _capabilityIds,
      'features': <String, bool>{
        'firebaseHostingPublish': true,
        'publisherBackendAwsStatus': true,
        'publisherBackendAwsOutputs': true,
        'publisherBackendAwsSmoke': true,
        'publisherBackendAwsWriteSmoke': true,
        'publisherBackendAwsDynamoDbSeed': true,
        'publisherBackendAwsDynamoDbDataStatus': true,
        'publisherBackendAwsDynamoDbDataExport': true,
        'publisherBackendAwsDynamoDbDataImport': true,
        'publisherBackendAwsDynamoDbDataRedemptions': true,
        'publisherBackendAwsDestroyDataLossGuard': true,
        'publisherBackendFirebaseFunctionsScaffold': true,
        'publisherBackendFirebaseDeploy': true,
        'publisherBackendFirebaseStatus': true,
        'publisherBackendFirebaseOutputs': true,
        'publisherBackendFirebaseHostCommand': true,
        'publisherBackendFirebaseHandoff': true,
        'publisherBackendFirebaseAccessKeys': true,
        'publisherBackendFirebaseAuthEmail': true,
        'publisherBackendFirebaseAuthStatus': true,
        'publisherBackendFirebaseHostAuthDiagnostics': true,
        'publisherBackendFirebaseSmoke': true,
        'publisherBackendFirebaseWriteSmoke': true,
        'publisherBackendFirebaseSmokeAuth': true,
        'publisherBackendFirebaseFirestoreSeed': true,
        'publisherBackendFirebaseFirestoreDataStatus': true,
        'publisherBackendFirebaseFirestoreDataExport': true,
        'publisherBackendFirebaseFirestoreDataImport': true,
        'publisherBackendFirebaseFirestoreDataRedemptions': true,
        'publisherBackendFirebaseDestroyDataLossGuard': true,
      },
      'commands': <String>[
        'publish --target firebase-hosting',
        'publisher-backend scaffold --template firebase-functions --storage firestore',
        'publisher-backend firebase deploy',
        'publisher-backend firebase status',
        'publisher-backend firebase outputs',
        'publisher-backend firebase host-command',
        'publisher-backend firebase handoff',
        'publisher-backend firebase access-key create',
        'publisher-backend firebase access-key list',
        'publisher-backend firebase access-key revoke',
        'publisher-backend firebase access-key rotate',
        'publisher-backend firebase auth status',
        'publisher-backend firebase smoke',
        'publisher-backend firebase smoke --include-write',
        'publisher-backend firebase smoke --include-auth',
        'publisher-backend firebase seed',
        'publisher-backend firebase data status',
        'publisher-backend firebase data export',
        'publisher-backend firebase data import',
        'publisher-backend firebase data redemptions',
        'publisher-backend firebase destroy --confirm-data-loss',
        'publisher-backend aws status',
        'publisher-backend aws outputs',
        'publisher-backend aws smoke',
        'publisher-backend aws smoke --include-write',
        'publisher-backend aws seed',
        'publisher-backend aws data status',
        'publisher-backend aws data export',
        'publisher-backend aws data import',
        'publisher-backend aws data redemptions',
        'publisher-backend aws destroy --confirm-data-loss',
      ],
    };
  }

  Map<String, Object?> _envStatusJson(
    ResolvedLocalCliEnvironmentState? resolved,
  ) {
    if (resolved == null) {
      return <String, Object?>{
        'schemaVersion': 1,
        'command': 'env status',
        'configured': false,
      };
    }
    final activeCloudEnvironment = resolved.state.cloudEnvironmentNamed(
      resolved.state.activeEnvironment,
    );
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'env status',
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'repoRootPath': resolved.state.repoRootPath,
      'activeEnvironment': resolved.state.activeEnvironment,
      'cloudEnvironmentCount': resolved.state.cloudEnvironments.length,
      'activeCloudEnvironment': activeCloudEnvironment == null
          ? null
          : _cloudEnvironmentJson(activeCloudEnvironment),
      'initializedAtUtc': resolved.state.initializedAtUtc,
      'updatedAtUtc': resolved.state.updatedAtUtc,
    };
  }

  Map<String, Object?> _cloudEnvironmentJson(
    CloudEnvironmentConfiguration environment,
  ) {
    return <String, Object?>{
      'name': environment.name,
      'provider': environment.provider,
      'values': _redactedCloudEnvironmentValues(environment.values),
      if ((environment.values['authWebApiKey']?.toString().trim() ?? '')
          .isNotEmpty)
        'authWebApiKeyConfigured': true,
      'configuredAtUtc': environment.configuredAtUtc,
      'updatedAtUtc': environment.updatedAtUtc,
    };
  }

  Map<String, Object?> _redactedCloudEnvironmentValues(
    Map<String, dynamic> values,
  ) {
    return values.map(
      (key, value) =>
          MapEntry(key, key == 'authWebApiKey' ? '<configured>' : value),
    );
  }

  Map<String, Object?> _publisherBackendStatusJson(
    PublisherBackendStatusResult result,
  ) {
    final state = result.state;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend status',
      'hasState': result.hasState,
      'processAlive': result.processAlive,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
      if (state != null) ...<String, Object?>{
        'miniProgramRootPath': state.miniProgramRootPath,
        'backendRootPath': state.backendRootPath,
        'pid': state.pid,
        'port': state.port,
        'healthCheckUrl': state.healthCheckUrl,
        'urls': <String, Object?>{
          'desktopWeb': PublisherBackendUrlsResult(
            port: state.port,
          ).desktopBaseUrl,
          'androidEmulator': PublisherBackendUrlsResult(
            port: state.port,
          ).androidEmulatorBaseUrl,
          'androidUsb': PublisherBackendUrlsResult(
            port: state.port,
          ).androidUsbBaseUrl,
        },
      },
    };
  }

  Map<String, Object?> _publisherBackendAwsStatusJson(
    PublisherBackendAwsStatusResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws status',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'stackStatusReason': result.stackStatusReason,
      'backendBaseUrl': result.backendBaseUrl,
      'healthUrl': result.healthUrl,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
      'outputs': result.outputs,
      'lastDeploy': result.state == null
          ? null
          : <String, Object?>{
              'deployedAtUtc': result.state!.deployedAtUtc,
              'backendRootPath': result.state!.backendRootPath,
              'stackName': result.state!.stackName,
              'backendBaseUrl': result.state!.backendBaseUrl,
            },
    };
  }

  Map<String, Object?> _publisherBackendAwsOutputsJson(
    PublisherBackendAwsOutputsResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws outputs',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'region': result.region,
      'outputs': result.outputs,
      'backendBaseUrl': result.outputs['PublisherBackendBaseUrl'],
      'healthUrl': result.outputs['PublisherBackendHealthUrl'],
      'functionName': result.outputs['PublisherBackendFunctionName'],
    };
  }

  Map<String, Object?> _publisherBackendAwsSmokeJson(
    PublisherBackendAwsSmokeResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws smoke',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'backendBaseUrl': result.backendBaseUrl,
      'includeWrite': result.includeWrite,
      'passed': result.passed,
      'error': result.error,
      'routes': result.routes
          .map(
            (route) => <String, Object?>{
              'method': route.method,
              'path': route.path,
              'uri': route.uri.toString(),
              'statusCode': route.statusCode,
              'responseStatus': route.responseStatus,
              'passed': route.passed,
              'error': route.error,
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _publisherBackendAwsSeedJson(
    PublisherBackendAwsSeedResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws seed',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'miniProgramId': result.miniProgramId,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'storageMode': result.storageMode,
      'tableName': result.tableName,
      'seeded': result.seeded,
      'itemCount': result.itemCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendAwsDataStatusJson(
    PublisherBackendAwsDataStatusResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws data status',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'miniProgramId': result.miniProgramId,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'storageMode': result.storageMode,
      'tableName': result.tableName,
      'tableStatus': result.tableStatus,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'available': result.available,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendAwsDataExportJson(
    PublisherBackendAwsDataExportResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws data export',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'miniProgramId': result.miniProgramId,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'storageMode': result.storageMode,
      'tableName': result.tableName,
      'includeRedemptions': result.includeRedemptions,
      'exported': result.exported,
      'outputPath': result.outputPath,
      'exportedAtUtc': result.exportedAtUtc,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'itemCount': result.itemCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendAwsDataImportJson(
    PublisherBackendAwsDataImportResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws data import',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'miniProgramId': result.miniProgramId,
      'inputPath': result.inputPath,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'storageMode': result.storageMode,
      'tableName': result.tableName,
      'includeRedemptions': result.includeRedemptions,
      'dryRun': result.dryRun,
      'succeeded': result.succeeded,
      'imported': result.imported,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'skippedRedemptionCount': result.skippedRedemptionCount,
      'itemCount': result.itemCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendAwsDataRedemptionsJson(
    PublisherBackendAwsDataRedemptionsResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend aws data redemptions',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'stackName': result.stackName,
      'stageName': result.stageName,
      'region': result.region,
      'miniProgramId': result.miniProgramId,
      'stackExists': result.stackExists,
      'stackStatus': result.stackStatus,
      'storageMode': result.storageMode,
      'tableName': result.tableName,
      'couponId': result.couponId,
      'userId': result.userId,
      'limit': result.limit,
      'matchedCount': result.matchedCount,
      'returnedCount': result.returnedCount,
      'available': result.available,
      'records': result.records,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseDeployJson(
    PublisherBackendFirebaseDeployResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase deploy',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'backendRootPath': result.backendRootPath,
      'functionsRootPath': result.functionsRootPath,
      'backendBaseUrl': result.backendBaseUrl,
      'healthUrl': result.healthUrl,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
      'dependenciesInstalled': result.dependenciesInstalled,
      'publicInvokerConfigured': result.publicInvokerConfigured,
      'publicInvokerChanged': result.publicInvokerChanged,
      'publicInvokerError': result.publicInvokerError,
      'authTokenCreatorConfigured': result.authTokenCreatorConfigured,
      'authTokenCreatorChanged': result.authTokenCreatorChanged,
      'authTokenCreatorServiceAccount': result.authTokenCreatorServiceAccount,
      'authTokenCreatorError': result.authTokenCreatorError,
      'outputs': result.outputs,
      'deployedAtUtc': result.deployedAtUtc,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseSeedJson(
    PublisherBackendFirebaseSeedResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase seed',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'storageMode': result.storageMode,
      'seeded': result.seeded,
      'itemCount': result.itemCount,
      'appRecordCount': result.appRecordCount,
      'couponCount': result.couponCount,
      'authSessionCount': result.authSessionCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseDataStatusJson(
    PublisherBackendFirebaseDataStatusResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase data status',
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

  Map<String, Object?> _publisherBackendFirebaseDataExportJson(
    PublisherBackendFirebaseDataExportResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase data export',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'storageMode': result.storageMode,
      'includeRedemptions': result.includeRedemptions,
      'exported': result.exported,
      'outputPath': result.outputPath,
      'exportedAtUtc': result.exportedAtUtc,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'itemCount': result.itemCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseDataImportJson(
    PublisherBackendFirebaseDataImportResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase data import',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'storageMode': result.storageMode,
      'inputPath': result.inputPath,
      'includeRedemptions': result.includeRedemptions,
      'dryRun': result.dryRun,
      'succeeded': result.succeeded,
      'imported': result.imported,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'skippedRedemptionCount': result.skippedRedemptionCount,
      'itemCount': result.itemCount,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseDataRedemptionsJson(
    PublisherBackendFirebaseDataRedemptionsResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase data redemptions',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'storageMode': result.storageMode,
      'couponId': result.couponId,
      'userId': result.userId,
      'limit': result.limit,
      'matchedCount': result.matchedCount,
      'returnedCount': result.returnedCount,
      'available': result.available,
      'records': result.records,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseDestroyJson(
    PublisherBackendFirebaseDestroyResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase destroy',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'deleted': result.deleted,
      'dataLossConfirmed': result.dataLossConfirmed,
      'deletedAtUtc': result.deletedAtUtc,
      'appRecordCount': result.appRecordCount,
      'redemptionCount': result.redemptionCount,
      'blockedByData': result.blockedByData,
      'error': result.error,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseStatusJson(
    PublisherBackendFirebaseStatusResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase status',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'backendRootPath': result.backendRootPath,
      'functionsRootPath': result.functionsRootPath,
      'backendBaseUrl': result.backendBaseUrl,
      'healthUrl': result.healthUrl,
      'scaffoldExists': result.scaffoldExists,
      'healthy': result.healthy,
      'healthStatusCode': result.healthStatusCode,
      'healthError': result.healthError,
      'outputs': result.outputs,
      'lastDeploy': result.state == null
          ? null
          : <String, Object?>{
              'deployedAtUtc': result.state!.deployedAtUtc,
              'backendRootPath': result.state!.backendRootPath,
              'projectId': result.state!.projectId,
              'region': result.state!.region,
              'functionName': result.state!.functionName,
              'backendBaseUrl': result.state!.backendBaseUrl,
            },
    };
  }

  Map<String, Object?> _publisherBackendFirebaseOutputsJson(
    PublisherBackendFirebaseOutputsResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase outputs',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'outputs': result.outputs,
      'backendBaseUrl': result.outputs['PublisherBackendBaseUrl'],
      'healthUrl': result.outputs['PublisherBackendHealthUrl'],
    };
  }

  Map<String, Object?> _publisherBackendFirebaseAuthStatusJson(
    _PublisherBackendFirebaseAuthStatusCliResult result,
  ) {
    final authStatus = result.authStatus;
    final hostAuthReadiness = result.hostAuthReadiness;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase auth status',
      'provider': authStatus.provider,
      'environmentName': authStatus.environmentName,
      'projectId': authStatus.projectId,
      'region': authStatus.region,
      'functionName': authStatus.functionName,
      'miniProgramId': authStatus.miniProgramId,
      'backendRootPath': authStatus.backendRootPath,
      'functionsRootPath': authStatus.functionsRootPath,
      'authWebApiKeyConfigured': authStatus.authWebApiKeyConfigured,
      'scaffoldExists': authStatus.scaffoldExists,
      'authServiceFileExists': authStatus.authServiceFileExists,
      'routerFileExists': authStatus.routerFileExists,
      'routerAuthRoutesReady': authStatus.routerAuthRoutesReady,
      'routerAllowsAuthorizationHeader':
          authStatus.routerAllowsAuthorizationHeader,
      'packageJsonFileExists': authStatus.packageJsonFileExists,
      'packageJsonHasFirebaseAdmin': authStatus.packageJsonHasFirebaseAdmin,
      'packageJsonHasFirebaseFunctions':
          authStatus.packageJsonHasFirebaseFunctions,
      'envFilePath': authStatus.envFilePath,
      'envFileExists': authStatus.envFileExists,
      'envAuthKeyConfigured': authStatus.envAuthKeyConfigured,
      'envUsesReservedAuthKey': authStatus.envUsesReservedAuthKey,
      'deployEnvReady': authStatus.deployEnvReady,
      'ready': authStatus.ready,
      'issues': authStatus.issues,
      'warnings': authStatus.warnings,
      'hostAuthChecked': hostAuthReadiness != null,
      'hostProjectRootPath': result.hostProjectRootPath,
      'hostAuthControllerReady': hostAuthReadiness?.ready,
      'hostRuntimeSetupPath': hostAuthReadiness?.runtimeSetupPath,
      'hostAuthControllerConfigured':
          hostAuthReadiness?.authControllerConfigured,
      'hostSecureAuthControllerConfigured':
          hostAuthReadiness?.secureAuthControllerConfigured,
      'hostDisposeAuthControllerConfigured':
          hostAuthReadiness?.disposeAuthControllerConfigured,
      'hostAuthIssues': hostAuthReadiness?.issues ?? const <String>[],
    };
  }

  Map<String, Object?> _publisherBackendFirebaseHostCommandJson(
    _PublisherBackendFirebaseHostCommandResult result,
  ) {
    final readiness = result.readiness;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase host-command',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramRootPath': result.miniProgramRootPath,
      'miniProgramId': result.miniProgramId,
      'title': result.title,
      'deliveryApiBaseUrl': result.deliveryApiBaseUrl,
      'backendBaseUrl': result.backendBaseUrl,
      'accessMode': result.accessMode,
      'hostEndpointCommandText': result.hostEndpointCommandText,
      'hostEndpointChecked': readiness != null,
      'hostEndpointReady': readiness?.ready,
      'hostProjectRootPath': result.hostProjectRootPath,
      'hostEndpointMapPath': readiness?.endpointMapPath,
      'hostEndpointFound': readiness?.endpointFound,
      'hostEndpointDeliveryApiBaseUrl': readiness?.apiBaseUrl,
      'hostEndpointBackendBaseUrl': readiness?.backendBaseUrl,
      'hostEndpointAccessMode': readiness?.accessMode,
      'hostEndpointBackendMode': readiness?.backendMode,
      'hostEndpointIssues': readiness?.issues ?? const <String>[],
      'hostAuthChecked': result.hostAuthReadiness != null,
      'hostAuthControllerReady': result.hostAuthReadiness?.ready,
      'hostRuntimeSetupPath': result.hostAuthReadiness?.runtimeSetupPath,
      'hostAuthControllerConfigured':
          result.hostAuthReadiness?.authControllerConfigured,
      'hostSecureAuthControllerConfigured':
          result.hostAuthReadiness?.secureAuthControllerConfigured,
      'hostDisposeAuthControllerConfigured':
          result.hostAuthReadiness?.disposeAuthControllerConfigured,
      'hostAuthIssues': result.hostAuthReadiness?.issues ?? const <String>[],
    };
  }

  Map<String, Object?> _publisherBackendFirebaseHandoffJson(
    _PublisherBackendFirebaseHandoffResult result,
  ) {
    final handoff = result.packageResult.handoff;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase handoff',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramRootPath': result.miniProgramRootPath,
      'miniProgramId': handoff.appId,
      'title': handoff.title,
      'deliveryApiBaseUrl': handoff.apiBaseUri.toString(),
      'backendBaseUrl': handoff.backendBaseUri?.toString(),
      'accessMode': handoff.accessMode,
      'accessKeyIncluded': handoff.accessKey != null,
      'packagePath': result.packageResult.filePath,
      'generatedAtUtc': handoff.generatedAtUtc,
      'hostImportCommandText': result.hostImportCommandText,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseAccessKeyCreateJson(
    PublisherBackendFirebaseAccessKeyCreateResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase access-key create',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'keyId': result.keyId,
      'accessKey': result.accessKey,
      'createdAtUtc': result.createdAtUtc,
      'expiresAtUtc': result.expiresAtUtc,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseAccessKeyListJson(
    PublisherBackendFirebaseAccessKeyListResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase access-key list',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'activeKeyCount': result.activeKeyCount,
      'keyCount': result.keyCount,
      'keys': result.keys
          .map(
            (key) => <String, Object?>{
              'keyId': key.keyId,
              'active': key.active,
              'currentlyActive': key.currentlyActive,
              'createdAtUtc': key.createdAtUtc,
              'updatedAtUtc': key.updatedAtUtc,
              'revokedAtUtc': key.revokedAtUtc,
              'expiresAtUtc': key.expiresAtUtc,
              'lastFour': key.lastFour,
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _publisherBackendFirebaseAccessKeyRevokeJson(
    PublisherBackendFirebaseAccessKeyRevokeResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase access-key revoke',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'keyId': result.keyId,
      'revokedAtUtc': result.revokedAtUtc,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseAccessKeyRotateJson(
    PublisherBackendFirebaseAccessKeyRotateResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase access-key rotate',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'miniProgramId': result.miniProgramId,
      'backendBaseUrl': result.backendBaseUrl,
      'revokedKeyId': result.revokedKeyId,
      'newKeyId': result.newKeyId,
      'accessKey': result.accessKey,
      'rotatedAtUtc': result.rotatedAtUtc,
      'expiresAtUtc': result.expiresAtUtc,
    };
  }

  Map<String, Object?> _publisherBackendFirebaseSmokeJson(
    PublisherBackendFirebaseSmokeResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend firebase smoke',
      'provider': result.provider,
      'environmentName': result.environmentName,
      'projectId': result.projectId,
      'region': result.region,
      'functionName': result.functionName,
      'backendBaseUrl': result.backendBaseUrl,
      'includeWrite': result.includeWrite,
      'writeCouponId': result.includeWrite ? result.writeCouponId : null,
      'writeUserId': result.includeWrite ? result.writeUserId : null,
      'includeAuth': result.includeAuth,
      'accessKeyProvided': result.accessKeyProvided,
      'authEmail': result.includeAuth ? result.authEmail : null,
      'authCreateUser': result.includeAuth ? result.authCreateUser : null,
      'passed': result.passed,
      'error': result.error,
      'routes': result.routes
          .map(
            (route) => <String, Object?>{
              'method': route.method,
              'path': route.path,
              'uri': route.uri.toString(),
              'statusCode': route.statusCode,
              'responseStatus': route.responseStatus,
              'redemptionVerified': route.redemptionVerified,
              'redemptionDocumentPath': route.redemptionDocumentPath,
              'verificationError': route.verificationError,
              'passed': route.passed,
              'error': route.error,
            },
          )
          .toList(),
    };
  }
}
