part of '../publisher_backend_starter.dart';

typedef PublisherBackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef PublisherBackendProcessStarter =
    Future<StartedPublisherBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef PublisherBackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef PublisherBackendPostRequester =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });
typedef PublisherBackendHttpRequester =
    Future<http.Response> Function(
      String method,
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });
typedef PublisherBackendFirebaseAccessTokenProvider =
    Future<String?> Function();
typedef PublisherBackendClock = DateTime Function();
typedef PublisherBackendDelay = Future<void> Function(Duration duration);

const List<String> _publisherBackendAwsSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
  '/auth/session',
];
const List<String> _publisherBackendFirebaseSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
];

const Duration _awsDeployHealthWaitTimeout = Duration(seconds: 45);
const Duration _awsDeployHealthAttemptTimeout = Duration(seconds: 5);
const Duration _awsDeployHealthRetryDelay = Duration(seconds: 1);
const Duration _firebaseDeployHealthWaitTimeout = Duration(seconds: 45);
const Duration _firebaseDeployHealthAttemptTimeout = Duration(seconds: 5);
const Duration _firebaseDeployHealthRetryDelay = Duration(seconds: 1);
const int _dynamoDbBatchWriteMaxAttempts = 5;

const String _publisherBackendStorageBundled = 'bundled';
const String _publisherBackendStorageDynamoDb = 'dynamodb';
const String _publisherBackendStorageFirestore = 'firestore';
const Set<String> _firebaseDataCollections = <String>{
  'home',
  'sessions',
  'coupons',
  'redemptions',
};
const String _firebaseCliClientId =
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const String _firebaseCliClientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const List<String> _firebaseCliTokenScopes = <String>[
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/firebase',
];
const String _awsSdkJavaScriptV3Version = '^3.1052.0';
const String _firebaseFunctionsVersion = '^7.2.5';
const String _firebaseAdminVersion = '^13.10.0';

class PublisherBackendException implements Exception {
  const PublisherBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublisherBackendScaffoldRequest {
  const PublisherBackendScaffoldRequest({
    required this.miniProgramRootPath,
    this.template = 'mock',
    this.storageMode = 'bundled',
    this.force = false,
    this.withStarterUi = false,
  });

  final String miniProgramRootPath;
  final String template;
  final String storageMode;
  final bool force;
  final bool withStarterUi;
}

class PublisherBackendScaffoldResult {
  const PublisherBackendScaffoldResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.template,
    required this.createdPaths,
    this.storageMode,
    this.starterUi,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String template;
  final List<String> createdPaths;
  final String? storageMode;
  final PublisherBackendFirebaseStarterUiResult? starterUi;
}

class PublisherBackendFirebaseStarterUiRequest {
  const PublisherBackendFirebaseStarterUiRequest({
    required this.miniProgramRootPath,
    this.force = false,
  });

  final String miniProgramRootPath;
  final bool force;
}

class PublisherBackendFirebaseStarterUiResult {
  const PublisherBackendFirebaseStarterUiResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.miniProgramId,
    required this.title,
    required this.entryScreen,
    required this.writtenPaths,
    required this.skippedPaths,
    required this.unchangedPaths,
    required this.force,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String miniProgramId;
  final String title;
  final String entryScreen;
  final List<String> writtenPaths;
  final List<String> skippedPaths;
  final List<String> unchangedPaths;
  final bool force;
}

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
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final bool includeWrite;
  final String writeCouponId;
  final String writeUserId;
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

class PublisherBackendFirebaseDeployRequest {
  const PublisherBackendFirebaseDeployRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.configurePublicInvoker = true,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final bool configurePublicInvoker;
}

class PublisherBackendFirebaseDeployResult {
  const PublisherBackendFirebaseDeployResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.backendBaseUrl,
    required this.healthUrl,
    required this.deployedAtUtc,
    required this.dependenciesInstalled,
    required this.publicInvokerConfigured,
    required this.publicInvokerChanged,
    required this.outputs,
    this.miniProgramRootPath,
    this.authTokenCreatorConfigured = false,
    this.authTokenCreatorChanged = false,
    this.authTokenCreatorServiceAccount,
    this.authTokenCreatorError,
    this.publicInvokerError,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String backendRootPath;
  final String functionsRootPath;
  final String backendBaseUrl;
  final String healthUrl;
  final String deployedAtUtc;
  final bool dependenciesInstalled;
  final bool publicInvokerConfigured;
  final bool publicInvokerChanged;
  final bool authTokenCreatorConfigured;
  final bool authTokenCreatorChanged;
  final Map<String, String> outputs;
  final String? miniProgramRootPath;
  final String? authTokenCreatorServiceAccount;
  final String? authTokenCreatorError;
  final String? publicInvokerError;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendFirebaseStatusRequest {
  const PublisherBackendFirebaseStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseStatusResult {
  const PublisherBackendFirebaseStatusResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.backendBaseUrl,
    required this.healthUrl,
    required this.scaffoldExists,
    required this.outputs,
    this.state,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String backendRootPath;
  final String functionsRootPath;
  final String backendBaseUrl;
  final String healthUrl;
  final bool scaffoldExists;
  final Map<String, String> outputs;
  final PublisherBackendFirebaseState? state;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendFirebaseOutputsRequest {
  const PublisherBackendFirebaseOutputsRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseOutputsResult {
  const PublisherBackendFirebaseOutputsResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.outputs,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final Map<String, String> outputs;
}

class PublisherBackendFirebaseAuthStatusRequest {
  const PublisherBackendFirebaseAuthStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseAuthStatusResult {
  const PublisherBackendFirebaseAuthStatusResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.authWebApiKeyConfigured,
    required this.scaffoldExists,
    required this.authServiceFileExists,
    required this.routerFileExists,
    required this.routerAuthRoutesReady,
    required this.routerAllowsAuthorizationHeader,
    required this.packageJsonFileExists,
    required this.packageJsonHasFirebaseAdmin,
    required this.packageJsonHasFirebaseFunctions,
    required this.envFilePath,
    required this.envFileExists,
    required this.envAuthKeyConfigured,
    required this.envUsesReservedAuthKey,
    required this.ready,
    required this.deployEnvReady,
    required this.issues,
    required this.warnings,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String backendRootPath;
  final String functionsRootPath;
  final bool authWebApiKeyConfigured;
  final bool scaffoldExists;
  final bool authServiceFileExists;
  final bool routerFileExists;
  final bool routerAuthRoutesReady;
  final bool routerAllowsAuthorizationHeader;
  final bool packageJsonFileExists;
  final bool packageJsonHasFirebaseAdmin;
  final bool packageJsonHasFirebaseFunctions;
  final String envFilePath;
  final bool envFileExists;
  final bool envAuthKeyConfigured;
  final bool envUsesReservedAuthKey;
  final bool ready;
  final bool deployEnvReady;
  final List<String> issues;
  final List<String> warnings;
}

class PublisherBackendFirebaseAccessKeyCreateRequest {
  const PublisherBackendFirebaseAccessKeyCreateRequest({
    required this.miniProgramRootPath,
    required this.environment,
    required this.keyId,
    this.accessKey,
    this.expiresAtUtc,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String keyId;
  final String? accessKey;
  final String? expiresAtUtc;
}

class PublisherBackendFirebaseAccessKeyListRequest {
  const PublisherBackendFirebaseAccessKeyListRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseAccessKeyRevokeRequest {
  const PublisherBackendFirebaseAccessKeyRevokeRequest({
    required this.miniProgramRootPath,
    required this.environment,
    required this.keyId,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String keyId;
}

class PublisherBackendFirebaseAccessKeyRotateRequest {
  const PublisherBackendFirebaseAccessKeyRotateRequest({
    required this.miniProgramRootPath,
    required this.environment,
    required this.keyId,
    this.newKeyId,
    this.accessKey,
    this.expiresAtUtc,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String keyId;
  final String? newKeyId;
  final String? accessKey;
  final String? expiresAtUtc;
}

class PublisherBackendFirebaseAccessKeyEntry {
  const PublisherBackendFirebaseAccessKeyEntry({
    required this.keyId,
    required this.active,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.revokedAtUtc,
    this.expiresAtUtc,
    this.lastFour,
  });

  final String keyId;
  final bool active;
  final String createdAtUtc;
  final String updatedAtUtc;
  final String? revokedAtUtc;
  final String? expiresAtUtc;
  final String? lastFour;

  bool get currentlyActive {
    if (!active || revokedAtUtc != null) {
      return false;
    }
    final expiresAt = expiresAtUtc == null
        ? null
        : DateTime.tryParse(expiresAtUtc!);
    return expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc());
  }
}

class PublisherBackendFirebaseAccessKeyCreateResult {
  const PublisherBackendFirebaseAccessKeyCreateResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.backendBaseUrl,
    required this.keyId,
    required this.accessKey,
    required this.createdAtUtc,
    this.expiresAtUtc,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String backendBaseUrl;
  final String keyId;
  final String accessKey;
  final String createdAtUtc;
  final String? expiresAtUtc;
}

class PublisherBackendFirebaseAccessKeyListResult {
  const PublisherBackendFirebaseAccessKeyListResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.backendBaseUrl,
    required this.keys,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String backendBaseUrl;
  final List<PublisherBackendFirebaseAccessKeyEntry> keys;

  int get keyCount => keys.length;
  int get activeKeyCount => keys.where((key) => key.currentlyActive).length;
}

class PublisherBackendFirebaseAccessKeyRevokeResult {
  const PublisherBackendFirebaseAccessKeyRevokeResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.backendBaseUrl,
    required this.keyId,
    required this.revokedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String backendBaseUrl;
  final String keyId;
  final String revokedAtUtc;
}

class PublisherBackendFirebaseAccessKeyRotateResult {
  const PublisherBackendFirebaseAccessKeyRotateResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.backendBaseUrl,
    required this.revokedKeyId,
    required this.newKeyId,
    required this.accessKey,
    required this.rotatedAtUtc,
    this.expiresAtUtc,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String backendBaseUrl;
  final String revokedKeyId;
  final String newKeyId;
  final String accessKey;
  final String rotatedAtUtc;
  final String? expiresAtUtc;
}

class PublisherBackendFirebaseSmokeRequest {
  const PublisherBackendFirebaseSmokeRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.includeWrite = false,
    this.writeCouponId = 'coupon-10',
    this.writeUserId = 'smoke-user',
    this.includeAuth = false,
    this.authEmail,
    this.authPassword,
    this.authCreateUser = false,
    this.accessKey,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final bool includeWrite;
  final String writeCouponId;
  final String writeUserId;
  final bool includeAuth;
  final String? authEmail;
  final String? authPassword;
  final bool authCreateUser;
  final String? accessKey;
}

class PublisherBackendFirebaseSmokeRouteResult {
  const PublisherBackendFirebaseSmokeRouteResult({
    required this.method,
    required this.path,
    required this.uri,
    required this.passed,
    this.statusCode,
    this.responseStatus,
    this.redemptionVerified,
    this.redemptionDocumentPath,
    this.verificationError,
    this.error,
  });

  final String method;
  final String path;
  final Uri uri;
  final bool passed;
  final int? statusCode;
  final String? responseStatus;
  final bool? redemptionVerified;
  final String? redemptionDocumentPath;
  final String? verificationError;
  final String? error;
}

class PublisherBackendFirebaseSmokeResult {
  const PublisherBackendFirebaseSmokeResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.backendBaseUrl,
    required this.passed,
    required this.routes,
    required this.includeWrite,
    required this.writeCouponId,
    required this.writeUserId,
    required this.includeAuth,
    required this.authCreateUser,
    this.authEmail,
    this.accessKeyProvided = false,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String backendBaseUrl;
  final bool passed;
  final List<PublisherBackendFirebaseSmokeRouteResult> routes;
  final bool includeWrite;
  final String writeCouponId;
  final String writeUserId;
  final bool includeAuth;
  final bool authCreateUser;
  final String? authEmail;
  final bool accessKeyProvided;
  final String? error;
}

class PublisherBackendFirebaseSeedRequest {
  const PublisherBackendFirebaseSeedRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseSeedResult {
  const PublisherBackendFirebaseSeedResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.seeded,
    required this.itemCount,
    required this.appRecordCount,
    required this.couponCount,
    required this.authSessionCount,
    required this.storageMode,
    this.backendBaseUrl,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final bool seeded;
  final int itemCount;
  final int appRecordCount;
  final int couponCount;
  final int authSessionCount;
  final String storageMode;
  final String? backendBaseUrl;
  final String? error;
}

class PublisherBackendFirebaseDataStatusRequest {
  const PublisherBackendFirebaseDataStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseDataStatusResult {
  const PublisherBackendFirebaseDataStatusResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.storageMode,
    required this.available,
    this.backendBaseUrl,
    this.homeRecordCount,
    this.authSessionCount,
    this.couponCount,
    this.redemptionCount,
    this.appRecordCount,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String storageMode;
  final bool available;
  final String? backendBaseUrl;
  final int? homeRecordCount;
  final int? authSessionCount;
  final int? couponCount;
  final int? redemptionCount;
  final int? appRecordCount;
  final String? error;
}

class PublisherBackendFirebaseDataExportRequest {
  const PublisherBackendFirebaseDataExportRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.outputPath,
    this.includeRedemptions = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? outputPath;
  final bool includeRedemptions;
}

class PublisherBackendFirebaseDataExportResult {
  const PublisherBackendFirebaseDataExportResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.storageMode,
    required this.exported,
    required this.includeRedemptions,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.itemCount,
    this.backendBaseUrl,
    this.outputPath,
    this.exportedAtUtc,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String storageMode;
  final bool exported;
  final bool includeRedemptions;
  final int appRecordCount;
  final int redemptionCount;
  final int itemCount;
  final String? backendBaseUrl;
  final String? outputPath;
  final String? exportedAtUtc;
  final String? error;
}

class PublisherBackendFirebaseDataImportRequest {
  const PublisherBackendFirebaseDataImportRequest({
    required this.miniProgramRootPath,
    required this.environment,
    required this.inputPath,
    this.includeRedemptions = false,
    this.dryRun = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String inputPath;
  final bool includeRedemptions;
  final bool dryRun;
}

class PublisherBackendFirebaseDataImportResult {
  const PublisherBackendFirebaseDataImportResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.storageMode,
    required this.succeeded,
    required this.imported,
    required this.dryRun,
    required this.includeRedemptions,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.skippedRedemptionCount,
    required this.itemCount,
    required this.inputPath,
    this.backendBaseUrl,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String storageMode;
  final bool succeeded;
  final bool imported;
  final bool dryRun;
  final bool includeRedemptions;
  final int appRecordCount;
  final int redemptionCount;
  final int skippedRedemptionCount;
  final int itemCount;
  final String inputPath;
  final String? backendBaseUrl;
  final String? error;
}

class PublisherBackendFirebaseDataRedemptionsRequest {
  const PublisherBackendFirebaseDataRedemptionsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.couponId,
    this.userId,
    this.limit = 50,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? couponId;
  final String? userId;
  final int limit;
}

class PublisherBackendFirebaseDataRedemptionsResult {
  const PublisherBackendFirebaseDataRedemptionsResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.storageMode,
    required this.available,
    required this.limit,
    required this.matchedCount,
    required this.returnedCount,
    required this.records,
    this.backendBaseUrl,
    this.couponId,
    this.userId,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final String storageMode;
  final bool available;
  final int limit;
  final int matchedCount;
  final int returnedCount;
  final List<Map<String, Object?>> records;
  final String? backendBaseUrl;
  final String? couponId;
  final String? userId;
  final String? error;
}

class PublisherBackendFirebaseDestroyRequest {
  const PublisherBackendFirebaseDestroyRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.confirmDataLoss = false,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final bool confirmDataLoss;
}

class PublisherBackendFirebaseDestroyResult {
  const PublisherBackendFirebaseDestroyResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramId,
    required this.deleted,
    required this.dataLossConfirmed,
    this.backendBaseUrl,
    this.deletedAtUtc,
    this.appRecordCount,
    this.redemptionCount,
    this.blockedByData = false,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramId;
  final bool deleted;
  final bool dataLossConfirmed;
  final String? backendBaseUrl;
  final String? deletedAtUtc;
  final int? appRecordCount;
  final int? redemptionCount;
  final bool blockedByData;
  final String? error;
}

class PublisherBackendRunResult {
  const PublisherBackendRunResult({
    required this.state,
    required this.alreadyRunning,
  });

  final PublisherBackendState state;
  final bool alreadyRunning;
}

class PublisherBackendStatusResult {
  const PublisherBackendStatusResult({
    required this.state,
    required this.hasState,
    required this.processAlive,
    required this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final PublisherBackendState? state;
  final bool hasState;
  final bool processAlive;
  final bool healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendStopResult {
  const PublisherBackendStopResult({
    required this.hadState,
    required this.processWasAlive,
    required this.stopped,
    required this.clearedStaleState,
  });

  final bool hadState;
  final bool processWasAlive;
  final bool stopped;
  final bool clearedStaleState;
}

class PublisherBackendUrlsResult {
  const PublisherBackendUrlsResult({required this.port});

  final int port;

  String get desktopBaseUrl => 'http://127.0.0.1:$port/';
  String get androidEmulatorBaseUrl => 'http://10.0.2.2:$port/';
  String get androidUsbBaseUrl => 'http://127.0.0.1:$port/';
}

class PublisherBackendState {
  const PublisherBackendState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.pid,
    required this.port,
    required this.bindHost,
    required this.healthCheckUrl,
    required this.stdoutLogPath,
    required this.stderrLogPath,
    required this.startedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final int pid;
  final int port;
  final String bindHost;
  final String healthCheckUrl;
  final String stdoutLogPath;
  final String stderrLogPath;
  final String startedAtUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'pid': pid,
    'port': port,
    'bindHost': bindHost,
    'healthCheckUrl': healthCheckUrl,
    'stdoutLogPath': stdoutLogPath,
    'stderrLogPath': stderrLogPath,
    'startedAtUtc': startedAtUtc,
  };

  static PublisherBackendState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final pid = json['pid'];
    final port = json['port'];
    final bindHost = json['bindHost'];
    final healthCheckUrl = json['healthCheckUrl'];
    final stdoutLogPath = json['stdoutLogPath'];
    final stderrLogPath = json['stderrLogPath'];
    final startedAtUtc = json['startedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        pid is! int ||
        port is! int ||
        bindHost is! String ||
        healthCheckUrl is! String ||
        stdoutLogPath is! String ||
        stderrLogPath is! String ||
        startedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.local.json is missing required fields.',
      );
    }
    return PublisherBackendState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      pid: pid,
      port: port,
      bindHost: bindHost,
      healthCheckUrl: healthCheckUrl,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: startedAtUtc,
    );
  }
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

class PublisherBackendFirebaseState {
  const PublisherBackendFirebaseState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.functionUrl,
    required this.outputs,
    required this.deployedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final String functionsRootPath;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String functionUrl;
  final Map<String, String> outputs;
  final String deployedAtUtc;

  String get backendBaseUrl =>
      outputs['PublisherBackendBaseUrl'] ?? functionUrl;
  String get healthUrl =>
      outputs['PublisherBackendHealthUrl'] ??
      _firebaseHealthUrlFromFunctionUrl(functionUrl);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'functionsRootPath': functionsRootPath,
    'environmentName': environmentName,
    'projectId': projectId,
    'region': region,
    'functionName': functionName,
    'functionUrl': functionUrl,
    'outputs': outputs,
    'deployedAtUtc': deployedAtUtc,
  };

  static PublisherBackendFirebaseState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final functionsRootPath = json['functionsRootPath'];
    final environmentName = json['environmentName'];
    final projectId = json['projectId'];
    final region = json['region'];
    final functionName = json['functionName'];
    final functionUrl = json['functionUrl'];
    final outputs = json['outputs'];
    final deployedAtUtc = json['deployedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        functionsRootPath is! String ||
        environmentName is! String ||
        projectId is! String ||
        region is! String ||
        functionName is! String ||
        functionUrl is! String ||
        outputs is! Map ||
        deployedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.firebase.json is missing required fields.',
      );
    }
    return PublisherBackendFirebaseState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      functionsRootPath: p.normalize(p.absolute(functionsRootPath)),
      environmentName: environmentName,
      projectId: projectId,
      region: region,
      functionName: functionName,
      functionUrl: functionUrl,
      outputs: outputs.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      deployedAtUtc: deployedAtUtc,
    );
  }
}

class StartedPublisherBackendProcess {
  const StartedPublisherBackendProcess({required this.pid});

  final int pid;
}
