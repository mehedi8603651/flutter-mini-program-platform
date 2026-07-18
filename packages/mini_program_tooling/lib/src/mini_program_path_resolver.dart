import 'path_resolution/models.dart';
import 'path_resolution/repo_discovery.dart';
import 'path_resolution/resolver.dart';

export 'path_resolution/models.dart'
    show MiniProgramPathResolutionException, ResolvedMiniProgramPaths;

/// Public compatibility facade for workspace and mini-program path resolution.
class MiniProgramPathResolver {
  const MiniProgramPathResolver();

  Future<String?> inferMiniProgramId({
    String? miniProgramRootPath,
    String? currentWorkingDirectory,
  }) => inferResolvedMiniProgramId(
    miniProgramRootPath: miniProgramRootPath,
    currentWorkingDirectory: currentWorkingDirectory,
  );

  Future<ResolvedMiniProgramPaths> resolve({
    required String miniProgramId,
    String? repoRootPath,
    String? miniProgramRootPath,
    String? currentWorkingDirectory,
    bool requireRepoRoot = false,
  }) => resolveMiniProgramPaths(
    miniProgramId: miniProgramId,
    repoRootPath: repoRootPath,
    miniProgramRootPath: miniProgramRootPath,
    currentWorkingDirectory: currentWorkingDirectory,
    requireRepoRoot: requireRepoRoot,
  );

  Future<String?> resolveRepoRoot({
    String? explicitRepoRootPath,
    String? currentWorkingDirectory,
    String? additionalSearchPath,
    bool required = false,
  }) => resolvePlatformRepoRoot(
    explicitRepoRootPath: explicitRepoRootPath,
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchPath: additionalSearchPath,
    required: required,
  );

  Future<String?> discoverRepoRoot({required String startDirectory}) =>
      discoverPlatformRepoRoot(startDirectory: startDirectory);
}
