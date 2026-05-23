import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

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
typedef PublisherBackendClock = DateTime Function();
typedef PublisherBackendDelay = Future<void> Function(Duration duration);

const List<String> _publisherBackendAwsSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
  '/auth/session',
];
const List<String> _publisherBackendFirebaseSmokeRoutePaths =
    _publisherBackendAwsSmokeRoutePaths;

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
  });

  final String miniProgramRootPath;
  final String template;
  final String storageMode;
  final bool force;
}

class PublisherBackendScaffoldResult {
  const PublisherBackendScaffoldResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.template,
    required this.createdPaths,
    this.storageMode,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String template;
  final List<String> createdPaths;
  final String? storageMode;
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
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
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
    required this.outputs,
    this.miniProgramRootPath,
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
  final Map<String, String> outputs;
  final String? miniProgramRootPath;
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

class PublisherBackendFirebaseSmokeRequest {
  const PublisherBackendFirebaseSmokeRequest({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class PublisherBackendFirebaseSmokeRouteResult {
  const PublisherBackendFirebaseSmokeRouteResult({
    required this.method,
    required this.path,
    required this.uri,
    required this.passed,
    this.statusCode,
    this.error,
  });

  final String method;
  final String path;
  final Uri uri;
  final bool passed;
  final int? statusCode;
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

class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner = _defaultShellRunner,
    PublisherBackendProcessStarter processStarter = _defaultProcessStarter,
    PublisherBackendHealthGetter healthGetter = http.get,
    PublisherBackendPostRequester postRequester = _defaultPostRequester,
    PublisherBackendClock clock = _defaultClock,
    PublisherBackendDelay delay = _defaultDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _postRequester = postRequester,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendPostRequester _postRequester;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) async {
    if (!const <String>[
      'mock',
      'aws-lambda',
      'firebase-functions',
    ].contains(request.template)) {
      throw PublisherBackendException(
        'Unsupported publisher backend template: ${request.template}',
      );
    }
    if (!const <String>[
      _publisherBackendStorageBundled,
      _publisherBackendStorageDynamoDb,
      _publisherBackendStorageFirestore,
    ].contains(request.storageMode)) {
      throw PublisherBackendException(
        'Unsupported publisher backend storage mode: ${request.storageMode}',
      );
    }
    if (request.template == 'mock' &&
        request.storageMode != _publisherBackendStorageBundled) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --storage is not supported with '
        '--template mock.',
      );
    }
    if (request.template == 'aws-lambda' &&
        !const <String>[
          _publisherBackendStorageBundled,
          _publisherBackendStorageDynamoDb,
        ].contains(request.storageMode)) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --template aws-lambda supports '
        '--storage bundled or --storage dynamodb.',
      );
    }
    if (request.template == 'firebase-functions' &&
        request.storageMode != _publisherBackendStorageFirestore) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --template firebase-functions requires '
        '--storage firestore.',
      );
    }
    final miniProgramRootPath = await _requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      switch (request.template) {
        'mock' => 'mock',
        'aws-lambda' => 'aws_lambda',
        'firebase-functions' => 'firebase_functions',
        _ => request.template,
      },
    );
    final createdPaths = <String>[];
    final files = switch (request.template) {
      'mock' => buildMockPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
      ),
      'aws-lambda' => buildAwsLambdaPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
        storageMode: request.storageMode,
      ),
      'firebase-functions' => buildFirebaseFunctionsPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
      ),
      _ => throw PublisherBackendException(
        'Unsupported publisher backend template: ${request.template}',
      ),
    };
    for (final entry in files.entries) {
      await _writeManagedFile(
        filePath: p.join(backendRootPath, entry.key),
        contents: entry.value,
        force: request.force,
        createdPaths: createdPaths,
      );
    }
    createdPaths.sort();
    return PublisherBackendScaffoldResult(
      miniProgramRootPath: miniProgramRootPath,
      backendRootPath: backendRootPath,
      template: request.template,
      createdPaths: createdPaths,
      storageMode:
          request.template == 'aws-lambda' ||
              request.template == 'firebase-functions'
          ? request.storageMode
          : null,
    );
  }

  Future<PublisherBackendRunResult> run({
    required String miniProgramRootPath,
    int port = 9090,
  }) async {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend run --port must be 1-65535.',
      );
    }
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final backendRootPath = p.join(rootPath, 'backend', 'mock');
    await _assertMockBackendPaths(backendRootPath);
    final previousState = await _readState(rootPath);
    if (previousState != null) {
      final previousStatus = await status(miniProgramRootPath: rootPath);
      if (previousStatus.processAlive && previousStatus.healthy) {
        return PublisherBackendRunResult(
          state: previousState,
          alreadyRunning: true,
        );
      }
      if (previousStatus.processAlive) {
        throw PublisherBackendException(
          'A recorded publisher backend process is alive but not healthy. '
          'Stop it or inspect logs before starting again.\n'
          '${previousStatus.healthError ?? previousState.healthCheckUrl}',
        );
      }
      await _clearState(rootPath);
    }

    final healthCheckUri = Uri.parse('http://127.0.0.1:$port/health');
    final preExisting = await _probeHealth(healthCheckUri);
    if (preExisting.healthy) {
      throw PublisherBackendException(
        'A publisher backend is already responding at $healthCheckUri, but no '
        'tracked state was found. Stop that server or use another --port.',
      );
    }

    final stateDirectory = await _ensureStateDirectory(rootPath);
    final stdoutLogPath = p.join(
      stateDirectory.path,
      'publisher_backend.local.out.log',
    );
    final stderrLogPath = p.join(
      stateDirectory.path,
      'publisher_backend.local.err.log',
    );
    final launcherScriptPath = p.join(
      stateDirectory.path,
      Platform.isWindows
          ? 'publisher_backend.local.runner.cmd'
          : 'publisher_backend.local.runner.sh',
    );
    await File(stdoutLogPath).writeAsString('');
    await File(stderrLogPath).writeAsString('');
    await _writeLauncherScript(
      launcherScriptPath: launcherScriptPath,
      backendRootPath: backendRootPath,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      port: port,
    );

    final startedProcess = await _processStarter(
      executable: Platform.isWindows ? 'cmd.exe' : 'sh',
      arguments: Platform.isWindows
          ? <String>['/c', launcherScriptPath]
          : <String>[launcherScriptPath],
      workingDirectory: stateDirectory.path,
    );
    final startupHealth = await _waitForHealthCheck(
      healthCheckUri,
      timeout: const Duration(seconds: 20),
    );
    if (!startupHealth.healthy) {
      await _terminateProcess(startedProcess.pid);
      final stderrTail = await _readLogTail(stderrLogPath);
      throw PublisherBackendException(
        [
          'Failed to confirm publisher backend health at $healthCheckUri.',
          if (startupHealth.statusCode != null)
            'Last health status code: ${startupHealth.statusCode}',
          if (startupHealth.error != null)
            'Last health detail: ${startupHealth.error}',
          if (stderrTail.isNotEmpty) 'stderr tail:\n$stderrTail',
        ].join('\n'),
      );
    }

    final state = PublisherBackendState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: backendRootPath,
      pid: startedProcess.pid,
      port: port,
      bindHost: '0.0.0.0',
      healthCheckUrl: healthCheckUri.toString(),
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: _clock().toUtc().toIso8601String(),
    );
    await _writeState(rootPath, state);
    return PublisherBackendRunResult(state: state, alreadyRunning: false);
  }

  Future<PublisherBackendStatusResult> status({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final state = await _readState(rootPath);
    if (state == null) {
      return const PublisherBackendStatusResult(
        state: null,
        hasState: false,
        processAlive: false,
        healthy: false,
      );
    }
    final processAlive = await _isProcessAlive(state.pid);
    final health = await _probeHealth(Uri.parse(state.healthCheckUrl));
    String? healthError = health.error;
    if (!processAlive && health.healthy) {
      healthError =
          'Recorded publisher backend PID is stale, but a backend is still '
          'responding at ${state.healthCheckUrl}.';
    } else if (!processAlive && !health.healthy && healthError == null) {
      healthError = 'Recorded publisher backend PID is no longer running.';
    }
    return PublisherBackendStatusResult(
      state: state,
      hasState: true,
      processAlive: processAlive,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: healthError,
    );
  }

  Future<PublisherBackendStopResult> stop({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final state = await _readState(rootPath);
    if (state == null) {
      return const PublisherBackendStopResult(
        hadState: false,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: false,
      );
    }
    final processAlive = await _isProcessAlive(state.pid);
    if (!processAlive) {
      await _clearState(rootPath);
      return const PublisherBackendStopResult(
        hadState: true,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: true,
      );
    }
    final stopResult = await _terminateProcess(state.pid);
    if (stopResult.exitCode != 0 && await _isProcessAlive(state.pid)) {
      final stderrText = '${stopResult.stderr}'.trim();
      throw PublisherBackendException(
        stderrText.isEmpty
            ? 'Failed to stop publisher backend PID ${state.pid}.'
            : 'Failed to stop publisher backend PID ${state.pid}.\n$stderrText',
      );
    }
    await _waitForBackendUnavailable(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    await _clearState(rootPath);
    return const PublisherBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  PublisherBackendUrlsResult urls({int port = 9090}) {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend urls --port must be 1-65535.',
      );
    }
    return PublisherBackendUrlsResult(port: port);
  }

  Future<PublisherBackendAwsDeployResult> awsDeploy(
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

  Future<PublisherBackendAwsStatusResult> awsStatus(
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

  Future<PublisherBackendAwsOutputsResult> awsOutputs(
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

  Future<PublisherBackendAwsSmokeResult> awsSmoke(
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

  Future<PublisherBackendFirebaseDeployResult> firebaseDeploy(
    PublisherBackendFirebaseDeployRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    await _assertFirebaseBackendPaths(settings.backendRootPath);
    final dependenciesInstalled = await _ensureFirebaseDependencies(settings);
    await _writeFirebaseEnvFile(settings);
    await _runFirebaseCommand(<String>[
      'deploy',
      '--only',
      'functions:${settings.functionName}',
      '--project',
      settings.projectId,
    ], workingDirectory: settings.backendRootPath);

    final outputs = settings.outputs;
    final health = await _waitForHealthCheck(
      Uri.parse(settings.healthUrl),
      timeout: _firebaseDeployHealthWaitTimeout,
      attemptTimeout: _firebaseDeployHealthAttemptTimeout,
      retryDelay: _firebaseDeployHealthRetryDelay,
    );
    final deployedAtUtc = _clock().toUtc().toIso8601String();
    final state = PublisherBackendFirebaseState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      functionUrl: settings.functionUrl,
      outputs: outputs,
      deployedAtUtc: deployedAtUtc,
    );
    await _writeFirebaseState(rootPath, state);
    return PublisherBackendFirebaseDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      miniProgramRootPath: rootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      deployedAtUtc: deployedAtUtc,
      dependenciesInstalled: dependenciesInstalled,
      outputs: outputs,
    );
  }

  Future<PublisherBackendFirebaseStatusResult> firebaseStatus(
    PublisherBackendFirebaseStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final state = await _readFirebaseState(rootPath);
    final scaffoldExists = await _firebaseBackendPathsExist(
      settings.backendRootPath,
    );
    final health = scaffoldExists
        ? await _probeHealth(Uri.parse(settings.healthUrl))
        : const _PublisherBackendHealth(
            healthy: false,
            error:
                'Firebase Functions publisher backend scaffold was not found.',
          );
    return PublisherBackendFirebaseStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      scaffoldExists: scaffoldExists,
      state: state,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseOutputsResult> firebaseOutputs(
    PublisherBackendFirebaseOutputsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    return PublisherBackendFirebaseOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseSmokeResult> firebaseSmoke(
    PublisherBackendFirebaseSmokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        backendBaseUrl: settings.functionUrl,
        passed: false,
        routes: const <PublisherBackendFirebaseSmokeRouteResult>[],
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final baseUri = Uri.parse(settings.functionUrl);
    final routes = <PublisherBackendFirebaseSmokeRouteResult>[];
    for (final path in _publisherBackendFirebaseSmokeRoutePaths) {
      routes.add(
        await _probeFirebaseSmokeRoute(
          method: 'GET',
          path: path,
          uri: _resolveBackendRoute(baseUri, path),
        ),
      );
    }
    return PublisherBackendFirebaseSmokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendBaseUrl: settings.functionUrl,
      passed: routes.every((route) => route.passed),
      routes: routes,
    );
  }

  Future<PublisherBackendAwsSeedResult> awsSeed(
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

  Future<PublisherBackendAwsDataStatusResult> awsDataStatus(
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

  Future<PublisherBackendAwsDataExportResult> awsDataExport(
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

  Future<PublisherBackendAwsDataImportResult> awsDataImport(
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

  Future<PublisherBackendAwsDataRedemptionsResult> awsDataRedemptions(
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

  Future<PublisherBackendAwsLogsResult> awsLogs(
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

  Future<PublisherBackendAwsDestroyResult> awsDestroy(
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

  Future<String> _requireMiniProgramRoot(String rawRootPath) async {
    final rootPath = p.normalize(p.absolute(rawRootPath));
    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $rootPath',
      );
    }
    return rootPath;
  }

  Future<void> _assertMockBackendPaths(String backendRootPath) async {
    final serverFile = File(p.join(backendRootPath, 'bin', 'server.dart'));
    final dataDirectory = Directory(p.join(backendRootPath, 'data'));
    if (!await serverFile.exists() || !await dataDirectory.exists()) {
      throw PublisherBackendException(
        'Publisher mock backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template mock` first.',
      );
    }
  }

  Future<void> _assertAwsBackendPaths(String backendRootPath) async {
    final templateFile = File(p.join(backendRootPath, 'template.yaml'));
    final handlerFile = File(p.join(backendRootPath, 'src', 'handler.mjs'));
    if (!await templateFile.exists() || !await handlerFile.exists()) {
      throw const PublisherBackendException(
        'AWS Lambda publisher backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template aws-lambda` first.',
      );
    }
  }

  Future<bool> _firebaseBackendPathsExist(String backendRootPath) async {
    final firebaseJsonFile = File(p.join(backendRootPath, 'firebase.json'));
    final packageJsonFile = File(
      p.join(backendRootPath, 'functions', 'package.json'),
    );
    final indexFile = File(p.join(backendRootPath, 'functions', 'index.js'));
    final routerFile = File(p.join(backendRootPath, 'functions', 'router.js'));
    return await firebaseJsonFile.exists() &&
        await packageJsonFile.exists() &&
        await indexFile.exists() &&
        await routerFile.exists();
  }

  Future<void> _assertFirebaseBackendPaths(String backendRootPath) async {
    if (!await _firebaseBackendPathsExist(backendRootPath)) {
      throw const PublisherBackendException(
        'Firebase Functions publisher backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }
  }

  Future<void> _writeManagedFile({
    required String filePath,
    required String contents,
    required bool force,
    required List<String> createdPaths,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final existing = await file.readAsString();
      if (existing == contents) {
        return;
      }
      if (!force) {
        throw PublisherBackendException(
          'Publisher backend scaffold would overwrite an existing file. '
          'Re-run with --force if you want to replace scaffold-managed files.\n'
          '$filePath',
        );
      }
    } else {
      createdPaths.add(filePath);
    }
    await file.writeAsString(contents);
  }

  Future<void> _writeLauncherScript({
    required String launcherScriptPath,
    required String backendRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final serverScriptPath = p.join(backendRootPath, 'bin', 'server.dart');
    final content = Platform.isWindows
        ? <String>[
            '@echo off',
            'setlocal',
            'cd /d ${_quoteForCmd(backendRootPath)}',
            '${_quoteForCmd(Platform.resolvedExecutable)} '
                '${_quoteForCmd(serverScriptPath)} '
                '${_quoteForCmd('--host=0.0.0.0')} '
                '${_quoteForCmd('--port=$port')} '
                '1>>${_quoteForCmd(stdoutLogPath)} '
                '2>>${_quoteForCmd(stderrLogPath)}',
          ].join('\r\n')
        : <String>[
            '#!/usr/bin/env sh',
            'set -eu',
            'cd ${_quoteForSh(backendRootPath)}',
            'exec ${_quoteForSh(Platform.resolvedExecutable)} '
                '${_quoteForSh(serverScriptPath)} '
                '${_quoteForSh('--host=0.0.0.0')} '
                '${_quoteForSh('--port=$port')} '
                '>>${_quoteForSh(stdoutLogPath)} '
                '2>>${_quoteForSh(stderrLogPath)}',
            '',
          ].join('\n');
    await File(launcherScriptPath).writeAsString(content);
  }

  Future<Directory> _ensureStateDirectory(String miniProgramRootPath) async {
    final directory = Directory(p.join(miniProgramRootPath, '.mini_program'));
    await directory.create(recursive: true);
    return directory;
  }

  String _statePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.local.json',
  );

  Future<PublisherBackendState?> _readState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.local.json must contain a JSON object.',
      );
    }
    return PublisherBackendState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeState(
    String miniProgramRootPath,
    PublisherBackendState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.local.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _awsStatePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.aws.json',
  );

  Future<PublisherBackendAwsState?> _readAwsState(
    String miniProgramRootPath,
  ) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.aws.json must contain a JSON object.',
      );
    }
    return PublisherBackendAwsState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeAwsState(
    String miniProgramRootPath,
    PublisherBackendAwsState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.aws.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearAwsState(String miniProgramRootPath) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _firebaseStatePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.firebase.json',
  );

  Future<PublisherBackendFirebaseState?> _readFirebaseState(
    String miniProgramRootPath,
  ) async {
    final file = File(_firebaseStatePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.firebase.json must contain a JSON object.',
      );
    }
    return PublisherBackendFirebaseState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeFirebaseState(
    String miniProgramRootPath,
    PublisherBackendFirebaseState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(
      p.join(directory.path, 'publisher_backend.firebase.json'),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _runSamCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final arguments = <String>[
      ...commandArguments,
      if (settings.awsProfile != null) '--profile',
      if (settings.awsProfile != null) settings.awsProfile!,
    ];
    final result = await _shellRunner(
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

  Future<void> _runFirebaseCommand(
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final result = await _shellRunner(
      'firebase',
      commandArguments,
      workingDirectory: workingDirectory,
    );
    _requireSuccess(
      executable: 'firebase',
      arguments: commandArguments,
      result: result,
      toolLabel: 'Firebase CLI',
    );
  }

  Future<bool> _ensureFirebaseDependencies(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final nodeModulesDirectory = Directory(
      p.join(settings.functionsRootPath, 'node_modules'),
    );
    if (await nodeModulesDirectory.exists()) {
      return false;
    }
    final arguments = <String>['install'];
    final result = await _shellRunner(
      'npm',
      arguments,
      workingDirectory: settings.functionsRootPath,
    );
    _requireSuccess(
      executable: 'npm',
      arguments: arguments,
      result: result,
      toolLabel: 'npm',
    );
    return true;
  }

  Future<void> _writeFirebaseEnvFile(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final file = File(p.join(settings.functionsRootPath, '.env'));
    final lines = <String>[];
    if (await file.exists()) {
      for (final line in const LineSplitter().convert(
        await file.readAsString(),
      )) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('FUNCTION_REGION=') ||
            trimmed.startsWith('MINI_PROGRAM_ID=')) {
          continue;
        }
        lines.add(line);
      }
    } else {
      await file.parent.create(recursive: true);
    }
    lines
      ..add('FUNCTION_REGION=${settings.region}')
      ..add('MINI_PROGRAM_ID=${settings.miniProgramId}');
    await file.writeAsString('${lines.join('\n')}\n');
  }

  Future<void> _runAwsCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    bool allowEmptyJsonOutput = false,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
      '--output',
      'json',
    ];
    final result = await _shellRunner('aws', arguments);
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
      throw PublisherBackendException(
        'AWS CLI returned no JSON output for command: aws ${arguments.join(' ')}',
      );
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned non-object JSON for command: aws ${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, dynamic>?> _describeStack(
    _PublisherBackendAwsSettings settings,
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
    final result = await _shellRunner('aws', arguments);
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
      throw const PublisherBackendException(
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
    _PublisherBackendAwsSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'describe-stack-resources',
      '--stack-name',
      settings.stackName,
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

  Future<_PublisherBackendAwsSeedData> _readAwsSeedData(
    _PublisherBackendAwsSettings settings,
  ) async {
    final dataRootPath = p.join(settings.backendRootPath, 'src', 'data');
    final home = await _readJsonObjectFile(
      p.join(dataRootPath, 'home_bootstrap.json'),
      label: 'home_bootstrap.json',
    );
    final session = await _readJsonObjectFile(
      p.join(dataRootPath, 'session.json'),
      label: 'session.json',
    );
    final couponsRoot = await _readJsonObjectFile(
      p.join(dataRootPath, 'coupons_list.json'),
      label: 'coupons_list.json',
    );
    final rawCoupons = couponsRoot['coupons'];
    if (rawCoupons is! List) {
      throw const PublisherBackendException(
        'coupons_list.json must contain a "coupons" list.',
      );
    }
    final coupons = <Map<String, Object?>>[];
    for (final rawCoupon in rawCoupons) {
      if (rawCoupon is! Map) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must be a JSON object.',
        );
      }
      final coupon = rawCoupon.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final couponId = coupon['id']?.toString().trim();
      if (couponId == null || couponId.isEmpty) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must contain a non-empty "id".',
        );
      }
      coupons.add(coupon);
    }
    return _PublisherBackendAwsSeedData(
      home: home,
      session: session,
      coupons: coupons,
    );
  }

  Future<Map<String, Object?>> _readJsonObjectFile(
    String filePath, {
    required String label,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw PublisherBackendException(
        'AWS publisher backend sample data is missing: $label',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS publisher backend sample data must be a JSON object: $label',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, Object?>> _buildDynamoDbSeedItems(
    _PublisherBackendAwsSettings settings,
    _PublisherBackendAwsSeedData seedData,
  ) {
    final now = _clock().toUtc().toIso8601String();
    final appPk = _appPartitionKey(settings.miniProgramId);
    final items = <Map<String, Object?>>[
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'HOME#bootstrap',
        recordType: 'home',
        payload: seedData.home,
        updatedAtUtc: now,
      ),
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'SESSION#demo',
        recordType: 'session',
        payload: seedData.session,
        updatedAtUtc: now,
      ),
    ];
    for (var i = 0; i < seedData.coupons.length; i++) {
      final coupon = seedData.coupons[i];
      final couponId = coupon['id']!.toString();
      items.add(
        _dynamoDbSeedItem(
          pk: appPk,
          sk: 'COUPON#$couponId',
          recordType: 'coupon',
          payload: coupon,
          updatedAtUtc: now,
          extraAttributes: <String, Object?>{
            'couponId': couponId,
            'sortIndex': i,
          },
        ),
      );
    }
    return items;
  }

  Map<String, Object?> _dynamoDbSeedItem({
    required String pk,
    required String sk,
    required String recordType,
    required Map<String, Object?> payload,
    required String updatedAtUtc,
    Map<String, Object?> extraAttributes = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'pk': pk,
      'sk': sk,
      'recordType': recordType,
      'payload': payload,
      'updatedAtUtc': updatedAtUtc,
      ...extraAttributes,
    };
  }

  Future<_PublisherBackendAwsDataImportPlan> _readAwsDataImportPlan({
    required _PublisherBackendAwsSettings settings,
    required String inputPath,
    required bool includeRedemptions,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw PublisherBackendException(
        'AWS publisher backend data import file was not found: $inputPath',
      );
    }
    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS publisher backend data import file must be a JSON object: '
        '$inputPath',
      );
    }
    final export = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (export['schemaVersion'] != 1) {
      throw PublisherBackendException(
        'AWS publisher backend data import file has an unsupported schemaVersion.',
      );
    }
    final rawItems = export['items'];
    if (rawItems is! List) {
      throw PublisherBackendException(
        'AWS publisher backend data import file is missing an items array.',
      );
    }

    final appPk = _appPartitionKey(settings.miniProgramId);
    final redemptionsPk = _redemptionsPartitionKey(settings.miniProgramId);
    final items = <Map<String, Object?>>[];
    var appRecordCount = 0;
    var redemptionCount = 0;
    var skippedRedemptionCount = 0;
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw PublisherBackendException(
          'AWS publisher backend data import items must be JSON objects.',
        );
      }
      final item = rawItem.map((key, value) => MapEntry(key.toString(), value));
      final pk = item['pk']?.toString().trim() ?? '';
      final sk = item['sk']?.toString().trim() ?? '';
      if (pk.isEmpty || sk.isEmpty) {
        throw PublisherBackendException(
          'AWS publisher backend data import items must include pk and sk.',
        );
      }
      if (pk == redemptionsPk) {
        if (!includeRedemptions) {
          skippedRedemptionCount++;
          continue;
        }
        redemptionCount++;
      } else if (pk == appPk) {
        appRecordCount++;
      } else {
        throw PublisherBackendException(
          'AWS publisher backend data import item "$pk $sk" does not belong '
          'to mini-program "${settings.miniProgramId}".',
        );
      }
      items.add(item);
    }
    return _PublisherBackendAwsDataImportPlan(
      items: items,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      skippedRedemptionCount: skippedRedemptionCount,
    );
  }

  String _resolveAwsDataExportPath(
    _PublisherBackendAwsSettings settings,
    String? outputPath,
  ) {
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(outputPath.trim()));
    }
    final timestamp = _compactUtcTimestamp(_clock().toUtc());
    final fileName =
        '${_safeFileSegment(settings.miniProgramId)}-'
        '${_safeFileSegment(settings.environmentName)}-'
        'data-export-$timestamp.json';
    return p.normalize(
      p.absolute(p.join(settings.backendRootPath, 'exports', fileName)),
    );
  }

  String _compactUtcTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}'
        '${two(value.month)}'
        '${two(value.day)}'
        'T'
        '${two(value.hour)}'
        '${two(value.minute)}'
        '${two(value.second)}'
        'Z';
  }

  String _safeFileSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    return sanitized.isEmpty ? 'mini_program' : sanitized;
  }

  List<Map<String, Object?>> _sortedDynamoDbExportItems(
    List<Map<String, Object?>> items,
  ) {
    final sorted = items
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    sorted.sort((left, right) {
      final pkCompare = (left['pk']?.toString() ?? '').compareTo(
        right['pk']?.toString() ?? '',
      );
      if (pkCompare != 0) {
        return pkCompare;
      }
      return (left['sk']?.toString() ?? '').compareTo(
        right['sk']?.toString() ?? '',
      );
    });
    return sorted;
  }

  List<Map<String, Object?>> _filterRedemptionRecords(
    List<Map<String, Object?>> records, {
    String? couponId,
    String? userId,
  }) {
    final couponFilter = couponId?.trim();
    final userFilter = userId?.trim();
    final filtered = records
        .where((record) {
          if (couponFilter != null && couponFilter.isNotEmpty) {
            final recordCouponId = _redemptionRecordValue(record, 'couponId');
            if (recordCouponId != couponFilter) {
              return false;
            }
          }
          if (userFilter != null && userFilter.isNotEmpty) {
            final recordUserId = _redemptionRecordValue(record, 'userId');
            if (recordUserId != userFilter) {
              return false;
            }
          }
          return true;
        })
        .map((record) => Map<String, Object?>.from(record))
        .toList();
    filtered.sort((left, right) {
      final rightTime =
          _redemptionRecordValue(right, 'createdAtUtc') ??
          _redemptionRecordValue(right, 'redeemedAtUtc') ??
          '';
      final leftTime =
          _redemptionRecordValue(left, 'createdAtUtc') ??
          _redemptionRecordValue(left, 'redeemedAtUtc') ??
          '';
      return rightTime.compareTo(leftTime);
    });
    return filtered;
  }

  String? _redemptionRecordValue(Map<String, Object?> record, String key) {
    final direct = record[key]?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final payload = record['payload'];
    if (payload is Map) {
      final value = payload[key]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<void> _batchWriteDynamoDbItems({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required List<Map<String, Object?>> items,
  }) async {
    for (var index = 0; index < items.length; index += 25) {
      final chunk = items.skip(index).take(25).toList();
      var requestItems = <String, Object?>{
        tableName: chunk
            .map(
              (item) => <String, Object?>{
                'PutRequest': <String, Object?>{
                  'Item': item.map(
                    (key, value) =>
                        MapEntry(key, _toDynamoDbAttributeValue(value)),
                  ),
                },
              },
            )
            .toList(),
      };
      for (
        var attempt = 1;
        attempt <= _dynamoDbBatchWriteMaxAttempts;
        attempt++
      ) {
        final response = await _runAwsJsonCommand(settings, <String>[
          'dynamodb',
          'batch-write-item',
          '--request-items',
          jsonEncode(requestItems),
        ]);
        final unprocessed = _dynamoDbRequestItems(response['UnprocessedItems']);
        if (!_hasDynamoDbRequestItems(unprocessed)) {
          break;
        }
        if (attempt == _dynamoDbBatchWriteMaxAttempts) {
          throw PublisherBackendException(
            'DynamoDB seed left unprocessed items for table "$tableName" after '
            '$_dynamoDbBatchWriteMaxAttempts attempts.',
          );
        }
        requestItems = unprocessed;
        await _delay(Duration(milliseconds: 200 * (1 << (attempt - 1))));
      }
    }
  }

  Map<String, Object?> _dynamoDbRequestItems(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }
    return value.map((key, nestedValue) {
      return MapEntry(key.toString(), nestedValue);
    });
  }

  bool _hasDynamoDbRequestItems(Map<String, Object?> requestItems) {
    for (final value in requestItems.values) {
      if (value is List && value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _describeDynamoDbTable(
    _PublisherBackendAwsSettings settings,
    String tableName,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'dynamodb',
      'describe-table',
      '--table-name',
      tableName,
    ]);
    final table = response['Table'];
    if (table is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned no DynamoDB table details for "$tableName".',
      );
    }
    return table.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<int> _queryDynamoDbCount({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required String partitionKey,
  }) async {
    var total = 0;
    Map<String, Object?>? exclusiveStartKey;
    do {
      final arguments = <String>[
        'dynamodb',
        'query',
        '--table-name',
        tableName,
        '--key-condition-expression',
        'pk = :pk',
        '--expression-attribute-values',
        jsonEncode(<String, Object?>{
          ':pk': <String, Object?>{'S': partitionKey},
        }),
        '--select',
        'COUNT',
        '--consistent-read',
        if (exclusiveStartKey != null) ...<String>[
          '--exclusive-start-key',
          jsonEncode(exclusiveStartKey),
        ],
      ];
      final response = await _runAwsJsonCommand(settings, arguments);
      total += _dynamoDbCountValue(response['Count']);
      final lastEvaluatedKey = response['LastEvaluatedKey'];
      exclusiveStartKey = lastEvaluatedKey is Map && lastEvaluatedKey.isNotEmpty
          ? lastEvaluatedKey.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
    } while (exclusiveStartKey != null);
    return total;
  }

  Future<List<Map<String, Object?>>> _queryDynamoDbItems({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required String partitionKey,
  }) async {
    final items = <Map<String, Object?>>[];
    Map<String, Object?>? exclusiveStartKey;
    do {
      final arguments = <String>[
        'dynamodb',
        'query',
        '--table-name',
        tableName,
        '--key-condition-expression',
        'pk = :pk',
        '--expression-attribute-values',
        jsonEncode(<String, Object?>{
          ':pk': <String, Object?>{'S': partitionKey},
        }),
        '--consistent-read',
        if (exclusiveStartKey != null) ...<String>[
          '--exclusive-start-key',
          jsonEncode(exclusiveStartKey),
        ],
      ];
      final response = await _runAwsJsonCommand(settings, arguments);
      final rawItems = response['Items'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          items.add(_fromDynamoDbItem(rawItem));
        }
      }
      final lastEvaluatedKey = response['LastEvaluatedKey'];
      exclusiveStartKey = lastEvaluatedKey is Map && lastEvaluatedKey.isNotEmpty
          ? lastEvaluatedKey.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
    } while (exclusiveStartKey != null);
    return items;
  }

  int _dynamoDbCountValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, Object?> _fromDynamoDbItem(Object? rawItem) {
    if (rawItem is! Map) {
      throw const PublisherBackendException(
        'AWS CLI returned a non-object DynamoDB item.',
      );
    }
    return rawItem.map(
      (key, value) =>
          MapEntry(key.toString(), _fromDynamoDbAttributeValue(value)),
    );
  }

  Object? _fromDynamoDbAttributeValue(Object? value) {
    if (value is! Map) {
      return value;
    }
    if (value.containsKey('S')) {
      return value['S']?.toString();
    }
    if (value.containsKey('N')) {
      return _fromDynamoDbNumber(value['N']);
    }
    if (value.containsKey('BOOL')) {
      final raw = value['BOOL'];
      return raw is bool ? raw : raw?.toString() == 'true';
    }
    if (value.containsKey('NULL')) {
      return null;
    }
    if (value.containsKey('L')) {
      final raw = value['L'];
      if (raw is List) {
        return raw.map(_fromDynamoDbAttributeValue).toList();
      }
      return const <Object?>[];
    }
    if (value.containsKey('M')) {
      final raw = value['M'];
      if (raw is Map) {
        return raw.map(
          (key, nestedValue) => MapEntry(
            key.toString(),
            _fromDynamoDbAttributeValue(nestedValue),
          ),
        );
      }
      return const <String, Object?>{};
    }
    if (value.containsKey('SS')) {
      final raw = value['SS'];
      return raw is List
          ? raw.map((entry) => entry?.toString()).toList()
          : const <String>[];
    }
    if (value.containsKey('NS')) {
      final raw = value['NS'];
      return raw is List
          ? raw.map(_fromDynamoDbNumber).toList()
          : const <num>[];
    }
    return value.map(
      (key, nestedValue) =>
          MapEntry(key.toString(), _fromDynamoDbAttributeValue(nestedValue)),
    );
  }

  Object? _fromDynamoDbNumber(Object? value) {
    final raw = value?.toString();
    if (raw == null) {
      return null;
    }
    final integer = int.tryParse(raw);
    if (integer != null) {
      return integer;
    }
    return double.tryParse(raw) ?? raw;
  }

  Map<String, Object?> _toDynamoDbAttributeValue(Object? value) {
    if (value == null) {
      return const <String, Object?>{'NULL': true};
    }
    if (value is bool) {
      return <String, Object?>{'BOOL': value};
    }
    if (value is num) {
      return <String, Object?>{'N': value.toString()};
    }
    if (value is String) {
      return <String, Object?>{'S': value};
    }
    if (value is List) {
      return <String, Object?>{
        'L': value.map(_toDynamoDbAttributeValue).toList(),
      };
    }
    if (value is Map) {
      return <String, Object?>{
        'M': value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _toDynamoDbAttributeValue(nestedValue)),
        ),
      };
    }
    return <String, Object?>{'S': value.toString()};
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

  List<String> _awsGlobalArguments(_PublisherBackendAwsSettings settings) {
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
    throw PublisherBackendException(
      '$toolLabel command failed.\n'
      'Command: $executable ${arguments.join(' ')}\n'
      'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
      'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
    );
  }

  Future<bool> _isProcessAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await _shellRunner('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }
    final result = await _shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }
    return const LineSplitter().convert('${result.stdout}'.trim()).length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner('taskkill', <String>['/PID', '$pid', '/T', '/F']);
    }
    return _shellRunner('kill', <String>['$pid']);
  }

  Future<_PublisherBackendHealth> _probeHealth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      return _PublisherBackendHealth(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const _PublisherBackendHealth(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return _PublisherBackendHealth(healthy: false, error: '$error');
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeRoute({
    required String method,
    required String path,
    required Uri uri,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      final passed = response.statusCode == 200;
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        error: passed ? null : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeWriteRoute({
    required Uri uri,
    required String couponId,
    required String userId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const path = '/coupon/redeem';
    try {
      final response = await _postRequester(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'couponId': couponId,
          'userId': userId,
        }),
      ).timeout(timeout);
      final responseStatus = _responseStatus(response.body);
      final passed =
          response.statusCode == 200 &&
          (responseStatus == 'redeemed' ||
              responseStatus == 'already_redeemed');
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: responseStatus,
        error: passed
            ? null
            : response.statusCode == 200
            ? 'Write route returned 200 without redeemed status.'
            : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult> _probeFirebaseSmokeRoute({
    required String method,
    required String path,
    required Uri uri,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      final passed = response.statusCode == 200;
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        error: passed ? null : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  String? _responseStatus(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final status = decoded['status']?.toString().trim();
        return status == null || status.isEmpty ? null : status;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _resolveBackendRoute(Uri baseUri, String path) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBaseUrl).resolve(relativePath);
  }

  Future<_PublisherBackendHealth> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final deadline = _clock().add(timeout);
    _PublisherBackendHealth lastResult = const _PublisherBackendHealth(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );
    while (_clock().isBefore(deadline)) {
      lastResult = await _probeHealth(uri, timeout: attemptTimeout);
      if (lastResult.healthy) {
        return lastResult;
      }
      await _delay(retryDelay);
    }
    return lastResult;
  }

  Future<bool> _waitForBackendUnavailable(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      final result = await _probeHealth(
        uri,
        timeout: const Duration(milliseconds: 750),
      );
      if (!result.healthy) {
        return true;
      }
      await _delay(const Duration(milliseconds: 250));
    }
    final finalProbe = await _probeHealth(
      uri,
      timeout: const Duration(milliseconds: 750),
    );
    return !finalProbe.healthy;
  }

  Future<String> _readLogTail(String filePath, {int lineCount = 20}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }
    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return '';
    }
    return lines
        .skip(lines.length > lineCount ? lines.length - lineCount : 0)
        .join('\n');
  }

  String _quoteForCmd(String value) => '"${value.replaceAll('"', '""')}"';

  String _quoteForSh(String value) => "'${value.replaceAll("'", r"'\''")}'";

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
  }

  static Future<StartedPublisherBackendProcess> _defaultProcessStarter({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
    return StartedPublisherBackendProcess(pid: process.pid);
  }

  static Future<http.Response> _defaultPostRequester(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(uri, headers: headers, body: body);
  }

  static DateTime _defaultClock() => DateTime.now();

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}

class _PublisherBackendHealth {
  const _PublisherBackendHealth({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}

class _PublisherBackendAwsSeedData {
  const _PublisherBackendAwsSeedData({
    required this.home,
    required this.session,
    required this.coupons,
  });

  final Map<String, Object?> home;
  final Map<String, Object?> session;
  final List<Map<String, Object?>> coupons;
}

class _PublisherBackendAwsDataImportPlan {
  const _PublisherBackendAwsDataImportPlan({
    required this.items,
    required this.appRecordCount,
    required this.redemptionCount,
    required this.skippedRedemptionCount,
  });

  final List<Map<String, Object?>> items;
  final int appRecordCount;
  final int redemptionCount;
  final int skippedRedemptionCount;
}

class _PublisherBackendAwsSettings {
  const _PublisherBackendAwsSettings({
    required this.environmentName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    this.awsProfile,
  });

  final String environmentName;
  final String miniProgramId;
  final String backendRootPath;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final String? awsProfile;

  static _PublisherBackendAwsSettings fromEnvironment({
    required CloudEnvironmentConfiguration environment,
    required String miniProgramRootPath,
    String? stackNameOverride,
    String? stageNameOverride,
    String? samS3BucketOverride,
  }) {
    if (environment.provider != 'aws') {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw PublisherBackendException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String? explicit, String key, String fallback) {
      if (explicit != null && explicit.trim().isNotEmpty) {
        return explicit.trim();
      }
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
    final region = requiredValue('region');
    final bucket = requiredValue('bucket');
    final stageName = optionalValue(stageNameOverride, 'stageName', 'prod');
    final samS3Bucket = optionalValue(
      samS3BucketOverride,
      'samS3Bucket',
      bucket,
    );
    final stackName = stackNameOverride?.trim().isNotEmpty == true
        ? stackNameOverride!.trim()
        : _defaultAwsPublisherBackendStackName(appId, environment.name);
    final awsProfile =
        environment.values['awsProfile']?.toString().trim().isEmpty == true
        ? null
        : environment.values['awsProfile']?.toString().trim();

    return _PublisherBackendAwsSettings(
      environmentName: environment.name,
      miniProgramId: appId,
      backendRootPath: p.join(miniProgramRootPath, 'backend', 'aws_lambda'),
      stackName: stackName,
      stageName: stageName,
      region: region,
      samS3Bucket: samS3Bucket,
      awsProfile: awsProfile,
    );
  }
}

class _PublisherBackendFirebaseSettings {
  const _PublisherBackendFirebaseSettings({
    required this.environmentName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.functionsRootPath,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.functionUrl,
  });

  final String environmentName;
  final String miniProgramId;
  final String backendRootPath;
  final String functionsRootPath;
  final String projectId;
  final String region;
  final String functionName;
  final String functionUrl;

  String get healthUrl => _firebaseHealthUrlFromFunctionUrl(functionUrl);

  Map<String, String> get outputs => <String, String>{
    'PublisherBackendBaseUrl': functionUrl,
    'PublisherBackendHealthUrl': healthUrl,
    'PublisherBackendFunctionName': functionName,
    'PublisherBackendProjectId': projectId,
    'PublisherBackendRegion': region,
    'PublisherBackendStorageMode': _publisherBackendStorageFirestore,
  };

  static _PublisherBackendFirebaseSettings fromEnvironment({
    required CloudEnvironmentConfiguration environment,
    required String miniProgramRootPath,
  }) {
    if (environment.provider != 'firebase') {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" is not a firebase environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw PublisherBackendException(
          'Cloud environment "${environment.name}" is missing required '
          'firebase setting "$key". Run `miniprogram env configure '
          '${environment.name} --provider firebase ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String key, String fallback) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
    final projectId = requiredValue('projectId');
    final region = optionalValue('region', 'us-central1');
    final functionName = optionalValue('functionName', 'publisherBackend');
    final configuredFunctionUrl =
        environment.values['functionUrl']?.toString().trim() ?? '';
    final functionUrl = configuredFunctionUrl.isEmpty
        ? _defaultFirebaseFunctionUrl(
            projectId: projectId,
            region: region,
            functionName: functionName,
          )
        : _normalizeFirebaseFunctionUrl(configuredFunctionUrl);
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      'firebase_functions',
    );

    return _PublisherBackendFirebaseSettings(
      environmentName: environment.name,
      miniProgramId: appId,
      backendRootPath: backendRootPath,
      functionsRootPath: p.join(backendRootPath, 'functions'),
      projectId: projectId,
      region: region,
      functionName: functionName,
      functionUrl: functionUrl,
    );
  }
}

String _defaultFirebaseFunctionUrl({
  required String projectId,
  required String region,
  required String functionName,
}) {
  return _normalizeFirebaseFunctionUrl(
    'https://$region-$projectId.cloudfunctions.net/$functionName',
  );
}

String _normalizeFirebaseFunctionUrl(String rawUrl) {
  final uri = Uri.parse(rawUrl.trim());
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw PublisherBackendException(
      'Firebase function URL must be an absolute HTTPS URL: $rawUrl',
    );
  }
  if (uri.scheme != 'https') {
    throw PublisherBackendException(
      'Firebase function URL must use https: $rawUrl',
    );
  }
  final withoutTrailingSlash = uri.toString().replaceFirst(RegExp(r'/+$'), '');
  return '$withoutTrailingSlash/';
}

String _firebaseHealthUrlFromFunctionUrl(String functionUrl) {
  final base = Uri.parse(_normalizeFirebaseFunctionUrl(functionUrl));
  return base.resolve('health').toString();
}

Map<String, String> buildAwsLambdaPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
  String storageMode = 'bundled',
}) {
  if (!const <String>[
    _publisherBackendStorageBundled,
    _publisherBackendStorageDynamoDb,
  ].contains(storageMode)) {
    throw PublisherBackendException(
      'Unsupported AWS Lambda publisher backend storage mode: $storageMode',
    );
  }
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'template.yaml': _awsLambdaTemplateYaml(
      displayTitle,
      appId: appId,
      storageMode: storageMode,
    ),
    'README.md': _awsLambdaReadme(appId, displayTitle, storageMode),
    p.join('src', 'package.json'): _awsLambdaPackageJson(appId, storageMode),
    p.join('src', 'handler.mjs'): _awsLambdaHandlerSource(),
    p.join('src', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('src', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('src', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildFirebaseFunctionsPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'firebase.json': _firebaseJson(),
    '.firebaserc.example': _firebaseRcExample(),
    'README.md': _firebaseFunctionsReadme(appId, displayTitle),
    p.join('functions', 'package.json'): _firebaseFunctionsPackageJson(appId),
    p.join('functions', 'index.js'): _firebaseFunctionsIndexSource(appId),
    p.join('functions', 'router.js'): _firebaseFunctionsRouterSource(),
    p.join('functions', 'firestore_store.js'):
        _firebaseFunctionsFirestoreStoreSource(),
    p.join('functions', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('functions', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('functions', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildMockPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  return <String, String>{
    'pubspec.yaml': _mockBackendPubspec(appId),
    'README.md': _mockBackendReadme(appId, displayTitle),
    p.join('bin', 'server.dart'): _mockBackendServerSource(),
    p.join('data', 'home_bootstrap.json'): _prettyJson(<String, Object?>{
      'title': '$displayTitle backend starter',
      'subtitle': 'Loaded from the publisher-owned mock backend.',
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'tier': 'Gold',
      },
      'heroImageUrl': 'https://picsum.photos/seed/${appId}_hero/960/480',
    }),
    p.join('data', 'coupons_list.json'): _prettyJson(<String, Object?>{
      'coupons': <Object?>[
        <String, Object?>{
          'id': 'coupon-10',
          'title': '10% starter coupon',
          'description': 'Backend-driven coupon item from mock data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_10/320/200',
        },
        <String, Object?>{
          'id': 'coupon-20',
          'title': '20% weekend reward',
          'description':
              'Replace this JSON with Firebase, AWS, or custom API data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_20/320/200',
        },
      ],
    }),
    p.join('data', 'session.json'): _prettyJson(<String, Object?>{
      'authenticated': true,
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'email': 'preview@example.com',
      },
      'note': 'Mock auth only. Real auth belongs on publisher servers.',
    }),
  };
}

String _firebaseJson() => _prettyJson(<String, Object?>{
  'functions': <String, Object?>{'source': 'functions'},
  'emulators': <String, Object?>{
    'functions': <String, Object?>{'port': 5001},
    'firestore': <String, Object?>{'port': 8080},
    'ui': <String, Object?>{'enabled': true},
  },
});

String _firebaseRcExample() => _prettyJson(<String, Object?>{
  'projects': <String, Object?>{'default': 'your-firebase-project-id'},
});

String _firebaseFunctionsPackageJson(
  String appId,
) => _prettyJson(<String, Object?>{
  'name': '${_safeNodePackageSegment(appId)}-firebase-backend',
  'private': true,
  'type': 'module',
  'main': 'index.js',
  'engines': <String, Object?>{'node': '22'},
  'scripts': <String, Object?>{
    'serve':
        'firebase emulators:start --config ../firebase.json --only functions,firestore',
    'shell': 'firebase functions:shell --config ../firebase.json',
    'deploy': 'firebase deploy --config ../firebase.json --only functions',
    'logs': 'firebase functions:log',
  },
  'dependencies': <String, Object?>{
    'firebase-admin': _firebaseAdminVersion,
    'firebase-functions': _firebaseFunctionsVersion,
  },
});

String _firebaseFunctionsReadme(String appId, String title) =>
    '''
# $title Firebase publisher backend

This is a Firebase Cloud Functions v2 + Firestore publisher backend for
mini-program business data. It is separate from mini-program delivery and keeps
Firebase Admin SDK credentials on publisher-owned infrastructure.

Storage mode: Firestore

Generated routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Firestore data model:

- `miniPrograms/$appId/home/bootstrap`
- `miniPrograms/$appId/sessions/demo`
- `miniPrograms/$appId/coupons/<couponId>`
- `miniPrograms/$appId/redemptions/<safeUserId_safeCouponId>`

Setup from the mini-program root:

```powershell
cd ../..
miniprogram env init
miniprogram env configure my-firebase-prod `
  --provider firebase `
  --project-id your-firebase-project-id `
  --region us-central1

miniprogram publisher-backend firebase deploy `
  --env my-firebase-prod
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod
```

Local emulator:

```powershell
cd functions
npm install
npm run serve
```

After deploy, connect host apps with the HTTPS function URL as
`--backend-base-url`. The host app does not need Firebase SDKs unless the host
itself chooses to use Firebase features such as Firebase Auth.

Firebase Auth is intentionally not included in this scaffold. `/auth/session`
returns publisher-owned session data from Firestore; a later auth bridge can
verify Firebase ID tokens on the server.
''';

String _firebaseFunctionsIndexSource(String appId) =>
    '''
import { onRequest } from 'firebase-functions/v2/https';
import { getApps, initializeApp } from 'firebase-admin/app';
import { createPublisherBackendHandler } from './router.js';
import { createFirestorePublisherBackendStore } from './firestore_store.js';

if (getApps().length === 0) {
  initializeApp();
}

const appId = process.env.MINI_PROGRAM_ID || '$appId';
const store = createFirestorePublisherBackendStore({ appId });
const publisherBackendHandler = createPublisherBackendHandler({ store });

export const publisherBackend = onRequest(
  {
    region: process.env.FUNCTION_REGION || 'us-central1',
  },
  publisherBackendHandler,
);
''';

String _firebaseFunctionsRouterSource() => r'''
export const expectedRoutes = [
  'GET /health',
  'GET /home/bootstrap',
  'GET /coupons/list',
  'GET /auth/session',
  'POST /coupon/redeem',
];

export function createPublisherBackendHandler({
  store,
  clock = () => new Date(),
} = {}) {
  if (!store) {
    throw new Error('createPublisherBackendHandler requires a store.');
  }

  return async function publisherBackendHandler(request, response) {
    writeCorsHeaders(response);
    if (request.method === 'OPTIONS') {
      return endEmpty(response, 204);
    }

    const method = String(request.method || 'GET').toUpperCase();
    const routePath = normalizePath(
      request.path || request.url || request.originalUrl || '/',
    );

    try {
      if (method === 'GET' && routePath === '/health') {
        return writeJson(response, 200, {
          status: 'ok',
          service: 'mini_program_firebase_publisher_backend',
          generatedAtUtc: clock().toISOString(),
        });
      }
      if (method === 'GET' && routePath === '/home/bootstrap') {
        const body = await store.homeBootstrap();
        return body
          ? writeJson(response, 200, body)
          : writeJson(response, 404, {
              errorCode: 'home_bootstrap_missing',
              message: 'Home bootstrap document was not found.',
            });
      }
      if (method === 'GET' && routePath === '/coupons/list') {
        return writeJson(response, 200, await store.couponsList());
      }
      if (method === 'GET' && routePath === '/auth/session') {
        const body = await store.authSession();
        return body
          ? writeJson(response, 200, body)
          : writeJson(response, 404, {
              errorCode: 'session_missing',
              message: 'Session document was not found.',
            });
      }
      if (method === 'POST' && routePath === '/coupon/redeem') {
        const body = await readJsonBody(request);
        const couponId = stringValue(body?.couponId);
        if (!couponId) {
          return writeJson(response, 400, {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          });
        }
        const userId = stringValue(body?.userId) || 'preview-user';
        const result = await store.redeemCoupon({
          couponId,
          userId,
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }

      return writeJson(response, 404, {
        errorCode: 'not_found',
        message: 'No publisher backend route matches ' + method + ' ' + routePath + '.',
      });
    } catch (error) {
      return writeJson(response, 500, {
        errorCode: 'publisher_backend_error',
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

function normalizePath(value) {
  let path = String(value || '/');
  if (path.startsWith('http://') || path.startsWith('https://')) {
    path = new URL(path).pathname;
  }
  path = path.split('?')[0].replace(/\/+$/g, '');
  return path || '/';
}

async function readJsonBody(request) {
  if (request.body && typeof request.body === 'object') {
    return request.body;
  }
  if (typeof request.body === 'string') {
    return request.body.trim() ? JSON.parse(request.body) : {};
  }
  if (request[Symbol.asyncIterator]) {
    const chunks = [];
    for await (const chunk of request) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const text = Buffer.concat(chunks).toString('utf8');
    return text.trim() ? JSON.parse(text) : {};
  }
  return {};
}

function writeCorsHeaders(response) {
  response.setHeader?.('access-control-allow-origin', '*');
  response.setHeader?.('access-control-allow-methods', 'GET, POST, OPTIONS');
  response.setHeader?.(
    'access-control-allow-headers',
    [
      'content-type',
      'x-mini-program-access-key',
      'x-mini-program-app-id',
      'x-mini-program-host-app',
      'x-mini-program-host-version',
      'x-mini-program-id',
      'x-mini-program-sdk-version',
      'x-mini-program-platform',
      'x-mini-program-locale',
    ].join(', '),
  );
}

function writeJson(response, statusCode, body) {
  if (typeof response.status === 'function') {
    response.status(statusCode);
  } else {
    response.statusCode = statusCode;
  }
  response.setHeader?.('content-type', 'application/json; charset=utf-8');
  if (typeof response.json === 'function') {
    response.json(body);
  } else {
    response.end(JSON.stringify(body, null, 2));
  }
}

function endEmpty(response, statusCode) {
  if (typeof response.status === 'function') {
    response.status(statusCode);
  } else {
    response.statusCode = statusCode;
  }
  response.end();
}

function stringValue(value) {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value).trim();
}
''';

String _firebaseFunctionsFirestoreStoreSource() => r'''
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

export function createFirestorePublisherBackendStore({
  appId,
  db = getFirestore(),
} = {}) {
  if (!appId) {
    throw new Error('createFirestorePublisherBackendStore requires appId.');
  }
  const appRef = db.collection('miniPrograms').doc(appId);

  return {
    async homeBootstrap() {
      return readDocument(appRef.collection('home').doc('bootstrap'));
    },

    async couponsList() {
      const snapshot = await appRef.collection('coupons').get();
      const coupons = snapshot.docs
        .map((document) => ({
          id: document.id,
          ...document.data(),
        }))
        .sort(compareCoupons);
      return { coupons };
    },

    async authSession() {
      return readDocument(appRef.collection('sessions').doc('demo'));
    },

    async redeemCoupon({ couponId, userId, requestedAtUtc }) {
      const couponRef = appRef.collection('coupons').doc(couponId);
      const redemptionRef = appRef
        .collection('redemptions')
        .doc(safeDocumentId(userId) + '_' + safeDocumentId(couponId));

      return db.runTransaction(async (transaction) => {
        const couponSnapshot = await transaction.get(couponRef);
        if (!couponSnapshot.exists) {
          return {
            statusCode: 404,
            body: {
              errorCode: 'coupon_not_found',
              message: 'Coupon was not found.',
              couponId,
            },
          };
        }

        const redemptionSnapshot = await transaction.get(redemptionRef);
        if (redemptionSnapshot.exists) {
          return {
            statusCode: 200,
            body: {
              status: 'already_redeemed',
              couponId,
              userId,
              redemption: redemptionSnapshot.data(),
            },
          };
        }

        const redemption = {
          status: 'redeemed',
          couponId,
          userId,
          redeemedAtUtc: requestedAtUtc,
          createdAt: FieldValue.serverTimestamp(),
        };
        transaction.set(redemptionRef, redemption);
        return {
          statusCode: 200,
          body: {
            status: 'redeemed',
            couponId,
            userId,
            redemption: {
              ...redemption,
              createdAt: null,
            },
          },
        };
      });
    },
  };
}

async function readDocument(reference) {
  const snapshot = await reference.get();
  return snapshot.exists ? snapshot.data() : null;
}

function compareCoupons(left, right) {
  const leftSort = Number.isFinite(Number(left.sortIndex))
    ? Number(left.sortIndex)
    : Number.MAX_SAFE_INTEGER;
  const rightSort = Number.isFinite(Number(right.sortIndex))
    ? Number(right.sortIndex)
    : Number.MAX_SAFE_INTEGER;
  if (leftSort !== rightSort) {
    return leftSort - rightSort;
  }
  return String(left.title || left.id).localeCompare(String(right.title || right.id));
}

function safeDocumentId(value) {
  return String(value || 'unknown')
    .trim()
    .replace(/[^A-Za-z0-9_.-]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'unknown';
}
''';

String _mockBackendPubspec(String appId) =>
    '''
name: ${appId}_mock_backend
description: Local mock publisher backend for $appId.
publish_to: none

environment:
  sdk: '>=3.9.0 <4.0.0'
''';

String _mockBackendReadme(String appId, String title) =>
    '''
# $title mock publisher backend

This is a local-only mock backend for mini-program data calls. It is not the
mini-program delivery backend and it does not contain production secrets.

Run it from the mini-program root:

```powershell
miniprogram publisher-backend run --port 9090
```

Useful base URLs:

- desktop/web host: `http://127.0.0.1:9090/`
- Android emulator host: `http://10.0.2.2:9090/`

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url http://127.0.0.1:9090/
```

Production Firebase, AWS, GCP, or custom server SDKs should live on your
publisher backend server, not in the Flutter host app or mini_program_sdk.
''';

String _mockBackendServerSource() => r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final host = _option(arguments, 'host') ?? '0.0.0.0';
  final port = int.tryParse(_option(arguments, 'port') ?? '9090') ?? 9090;
  final dataRoot = Directory(
    _option(arguments, 'data-root') ??
        '${File.fromUri(Platform.script).parent.parent.path}${Platform.pathSeparator}data',
  );
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Mock publisher backend listening on http://$host:$port');
  stdout.writeln('Data root: ${dataRoot.path}');
  await for (final request in server) {
    await _handleRequest(request, dataRoot);
  }
}

Future<void> _handleRequest(HttpRequest request, Directory dataRoot) async {
  _writeCorsHeaders(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  final path = request.uri.path.replaceAll(RegExp(r'/+$'), '');
  if (request.method == 'GET' && path == '/health') {
    await _writeJson(request.response, <String, Object?>{
      'status': 'ok',
      'service': 'mini_program_mock_publisher_backend',
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }
  if (request.method == 'GET' && path == '/home/bootstrap') {
    await _writeDataFile(request.response, dataRoot, 'home_bootstrap.json');
    return;
  }
  if (request.method == 'GET' && path == '/coupons/list') {
    await _writeDataFile(request.response, dataRoot, 'coupons_list.json');
    return;
  }
  if (request.method == 'GET' && path == '/auth/session') {
    await _writeDataFile(request.response, dataRoot, 'session.json');
    return;
  }
  if (request.method == 'POST' && path == '/coupon/redeem') {
    final body = await utf8.decoder.bind(request).join();
    final decoded = body.trim().isEmpty ? <String, Object?>{} : jsonDecode(body);
    await _writeJson(request.response, <String, Object?>{
      'status': 'redeemed',
      'couponId': decoded is Map ? decoded['couponId']?.toString() : null,
      'message': 'Mock redeem succeeded. Replace this route on your real backend.',
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await _writeJson(request.response, <String, Object?>{
    'errorCode': 'not_found',
    'message': 'No mock backend route matches ${request.uri.path}.',
  });
}

Future<void> _writeDataFile(
  HttpResponse response,
  Directory dataRoot,
  String fileName,
) async {
  final file = File('${dataRoot.path}${Platform.pathSeparator}$fileName');
  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, <String, Object?>{
      'errorCode': 'mock_data_missing',
      'message': 'Mock data file was not found: $fileName',
    });
    return;
  }
  response.headers.contentType = ContentType.json;
  await response.addStream(file.openRead());
  await response.close();
}

Future<void> _writeJson(HttpResponse response, Object? body) async {
  response.headers.contentType = ContentType.json;
  response.write(const JsonEncoder.withIndent('  ').convert(body));
  await response.close();
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers.set('access-control-allow-origin', '*');
  response.headers.set(
    'access-control-allow-methods',
    'GET, POST, OPTIONS',
  );
  response.headers.set(
    'access-control-allow-headers',
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  );
}

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (var i = 0; i < arguments.length; i++) {
    final value = arguments[i];
    if (value.startsWith(prefix)) {
      return value.substring(prefix.length);
    }
    if (value == '--$name' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  return null;
}
''';

String _awsLambdaTemplateYaml(
  String title, {
  required String appId,
  required String storageMode,
}) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final dataTableResource = usesDynamoDb
      ? '''
  PublisherBackendDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE

'''
      : '';
  final functionEnvironment =
      '''
      Environment:
        Variables:
          PUBLISHER_BACKEND_STORAGE: $storageMode
          MINI_PROGRAM_ID: $appId
${usesDynamoDb ? '          PUBLISHER_BACKEND_TABLE_NAME: !Ref PublisherBackendDataTable\n' : ''}''';
  final functionPolicies = usesDynamoDb
      ? '''
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref PublisherBackendDataTable
'''
      : '';
  final dataTableOutput = usesDynamoDb
      ? '''
  PublisherBackendDataTableName:
    Description: DynamoDB table used by the publisher backend.
    Value: !Ref PublisherBackendDataTable
'''
      : '';
  return '''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Publisher-owned business API backend for $title.

Parameters:
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.

Globals:
  Function:
    Runtime: nodejs24.x
    Timeout: 8
    MemorySize: 256
    Architectures:
      - arm64

Resources:
  PublisherBackendHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName
      CorsConfiguration:
        AllowOrigins:
          - '*'
        AllowMethods:
          - GET
          - POST
          - OPTIONS
        AllowHeaders:
          - content-type
          - x-mini-program-access-key
          - x-mini-program-app-id
          - x-mini-program-host-app
          - x-mini-program-host-version
          - x-mini-program-id
          - x-mini-program-sdk-version
          - x-mini-program-platform
          - x-mini-program-locale

$dataTableResource  PublisherBackendFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Description: Publisher-owned mini-program business API.
$functionEnvironment$functionPolicies      Events:
        ProxyApi:
          Type: HttpApi
          Properties:
            ApiId: !Ref PublisherBackendHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  PublisherBackendBaseUrl:
    Description: Base URL for MiniProgramBackendEndpoint.baseUri.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/'
  PublisherBackendHealthUrl:
    Description: Publisher backend health URL.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/health'
  PublisherBackendFunctionName:
    Description: Publisher backend Lambda function name.
    Value: !Ref PublisherBackendFunction
  PublisherBackendStackName:
    Description: Publisher backend CloudFormation stack name.
    Value: !Ref AWS::StackName
  PublisherBackendStorageMode:
    Description: Publisher backend storage mode.
    Value: $storageMode
$dataTableOutput''';
}

String _awsLambdaReadme(String appId, String title, String storageMode) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final storageSection = usesDynamoDb
      ? '''
Storage mode: DynamoDB.

After deploying the stack, seed the starter data into DynamoDB:

```powershell
miniprogram publisher-backend aws seed --env <env-name>
miniprogram publisher-backend aws data status --env <env-name>
miniprogram publisher-backend aws data export --env <env-name> --include-redemptions
miniprogram publisher-backend aws data import --env <env-name> --input <export-file> --dry-run --include-redemptions
miniprogram publisher-backend aws data redemptions --env <env-name> --coupon-id coupon-10
miniprogram publisher-backend aws smoke --env <env-name> --include-write
```

The DynamoDB table is owned by this SAM stack. `aws destroy --yes` checks for
stack-owned DynamoDB data and requires `--confirm-data-loss` when app records or
redemptions exist. Seed retries unprocessed DynamoDB batch writes; data status
counts paginated app and redemption records. Export production data before stack
cleanup or migration.
'''
      : '''
Storage mode: bundled JSON.

The sample Lambda returns bundled JSON from `src/data/`. To create a persistent
DynamoDB starter instead, re-run scaffold with:

```powershell
miniprogram publisher-backend scaffold --template aws-lambda --storage dynamodb
```
''';
  return '''
# $title AWS Lambda publisher backend

This backend is for publisher-owned business APIs. It is not the mini-program
delivery backend. Host apps only receive the resulting `backendBaseUrl`; AWS
secrets and future database credentials stay on the publisher server.

$storageSection

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`
- `OPTIONS *`

Deploy from the mini-program root:

```powershell
miniprogram publisher-backend aws deploy --env <env-name>
```

Deploy waits for the health endpoint with cold-start-aware retries. The default
smoke command is read-only; add `--include-write` only when you want to verify
`POST /coupon/redeem`.

After deploy, connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url <PublisherBackendBaseUrl>
```

Do not put publisher backend secrets in mini-program JSON, host source, APK,
IPA, or web JavaScript.
''';
}

String _awsLambdaPackageJson(String appId, String storageMode) {
  final dependencies = storageMode == _publisherBackendStorageDynamoDb
      ? ''',
  "dependencies": {
    "@aws-sdk/client-dynamodb": "$_awsSdkJavaScriptV3Version",
    "@aws-sdk/lib-dynamodb": "$_awsSdkJavaScriptV3Version"
  }'''
      : '';
  return '''
{
  "name": "${appId}_aws_publisher_backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda publisher backend starter for $appId"$dependencies
}
''';
}

String _awsLambdaHandlerSource() => r'''
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));
const dataRoot = join(currentDir, 'data');
const storageMode = process.env.PUBLISHER_BACKEND_STORAGE ?? 'bundled';
const miniProgramId = process.env.MINI_PROGRAM_ID ?? 'mini_program';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers':
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  'content-type': 'application/json; charset=utf-8',
};

let testStore = null;
let cachedStore = null;

export function setPublisherBackendStoreForTesting(store) {
  testStore = store;
  cachedStore = null;
}

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? event.httpMethod ?? 'GET';
  const path = normalizePath(
    event.rawPath ?? event.path ?? '/',
    event.requestContext?.stage,
  );

  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: corsHeaders,
      body: '',
    };
  }

  const store = await resolveStore();

  if (method === 'GET' && path === '/health') {
    return json(200, {
      status: 'ok',
      service: 'mini_program_aws_publisher_backend',
      storageMode,
      generatedAtUtc: new Date().toISOString(),
    });
  }

  if (method === 'GET' && path === '/home/bootstrap') {
    return jsonFromStore(await store.homeBootstrap(), 'home/bootstrap');
  }

  if (method === 'GET' && path === '/coupons/list') {
    return jsonFromStore(await store.couponsList(), 'coupons/list');
  }

  if (method === 'GET' && path === '/auth/session') {
    return jsonFromStore(await store.authSession(), 'auth/session');
  }

  if (method === 'POST' && path === '/coupon/redeem') {
    const body = parseJsonBody(event.body, event.isBase64Encoded);
    const result = await store.redeemCoupon(body);
    return json(result.statusCode, result.body);
  }

  return json(404, {
    errorCode: 'not_found',
    message: `No publisher backend route matches ${path}.`,
  });
}

async function resolveStore() {
  if (testStore) {
    return testStore;
  }
  if (cachedStore) {
    return cachedStore;
  }
  cachedStore =
    storageMode === 'dynamodb'
      ? await createDynamoDbStore()
      : new BundledJsonStore(dataRoot);
  return cachedStore;
}

function jsonFromStore(body, label) {
  if (body == null) {
    return json(404, {
      errorCode: 'backend_data_missing',
      message: `Backend data was not found: ${label}`,
    });
  }
  return json(200, body);
}

class BundledJsonStore {
  constructor(root) {
    this.root = root;
  }

  homeBootstrap() {
    return this.dataFile('home_bootstrap.json');
  }

  couponsList() {
    return this.dataFile('coupons_list.json');
  }

  authSession() {
    return this.dataFile('session.json');
  }

  async redeemCoupon(body) {
    return {
      statusCode: body?.couponId ? 200 : 400,
      body: body?.couponId
        ? {
            status: 'redeemed',
            couponId: body.couponId,
            message:
              'AWS sample redeem succeeded. Use --storage dynamodb for persistent redemptions.',
          }
        : {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          },
    };
  }

  async dataFile(fileName) {
    try {
      const raw = await readFile(join(this.root, fileName), 'utf8');
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  }
}

async function createDynamoDbStore() {
  const tableName = process.env.PUBLISHER_BACKEND_TABLE_NAME;
  if (!tableName) {
    throw new Error('PUBLISHER_BACKEND_TABLE_NAME is required for DynamoDB storage.');
  }
  const [{ DynamoDBClient }, dynamodbLib] = await Promise.all([
    import('@aws-sdk/client-dynamodb'),
    import('@aws-sdk/lib-dynamodb'),
  ]);
  const docClient = dynamodbLib.DynamoDBDocumentClient.from(
    new DynamoDBClient({}),
  );
  return new DynamoDbStore({
    docClient,
    tableName,
    appId: miniProgramId,
    commands: dynamodbLib,
  });
}

class DynamoDbStore {
  constructor({ docClient, tableName, appId, commands }) {
    this.docClient = docClient;
    this.tableName = tableName;
    this.appPk = `APP#${appId}`;
    this.redemptionsPk = `APP#${appId}#REDEMPTIONS`;
    this.GetCommand = commands.GetCommand;
    this.PutCommand = commands.PutCommand;
    this.QueryCommand = commands.QueryCommand;
  }

  homeBootstrap() {
    return this.payloadFor('HOME#bootstrap');
  }

  async couponsList() {
    const items = [];
    let exclusiveStartKey;
    do {
      const response = await this.docClient.send(
        new this.QueryCommand({
          TableName: this.tableName,
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
          ExpressionAttributeValues: {
            ':pk': this.appPk,
            ':prefix': 'COUPON#',
          },
          ConsistentRead: true,
          ExclusiveStartKey: exclusiveStartKey,
        }),
      );
      items.push(...(response.Items ?? []));
      exclusiveStartKey = response.LastEvaluatedKey;
    } while (exclusiveStartKey);
    const coupons = items
      .sort((left, right) => (left.sortIndex ?? 0) - (right.sortIndex ?? 0))
      .map((item) => item.payload)
      .filter((item) => item != null);
    return { coupons };
  }

  authSession() {
    return this.payloadFor('SESSION#demo');
  }

  async redeemCoupon(body) {
    const couponId = body?.couponId?.toString()?.trim();
    if (!couponId) {
      return {
        statusCode: 400,
        body: {
          errorCode: 'missing_coupon_id',
          message: 'couponId is required.',
        },
      };
    }

    const coupon = await this.payloadFor(`COUPON#${couponId}`);
    if (coupon == null) {
      return {
        statusCode: 404,
        body: {
          errorCode: 'coupon_not_found',
          couponId,
          message: `Coupon was not found: ${couponId}`,
        },
      };
    }

    const userId =
      body?.userId?.toString()?.trim() ||
      body?.user?.id?.toString()?.trim() ||
      'anonymous';
    const redeemedAtUtc = new Date().toISOString();
    const redemption = {
      status: 'redeemed',
      couponId,
      userId,
      redeemedAtUtc,
    };

    try {
      await this.docClient.send(
        new this.PutCommand({
          TableName: this.tableName,
          Item: {
            pk: this.redemptionsPk,
            sk: `USER#${userId}#COUPON#${couponId}`,
            recordType: 'redemption',
            couponId,
            userId,
            payload: redemption,
            createdAtUtc: redeemedAtUtc,
          },
          ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
        }),
      );
      return {
        statusCode: 200,
        body: {
          ...redemption,
          message: 'Coupon redeemed.',
        },
      };
    } catch (error) {
      if (error?.name === 'ConditionalCheckFailedException') {
        return {
          statusCode: 200,
          body: {
            status: 'already_redeemed',
            couponId,
            userId,
            message: 'Coupon was already redeemed for this user.',
          },
        };
      }
      throw error;
    }
  }

  async payloadFor(sk) {
    const response = await this.docClient.send(
      new this.GetCommand({
        TableName: this.tableName,
        Key: {
          pk: this.appPk,
          sk,
        },
        ConsistentRead: true,
      }),
    );
    return response.Item?.payload ?? null;
  }
}

function parseJsonBody(rawBody, isBase64Encoded) {
  if (!rawBody) {
    return {};
  }
  const decoded = isBase64Encoded
    ? Buffer.from(rawBody, 'base64').toString('utf8')
    : rawBody;
  try {
    return JSON.parse(decoded);
  } catch (_) {
    return {};
  }
}

function normalizePath(rawPath, stage) {
  let value = rawPath.replace(/\/+$/g, '');
  if (stage && stage !== '$default') {
    const stagePrefix = `/${stage}`;
    if (value === stagePrefix) {
      value = '/';
    } else if (value.startsWith(`${stagePrefix}/`)) {
      value = value.substring(stagePrefix.length);
    }
  }
  return value.length === 0 ? '/' : value;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body, null, 2),
  };
}
''';

String _defaultAwsPublisherBackendStackName(
  String appId,
  String environmentName,
) {
  final safeAppId = _safeAwsSegment(appId);
  final safeEnv = _safeAwsSegment(environmentName);
  return 'mini-program-publisher-backend-$safeAppId-$safeEnv';
}

String _appPartitionKey(String appId) => 'APP#$appId';

String _redemptionsPartitionKey(String appId) => 'APP#$appId#REDEMPTIONS';

String _safeAwsSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'default' : normalized;
}

String _safeNodePackageSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return normalized.isEmpty ? 'mini-program' : normalized;
}

String? _readManifestIdSync(String miniProgramRootPath) {
  try {
    final file = File(p.join(miniProgramRootPath, 'manifest.json'));
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) {
      final id = decoded['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _titleFromAppId(String appId) => appId
    .split(RegExp(r'[_-]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
