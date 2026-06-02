part of '../mini_program_cloud_controller.dart';

typedef MiniProgramCloudProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

Future<ProcessResult> _defaultMiniProgramCloudProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
  );
}

class MiniProgramCloudException implements Exception {
  const MiniProgramCloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramCloudDeployRequest {
  const MiniProgramCloudDeployRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudStatusRequest {
  const MiniProgramCloudStatusRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudOutputsRequest {
  const MiniProgramCloudOutputsRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudLogsRequest {
  const MiniProgramCloudLogsRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    this.since = '1h',
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String since;
}

class MiniProgramCloudDestroyRequest {
  const MiniProgramCloudDestroyRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudDoctorRequest {
  const MiniProgramCloudDoctorRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudRollbackRequest {
  const MiniProgramCloudRollbackRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.version,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final String version;
}

class MiniProgramCloudDeployResult {
  const MiniProgramCloudDeployResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.bucketName,
    required this.backendProjectRootPath,
    required this.outputs,
    required this.deployedAtUtc,
    this.apiBaseUrl,
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
  final String bucketName;
  final String backendProjectRootPath;
  final Map<String, String> outputs;
  final String deployedAtUtc;
  final String? apiBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class MiniProgramCloudStatusResult {
  const MiniProgramCloudStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.outputs,
    this.stackStatus,
    this.stackStatusReason,
    this.apiBaseUrl,
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
  final String? stackStatus;
  final String? stackStatusReason;
  final Map<String, String> outputs;
  final String? apiBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class MiniProgramCloudOutputsResult {
  const MiniProgramCloudOutputsResult({
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

class MiniProgramCloudLogsResult {
  const MiniProgramCloudLogsResult({
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

class MiniProgramCloudDestroyResult {
  const MiniProgramCloudDestroyResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.deletedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final String deletedAtUtc;
}

class MiniProgramCloudDoctorResult {
  const MiniProgramCloudDoctorResult({required this.checks});

  final List<MiniprogramDoctorCheck> checks;

  bool get hasErrors =>
      checks.any((check) => check.status == MiniprogramDoctorCheckStatus.error);
}

class MiniProgramCloudRollbackResult {
  const MiniProgramCloudRollbackResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.version,
    required this.bucketName,
    required this.region,
    required this.catalogKey,
    required this.releaseKey,
    required this.rolledBackAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String version;
  final String bucketName;
  final String region;
  final String catalogKey;
  final String releaseKey;
  final String rolledBackAtUtc;
}

class MiniProgramAccessKeyCreateRequest {
  const MiniProgramAccessKeyCreateRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.keyId,
    this.accessKey,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final String keyId;
  final String? accessKey;
}

class MiniProgramAccessKeyListRequest {
  const MiniProgramAccessKeyListRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
}

class MiniProgramAccessKeyRevokeRequest {
  const MiniProgramAccessKeyRevokeRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.keyId,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final String keyId;
}

class MiniProgramAccessKeyRotateRequest {
  const MiniProgramAccessKeyRotateRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.keyId,
    this.newKeyId,
    this.accessKey,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final String keyId;
  final String? newKeyId;
  final String? accessKey;
}

class MiniProgramAccessKeyEntry {
  const MiniProgramAccessKeyEntry({
    required this.id,
    required this.sha256,
    required this.enabled,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.revokedAtUtc,
  });

  final String id;
  final String sha256;
  final bool enabled;
  final String createdAtUtc;
  final String updatedAtUtc;
  final String? revokedAtUtc;

  bool get active => enabled && revokedAtUtc == null;
}

class MiniProgramAccessKeyCreateResult {
  const MiniProgramAccessKeyCreateResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.policyKey,
    required this.keyId,
    required this.accessKey,
    required this.createdAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String policyKey;
  final String keyId;
  final String accessKey;
  final String createdAtUtc;
}

class MiniProgramAccessKeyListResult {
  const MiniProgramAccessKeyListResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.policyKey,
    required this.policyExists,
    required this.keys,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String policyKey;
  final bool policyExists;
  final List<MiniProgramAccessKeyEntry> keys;
}

class MiniProgramAccessKeyRevokeResult {
  const MiniProgramAccessKeyRevokeResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.policyKey,
    required this.keyId,
    required this.revokedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String policyKey;
  final String keyId;
  final String revokedAtUtc;
}

class MiniProgramAccessKeyRotateResult {
  const MiniProgramAccessKeyRotateResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.policyKey,
    required this.revokedKeyId,
    required this.newKeyId,
    required this.accessKey,
    required this.rotatedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String policyKey;
  final String revokedKeyId;
  final String newKeyId;
  final String accessKey;
  final String rotatedAtUtc;
}

class MiniProgramCloudAppListRequest {
  const MiniProgramCloudAppListRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudAppInfoRequest {
  const MiniProgramCloudAppInfoRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
}

class MiniProgramCloudAppDisableRequest {
  const MiniProgramCloudAppDisableRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.confirmed,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final bool confirmed;
}

class MiniProgramCloudAppDeleteRequest {
  const MiniProgramCloudAppDeleteRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.confirmed,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final bool confirmed;
}

class MiniProgramCloudAppSummary {
  const MiniProgramCloudAppSummary({
    required this.miniProgramId,
    required this.catalogKey,
    this.latestVersion,
    this.updatedAtUtc,
  });

  final String miniProgramId;
  final String catalogKey;
  final String? latestVersion;
  final String? updatedAtUtc;
}

class MiniProgramCloudAppListResult {
  const MiniProgramCloudAppListResult({
    required this.provider,
    required this.environmentName,
    required this.bucketName,
    required this.region,
    required this.apps,
  });

  final String provider;
  final String environmentName;
  final String bucketName;
  final String region;
  final List<MiniProgramCloudAppSummary> apps;
}

class MiniProgramCloudAppInfoResult {
  const MiniProgramCloudAppInfoResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.catalogKey,
    required this.catalog,
    this.releaseKey,
    this.release,
    this.accessPolicyKey,
    this.accessKeyCount = 0,
    this.activeAccessKeyCount = 0,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String catalogKey;
  final Map<String, dynamic> catalog;
  final String? releaseKey;
  final Map<String, dynamic>? release;
  final String? accessPolicyKey;
  final int accessKeyCount;
  final int activeAccessKeyCount;
}

class MiniProgramCloudAppDisableResult {
  const MiniProgramCloudAppDisableResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.catalogKey,
    required this.disabledCatalogKey,
    required this.disabledAtUtc,
    required this.dryRun,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final String catalogKey;
  final String disabledCatalogKey;
  final String disabledAtUtc;
  final bool dryRun;
}

class MiniProgramCloudAppDeleteResult {
  const MiniProgramCloudAppDeleteResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.bucketName,
    required this.region,
    required this.deletedKeys,
    required this.dryRun,
    required this.deletedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String bucketName;
  final String region;
  final List<String> deletedKeys;
  final bool dryRun;
  final String deletedAtUtc;
}
