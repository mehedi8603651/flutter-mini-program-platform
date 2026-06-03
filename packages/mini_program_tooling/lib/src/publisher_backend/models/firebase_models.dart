part of '../../publisher_backend_starter.dart';

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
    required this.sourceRootPath,
    required this.miniProgramId,
    required this.title,
    required this.entryScreen,
    required this.screenFormat,
    required this.writtenPaths,
    required this.skippedPaths,
    required this.unchangedPaths,
    required this.force,
    this.screenSchemaVersion,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String sourceRootPath;
  final String miniProgramId;
  final String title;
  final String entryScreen;
  final String screenFormat;
  final int? screenSchemaVersion;
  final List<String> writtenPaths;
  final List<String> skippedPaths;
  final List<String> unchangedPaths;
  final bool force;
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
