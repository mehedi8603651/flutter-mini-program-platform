class MiniProgramHostCapabilityInitRequest {
  const MiniProgramHostCapabilityInitRequest({
    required this.projectRootPath,
    required this.capability,
    required this.platform,
  });

  final String projectRootPath;
  final String capability;
  final String platform;
}

class MiniProgramHostCapabilityInitResult {
  const MiniProgramHostCapabilityInitResult({
    required this.projectRootPath,
    required this.capability,
    required this.platform,
    required this.createdPaths,
    required this.updatedPaths,
  });

  final String projectRootPath;
  final String capability;
  final String platform;
  final List<String> createdPaths;
  final List<String> updatedPaths;

  bool get alreadyInstalled => createdPaths.isEmpty && updatedPaths.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectRootPath': projectRootPath,
    'capability': capability,
    'platform': platform,
    'alreadyInstalled': alreadyInstalled,
    'createdPaths': createdPaths,
    'updatedPaths': updatedPaths,
  };
}

class MiniProgramHostCapabilityException implements Exception {
  const MiniProgramHostCapabilityException(this.message);

  final String message;

  @override
  String toString() => message;
}
