typedef MiniProgramHostProcessRunner =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class MiniProgramHostException implements Exception {
  const MiniProgramHostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramHostRunRequest {
  const MiniProgramHostRunRequest({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
}

class MiniProgramHostRunResult {
  const MiniProgramHostRunResult({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
    required this.invocation,
    required this.exitCode,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
  final List<String> invocation;
  final int exitCode;
}

class MiniProgramHostEndpointAddRequest {
  const MiniProgramHostEndpointAddRequest({
    required this.projectRootPath,
    required this.appId,
    required this.apiBaseUri,
    this.title,
    this.policySourcePath,
    this.requestedCache = const <String, Object?>{},
    this.requestedPublisherApi = const <String, Object?>{},
    this.requestedPermissions = const <String, Object?>{},
    this.acceptRequestedPolicy = false,
    this.force = false,
  });

  final String projectRootPath;
  final String appId;
  final Uri apiBaseUri;
  final String? title;
  final String? policySourcePath;
  final Map<String, Object?> requestedCache;
  final Map<String, Object?> requestedPublisherApi;
  final Map<String, Object?> requestedPermissions;
  final bool acceptRequestedPolicy;
  final bool force;
}

class MiniProgramHostEndpointAddResult {
  const MiniProgramHostEndpointAddResult({
    required this.projectRootPath,
    required this.filePath,
    required this.registryFilePath,
    required this.policyFilePath,
    required this.policyResolverFilePath,
    required this.appId,
    required this.title,
    required this.apiBaseUri,
    required this.endpointCount,
    required this.registryCount,
    required this.created,
    required this.updated,
  });

  final String projectRootPath;
  final String filePath;
  final String registryFilePath;
  final String policyFilePath;
  final String policyResolverFilePath;
  final String appId;
  final String title;
  final Uri apiBaseUri;
  final int endpointCount;
  final int registryCount;
  final bool created;
  final bool updated;
}
