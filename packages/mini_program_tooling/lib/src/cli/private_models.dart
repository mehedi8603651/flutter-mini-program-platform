part of '../miniprogram_cli.dart';

class _PublisherBackendAwsInputs {
  const _PublisherBackendAwsInputs({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class _PublisherBackendFirebaseInputs {
  const _PublisherBackendFirebaseInputs({
    required this.miniProgramRootPath,
    required this.environment,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
}

class _MiniProgramManifestInfo {
  const _MiniProgramManifestInfo({required this.appId, required this.title});

  final String appId;
  final String? title;
}

class _PublisherBackendFirebaseHostCommandResult {
  const _PublisherBackendFirebaseHostCommandResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.title,
    required this.deliveryApiBaseUrl,
    required this.backendBaseUrl,
    required this.accessMode,
    required this.hostEndpointCommandText,
    required this.hostProjectRootPath,
    required this.readiness,
    required this.hostAuthReadiness,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String title;
  final String deliveryApiBaseUrl;
  final String backendBaseUrl;
  final String accessMode;
  final String hostEndpointCommandText;
  final String? hostProjectRootPath;
  final _HostEndpointReadiness? readiness;
  final _HostAuthReadiness? hostAuthReadiness;
}

class _PublisherBackendFirebaseAuthStatusCliResult {
  const _PublisherBackendFirebaseAuthStatusCliResult({
    required this.authStatus,
    required this.hostProjectRootPath,
    required this.hostAuthReadiness,
  });

  final PublisherBackendFirebaseAuthStatusResult authStatus;
  final String? hostProjectRootPath;
  final _HostAuthReadiness? hostAuthReadiness;
}

class _PublisherBackendFirebaseHandoffResult {
  const _PublisherBackendFirebaseHandoffResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.region,
    required this.functionName,
    required this.miniProgramRootPath,
    required this.packageResult,
    required this.hostImportCommandText,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String region;
  final String functionName;
  final String miniProgramRootPath;
  final MiniProgramPartnerPackageResult packageResult;
  final String hostImportCommandText;
}

class _HostEndpointReadiness {
  const _HostEndpointReadiness({
    required this.ready,
    required this.endpointFound,
    required this.endpointMapPath,
    required this.issues,
    this.apiBaseUrl,
    this.backendBaseUrl,
    this.accessMode,
    this.backendMode,
  });

  final bool ready;
  final bool endpointFound;
  final String endpointMapPath;
  final List<String> issues;
  final String? apiBaseUrl;
  final String? backendBaseUrl;
  final String? accessMode;
  final String? backendMode;
}

class _HostAuthReadiness {
  const _HostAuthReadiness({
    required this.ready,
    required this.runtimeSetupPath,
    required this.authControllerConfigured,
    required this.secureAuthControllerConfigured,
    required this.disposeAuthControllerConfigured,
    required this.issues,
  });

  final bool ready;
  final String runtimeSetupPath;
  final bool authControllerConfigured;
  final bool secureAuthControllerConfigured;
  final bool disposeAuthControllerConfigured;
  final List<String> issues;
}
