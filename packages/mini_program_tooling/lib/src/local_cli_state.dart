import 'dart:io';

import 'local_state/models.dart';
import 'local_state/store.dart';

export 'local_state/models.dart'
    show
        LocalBackendState,
        LocalBackendWorkspaceState,
        LocalCliEnvironmentState,
        LocalCliStateException,
        PublishedLocalArtifactRecord,
        PublishedLocalArtifactsState,
        ResolvedLocalBackendWorkspaceState,
        ResolvedLocalCliEnvironmentState;

/// Public compatibility facade for local CLI state persistence.
///
/// File schemas and discovery behavior are implemented by the internal
/// feature-oriented persistence modules under `local_state/`.
class LocalCliStateStore {
  const LocalCliStateStore({
    String? homeDirectoryPath,
    String? localAppDataDirectoryPath,
  }) : _homeDirectoryPath = homeDirectoryPath,
       _localAppDataDirectoryPath = localAppDataDirectoryPath;

  final String? _homeDirectoryPath;
  final String? _localAppDataDirectoryPath;

  LocalCliStatePersistence get _persistence => LocalCliStatePersistence(
    homeDirectoryPath: _homeDirectoryPath,
    localAppDataDirectoryPath: _localAppDataDirectoryPath,
  );

  String stateDirectoryPath(String rootPath) =>
      _persistence.paths.stateDirectoryPath(rootPath);

  String backendStatePath(String repoRootPath) =>
      _persistence.paths.backendStatePath(repoRootPath);

  String publishedArtifactsPath(String repoRootPath) =>
      _persistence.paths.publishedArtifactsPath(repoRootPath);

  String environmentStatePath(String rootPath) =>
      _persistence.paths.environmentStatePath(rootPath);

  String backendWorkspaceStatePath(String rootPath) =>
      _persistence.paths.backendWorkspaceStatePath(rootPath);

  String globalStateDirectoryPath() =>
      _persistence.paths.globalStateDirectoryPath();

  String globalEnvironmentStatePath() =>
      _persistence.paths.globalEnvironmentStatePath();

  String globalBackendWorkspaceStatePath() =>
      _persistence.paths.globalBackendWorkspaceStatePath();

  String defaultBackendWorkspaceRootPath() =>
      _persistence.paths.defaultBackendWorkspaceRootPath();

  Future<Directory> ensureStateDirectory(String rootPath) =>
      _persistence.ensureStateDirectory(rootPath);

  Future<LocalBackendState?> readBackendState(String repoRootPath) =>
      _persistence.readBackendState(repoRootPath);

  Future<void> writeBackendState(
    String repoRootPath,
    LocalBackendState state,
  ) => _persistence.writeBackendState(repoRootPath, state);

  Future<void> clearBackendState(String repoRootPath) =>
      _persistence.clearBackendState(repoRootPath);

  Future<PublishedLocalArtifactsState> readPublishedArtifactsState(
    String repoRootPath,
  ) => _persistence.readPublishedArtifactsState(repoRootPath);

  Future<void> writePublishedArtifactsState(
    String repoRootPath,
    PublishedLocalArtifactsState state,
  ) => _persistence.writePublishedArtifactsState(repoRootPath, state);

  Future<void> recordPublishedArtifact(
    String repoRootPath,
    PublishedLocalArtifactRecord record,
  ) => _persistence.recordPublishedArtifact(repoRootPath, record);

  Future<void> clearPublishedArtifactsState(String repoRootPath) =>
      _persistence.clearPublishedArtifactsState(repoRootPath);

  Future<LocalCliEnvironmentState?> readEnvironmentState(String rootPath) =>
      _persistence.readEnvironmentState(rootPath);

  Future<void> writeEnvironmentState(
    String rootPath,
    LocalCliEnvironmentState state,
  ) => _persistence.writeEnvironmentState(rootPath, state);

  Future<LocalCliEnvironmentState?> readGlobalEnvironmentState() =>
      _persistence.readGlobalEnvironmentState();

  Future<void> writeGlobalEnvironmentState(LocalCliEnvironmentState state) =>
      _persistence.writeGlobalEnvironmentState(state);

  Future<ResolvedLocalCliEnvironmentState?> discoverEnvironmentState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) => _persistence.discoverEnvironmentState(
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
    includeGlobalFallback: includeGlobalFallback,
  );

  Future<LocalBackendWorkspaceState?> readBackendWorkspaceState(
    String rootPath,
  ) => _persistence.readBackendWorkspaceState(rootPath);

  Future<void> writeBackendWorkspaceState(
    String rootPath,
    LocalBackendWorkspaceState state,
  ) => _persistence.writeBackendWorkspaceState(rootPath, state);

  Future<LocalBackendWorkspaceState?> readGlobalBackendWorkspaceState() =>
      _persistence.readGlobalBackendWorkspaceState();

  Future<void> writeGlobalBackendWorkspaceState(
    LocalBackendWorkspaceState state,
  ) => _persistence.writeGlobalBackendWorkspaceState(state);

  Future<ResolvedLocalBackendWorkspaceState?> discoverBackendWorkspaceState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) => _persistence.discoverBackendWorkspaceState(
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
    includeGlobalFallback: includeGlobalFallback,
  );
}
