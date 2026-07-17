import 'dart:io';

typedef PreviewHostShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class MiniProgramPreviewHostInitRequest {
  const MiniProgramPreviewHostInitRequest({
    required this.hostRootPath,
    this.repoRootPath,
    this.screenFormat = 'mp',
    this.requiredPlatforms = const <String>{'web', 'windows'},
  });

  final String hostRootPath;
  final String? repoRootPath;
  final String screenFormat;
  final Set<String> requiredPlatforms;
}

class MiniProgramPreviewHostInitResult {
  const MiniProgramPreviewHostInitResult({
    required this.hostRootPath,
    required this.managedPaths,
    required this.usedPathDependencies,
    this.screenFormat = 'mp',
  });

  final String hostRootPath;
  final List<String> managedPaths;
  final bool usedPathDependencies;
  final String screenFormat;
}

class MiniProgramPreviewHostInitException implements Exception {
  const MiniProgramPreviewHostInitException(this.message);

  final String message;

  @override
  String toString() => message;
}
