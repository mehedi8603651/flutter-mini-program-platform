class MiniProgramEmbeddingInitRequest {
  const MiniProgramEmbeddingInitRequest({
    required this.projectRootPath,
    this.repoRootPath,
    this.hostAppId,
    this.hostVersion,
    this.nativeRoutePath = '/native/profile-editor',
    this.androidSeparateTasks = false,
    this.force = false,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String? hostAppId;
  final String? hostVersion;
  final String nativeRoutePath;

  /// Generate opt-in Android task integration. Standard embedding is unchanged.
  final bool androidSeparateTasks;
  final bool force;
}

class MiniProgramEmbeddingInitResult {
  const MiniProgramEmbeddingInitResult({
    required this.projectRootPath,
    required this.repoRootPath,
    required this.packageName,
    required this.hostAppId,
    required this.hostVersion,
    required this.nativeRoutePath,
    required this.createdPaths,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String packageName;
  final String hostAppId;
  final String hostVersion;
  final String nativeRoutePath;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'projectRootPath': projectRootPath,
    'repoRootPath': repoRootPath,
    'packageName': packageName,
    'hostAppId': hostAppId,
    'hostVersion': hostVersion,
    'nativeRoutePath': nativeRoutePath,
    'createdPaths': createdPaths,
  };
}

class MiniProgramEmbeddingInitException implements Exception {
  const MiniProgramEmbeddingInitException(this.message);

  final String message;

  @override
  String toString() => message;
}
