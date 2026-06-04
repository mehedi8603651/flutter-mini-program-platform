part of '../../publisher_backend_starter.dart';

class PublisherBackendAwsDeployRequest {
  const PublisherBackendAwsDeployRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsDeployResult {
  const PublisherBackendAwsDeployResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    required this.backendRootPath,
    required this.outputs,
    required this.deployedAtUtc,
    this.miniProgramRootPath,
    this.backendBaseUrl,
    this.healthUrl,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final String backendRootPath;
  final String? miniProgramRootPath;
  final Map<String, String> outputs;
  final String deployedAtUtc;
  final String? backendBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendAwsStatusRequest {
  const PublisherBackendAwsStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsStatusResult {
  const PublisherBackendAwsStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.outputs,
    this.state,
    this.stackStatus,
    this.stackStatusReason,
    this.backendBaseUrl,
    this.healthUrl,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final PublisherBackendAwsState? state;
  final String? stackStatus;
  final String? stackStatusReason;
  final Map<String, String> outputs;
  final String? backendBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendAwsOutputsRequest {
  const PublisherBackendAwsOutputsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsOutputsResult {
  const PublisherBackendAwsOutputsResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.outputs,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final Map<String, String> outputs;
}

class PublisherBackendAwsSmokeRequest {
  const PublisherBackendAwsSmokeRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.includeWrite = false,
    this.writeCouponId = 'coupon-10',
    this.writeUserId = 'smoke-user',
    this.accessKey,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final bool includeWrite;
  final String writeCouponId;
  final String writeUserId;
  final String? accessKey;
}

class PublisherBackendAwsSmokeRouteResult {
  const PublisherBackendAwsSmokeRouteResult({
    required this.method,
    required this.path,
    required this.uri,
    required this.passed,
    this.statusCode,
    this.responseStatus,
    this.error,
  });

  final String method;
  final String path;
  final Uri uri;
  final bool passed;
  final int? statusCode;
  final String? responseStatus;
  final String? error;
}

class PublisherBackendAwsSmokeResult {
  const PublisherBackendAwsSmokeResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.passed,
    required this.routes,
    required this.includeWrite,
    this.accessKeyProvided = false,
    this.backendBaseUrl,
    this.stackStatus,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool passed;
  final List<PublisherBackendAwsSmokeRouteResult> routes;
  final bool includeWrite;
  final bool accessKeyProvided;
  final String? backendBaseUrl;
  final String? stackStatus;
  final String? error;
}

class PublisherBackendAwsSeedRequest {
  const PublisherBackendAwsSeedRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsSeedResult {
  const PublisherBackendAwsSeedResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.seeded,
    required this.itemCount,
    required this.miniProgramId,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool seeded;
  final int itemCount;
  final String miniProgramId;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? error;
}

class PublisherBackendAwsDataStatusRequest {
  const PublisherBackendAwsDataStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsDataStatusResult {
  const PublisherBackendAwsDataStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.available,
    required this.miniProgramId,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.tableStatus,
    this.appRecordCount,
    this.redemptionCount,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool available;
  final String miniProgramId;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? tableStatus;
  final int? appRecordCount;
  final int? redemptionCount;
  final String? error;
}

class PublisherBackendAwsDataExportRequest {
  const PublisherBackendAwsDataExportRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.outputPath,
    this.includeRedemptions = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final String? outputPath;
  final bool includeRedemptions;
}

class PublisherBackendAwsDataExportResult {
  const PublisherBackendAwsDataExportResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.exported,
    required this.miniProgramId,
    required this.includeRedemptions,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.itemCount,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.outputPath,
    this.exportedAtUtc,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool exported;
  final String miniProgramId;
  final bool includeRedemptions;
  final int appRecordCount;
  final int redemptionCount;
  final int itemCount;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? outputPath;
  final String? exportedAtUtc;
  final String? error;
}

class PublisherBackendAwsDataImportRequest {
  const PublisherBackendAwsDataImportRequest({
    required this.miniProgramRootPath,
    required this.environment,
    required this.inputPath,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.includeRedemptions = false,
    this.dryRun = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String inputPath;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final bool includeRedemptions;
  final bool dryRun;
}

class PublisherBackendAwsDataImportResult {
  const PublisherBackendAwsDataImportResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.succeeded,
    required this.imported,
    required this.dryRun,
    required this.miniProgramId,
    required this.includeRedemptions,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.skippedRedemptionCount,
    required this.itemCount,
    required this.inputPath,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool succeeded;
  final bool imported;
  final bool dryRun;
  final String miniProgramId;
  final bool includeRedemptions;
  final int appRecordCount;
  final int redemptionCount;
  final int skippedRedemptionCount;
  final int itemCount;
  final String inputPath;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? error;
}

class PublisherBackendAwsDataRedemptionsRequest {
  const PublisherBackendAwsDataRedemptionsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.couponId,
    this.userId,
    this.limit = 50,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final String? couponId;
  final String? userId;
  final int limit;
}

class PublisherBackendAwsDataRedemptionsResult {
  const PublisherBackendAwsDataRedemptionsResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.available,
    required this.miniProgramId,
    required this.limit,
    required this.matchedCount,
    required this.returnedCount,
    required this.records,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.couponId,
    this.userId,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool available;
  final String miniProgramId;
  final int limit;
  final int matchedCount;
  final int returnedCount;
  final List<Map<String, Object?>> records;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? couponId;
  final String? userId;
  final String? error;
}

class PublisherBackendAwsLogsRequest {
  const PublisherBackendAwsLogsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.since = '1h',
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final String since;
}

class PublisherBackendAwsLogsResult {
  const PublisherBackendAwsLogsResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.lambdaFunctionName,
    required this.since,
    required this.stdoutText,
    required this.stderrText,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final String lambdaFunctionName;
  final String since;
  final String stdoutText;
  final String stderrText;
}

class PublisherBackendAwsDestroyRequest {
  const PublisherBackendAwsDestroyRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.confirmDataLoss = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final bool confirmDataLoss;
}

class PublisherBackendAwsDestroyResult {
  const PublisherBackendAwsDestroyResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.deleted,
    required this.dataLossConfirmed,
    this.deletedAtUtc,
    this.tableName,
    this.appRecordCount,
    this.redemptionCount,
    this.blockedByData = false,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final bool deleted;
  final bool dataLossConfirmed;
  final String? deletedAtUtc;
  final String? tableName;
  final int? appRecordCount;
  final int? redemptionCount;
  final bool blockedByData;
  final String? error;
}

class PublisherBackendAwsState {
  const PublisherBackendAwsState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    required this.outputs,
    required this.deployedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final Map<String, String> outputs;
  final String deployedAtUtc;

  String? get backendBaseUrl => outputs['PublisherBackendBaseUrl'];
  String? get healthUrl => outputs['PublisherBackendHealthUrl'];
  String? get functionName => outputs['PublisherBackendFunctionName'];

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'environmentName': environmentName,
    'stackName': stackName,
    'stageName': stageName,
    'region': region,
    'samS3Bucket': samS3Bucket,
    'outputs': outputs,
    'deployedAtUtc': deployedAtUtc,
  };

  static PublisherBackendAwsState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final environmentName = json['environmentName'];
    final stackName = json['stackName'];
    final stageName = json['stageName'];
    final region = json['region'];
    final samS3Bucket = json['samS3Bucket'];
    final outputs = json['outputs'];
    final deployedAtUtc = json['deployedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        environmentName is! String ||
        stackName is! String ||
        stageName is! String ||
        region is! String ||
        samS3Bucket is! String ||
        outputs is! Map ||
        deployedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.aws.json is missing required fields.',
      );
    }
    return PublisherBackendAwsState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      environmentName: environmentName,
      stackName: stackName,
      stageName: stageName,
      region: region,
      samS3Bucket: samS3Bucket,
      outputs: outputs.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      deployedAtUtc: deployedAtUtc,
    );
  }
}
