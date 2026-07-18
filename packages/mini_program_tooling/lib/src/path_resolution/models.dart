class MiniProgramPathResolutionException implements Exception {
  const MiniProgramPathResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResolvedMiniProgramPaths {
  const ResolvedMiniProgramPaths({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.isRepoManaged,
    required this.checkedPaths,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final bool isRepoManaged;
  final List<String> checkedPaths;
}

class MiniProgramPathCandidate {
  const MiniProgramPathCandidate({
    required this.path,
    required this.label,
    this.isExplicit = false,
    this.isRepoManaged = false,
  });

  final String path;
  final String label;
  final bool isExplicit;
  final bool isRepoManaged;
}

class MatchedMiniProgram {
  const MatchedMiniProgram({
    required this.miniProgramRootPath,
    required this.miniProgramId,
  });

  final String miniProgramRootPath;
  final String miniProgramId;
}
