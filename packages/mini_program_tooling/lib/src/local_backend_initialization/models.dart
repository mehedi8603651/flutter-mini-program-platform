class LocalBackendInitException implements Exception {
  const LocalBackendInitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackendInitRequest {
  const LocalBackendInitRequest({this.backendRootPath, this.force = false});

  final String? backendRootPath;
  final bool force;
}

class LocalBackendInitResult {
  const LocalBackendInitResult({
    required this.backendRootPath,
    required this.apiRootPath,
    required this.serviceDirectoryPath,
    required this.stateFilePath,
    required this.globalStateFilePath,
    required this.createdPaths,
  });

  final String backendRootPath;
  final String apiRootPath;
  final String serviceDirectoryPath;
  final String stateFilePath;
  final String globalStateFilePath;
  final List<String> createdPaths;
}

class LocalBackendWorkspacePaths {
  const LocalBackendWorkspacePaths({
    required this.backendRootPath,
    required this.apiRootPath,
    required this.serviceDirectoryPath,
  });

  final String backendRootPath;
  final String apiRootPath;
  final String serviceDirectoryPath;
}

class LocalBackendWorkspaceStatePaths {
  const LocalBackendWorkspaceStatePaths({
    required this.stateFilePath,
    required this.globalStateFilePath,
  });

  final String stateFilePath;
  final String globalStateFilePath;
}
