import 'dart:io';

import 'discovery.dart';
import 'json_io.dart';
import 'models.dart';
import 'paths.dart';

class LocalCliStatePersistence {
  LocalCliStatePersistence({
    String? homeDirectoryPath,
    String? localAppDataDirectoryPath,
  }) : paths = LocalCliStatePaths(
         homeDirectoryPath: homeDirectoryPath,
         localAppDataDirectoryPath: localAppDataDirectoryPath,
       );

  final LocalCliStatePaths paths;

  Future<Directory> ensureStateDirectory(String rootPath) async {
    final directory = Directory(paths.stateDirectoryPath(rootPath));
    await directory.create(recursive: true);
    return directory;
  }

  Future<LocalBackendState?> readBackendState(String repoRootPath) async {
    final file = File(paths.backendStatePath(repoRootPath));
    if (!await file.exists()) {
      return null;
    }

    return LocalBackendState.fromJson(await readLocalStateJsonObject(file));
  }

  Future<void> writeBackendState(
    String repoRootPath,
    LocalBackendState state,
  ) async {
    await ensureStateDirectory(repoRootPath);
    await writeLocalStateJsonObject(
      File(paths.backendStatePath(repoRootPath)),
      state.toJson(),
    );
  }

  Future<void> clearBackendState(String repoRootPath) =>
      _deleteIfPresent(File(paths.backendStatePath(repoRootPath)));

  Future<PublishedLocalArtifactsState> readPublishedArtifactsState(
    String repoRootPath,
  ) async {
    final file = File(paths.publishedArtifactsPath(repoRootPath));
    if (!await file.exists()) {
      return const PublishedLocalArtifactsState(
        records: <PublishedLocalArtifactRecord>[],
      );
    }

    return PublishedLocalArtifactsState.fromJson(
      await readLocalStateJsonObject(file),
    );
  }

  Future<void> writePublishedArtifactsState(
    String repoRootPath,
    PublishedLocalArtifactsState state,
  ) async {
    await ensureStateDirectory(repoRootPath);
    await writeLocalStateJsonObject(
      File(paths.publishedArtifactsPath(repoRootPath)),
      state.toJson(),
    );
  }

  Future<void> recordPublishedArtifact(
    String repoRootPath,
    PublishedLocalArtifactRecord record,
  ) async {
    final state = await readPublishedArtifactsState(repoRootPath);
    final updatedRecords =
        state.records
            .where(
              (existing) =>
                  existing.miniProgramId != record.miniProgramId ||
                  existing.version != record.version,
            )
            .toList()
          ..add(record);
    updatedRecords.sort((a, b) {
      final idComparison = a.miniProgramId.compareTo(b.miniProgramId);
      if (idComparison != 0) {
        return idComparison;
      }
      return a.version.compareTo(b.version);
    });

    await writePublishedArtifactsState(
      repoRootPath,
      PublishedLocalArtifactsState(records: updatedRecords),
    );
  }

  Future<void> clearPublishedArtifactsState(String repoRootPath) =>
      _deleteIfPresent(File(paths.publishedArtifactsPath(repoRootPath)));

  Future<LocalCliEnvironmentState?> readEnvironmentState(
    String rootPath,
  ) async {
    final file = File(paths.environmentStatePath(rootPath));
    if (!await file.exists()) {
      return null;
    }

    return LocalCliEnvironmentState.fromJson(
      await readLocalStateJsonObject(file),
    );
  }

  Future<void> writeEnvironmentState(
    String rootPath,
    LocalCliEnvironmentState state,
  ) async {
    await ensureStateDirectory(rootPath);
    await writeLocalStateJsonObject(
      File(paths.environmentStatePath(rootPath)),
      state.toJson(),
    );
  }

  Future<LocalCliEnvironmentState?> readGlobalEnvironmentState() async {
    final file = File(paths.globalEnvironmentStatePath());
    if (!await file.exists()) {
      return null;
    }

    return LocalCliEnvironmentState.fromJson(
      await readLocalStateJsonObject(file),
    );
  }

  Future<void> writeGlobalEnvironmentState(
    LocalCliEnvironmentState state,
  ) async {
    await Directory(paths.globalStateDirectoryPath()).create(recursive: true);
    await writeLocalStateJsonObject(
      File(paths.globalEnvironmentStatePath()),
      state.toJson(),
    );
  }

  Future<ResolvedLocalCliEnvironmentState?> discoverEnvironmentState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) => discoverLocalEnvironmentState(
    paths: paths,
    readLocalState: readEnvironmentState,
    readGlobalState: readGlobalEnvironmentState,
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
    includeGlobalFallback: includeGlobalFallback,
  );

  Future<LocalBackendWorkspaceState?> readBackendWorkspaceState(
    String rootPath,
  ) async {
    final file = File(paths.backendWorkspaceStatePath(rootPath));
    if (!await file.exists()) {
      return null;
    }

    return LocalBackendWorkspaceState.fromJson(
      await readLocalStateJsonObject(file),
    );
  }

  Future<void> writeBackendWorkspaceState(
    String rootPath,
    LocalBackendWorkspaceState state,
  ) async {
    await ensureStateDirectory(rootPath);
    await writeLocalStateJsonObject(
      File(paths.backendWorkspaceStatePath(rootPath)),
      state.toJson(),
    );
  }

  Future<LocalBackendWorkspaceState?> readGlobalBackendWorkspaceState() async {
    final file = File(paths.globalBackendWorkspaceStatePath());
    if (!await file.exists()) {
      return null;
    }

    return LocalBackendWorkspaceState.fromJson(
      await readLocalStateJsonObject(file),
    );
  }

  Future<void> writeGlobalBackendWorkspaceState(
    LocalBackendWorkspaceState state,
  ) async {
    await Directory(paths.globalStateDirectoryPath()).create(recursive: true);
    await writeLocalStateJsonObject(
      File(paths.globalBackendWorkspaceStatePath()),
      state.toJson(),
    );
  }

  Future<ResolvedLocalBackendWorkspaceState?> discoverBackendWorkspaceState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) => discoverLocalBackendWorkspaceState(
    paths: paths,
    readLocalState: readBackendWorkspaceState,
    readGlobalState: readGlobalBackendWorkspaceState,
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
    includeGlobalFallback: includeGlobalFallback,
  );

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
