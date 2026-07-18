import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'paths.dart';

typedef ReadLocalEnvironmentState =
    Future<LocalCliEnvironmentState?> Function(String rootPath);
typedef ReadGlobalEnvironmentState =
    Future<LocalCliEnvironmentState?> Function();
typedef ReadLocalBackendWorkspaceState =
    Future<LocalBackendWorkspaceState?> Function(String rootPath);
typedef ReadGlobalBackendWorkspaceState =
    Future<LocalBackendWorkspaceState?> Function();

Future<ResolvedLocalCliEnvironmentState?> discoverLocalEnvironmentState({
  required LocalCliStatePaths paths,
  required ReadLocalEnvironmentState readLocalState,
  required ReadGlobalEnvironmentState readGlobalState,
  String? currentWorkingDirectory,
  Iterable<String> additionalSearchRoots = const <String>[],
  bool includeGlobalFallback = true,
}) async {
  final startDirectories = _normalizedSearchRoots(
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
  );

  for (final startDirectory in startDirectories) {
    final rootPath = await _discoverRoot(
      startDirectory: startDirectory,
      statePathForRoot: paths.environmentStatePath,
    );
    if (rootPath != null) {
      final state = await readLocalState(rootPath);
      if (state != null) {
        return ResolvedLocalCliEnvironmentState(
          rootPath: rootPath,
          filePath: paths.environmentStatePath(rootPath),
          state: state,
          scope: 'local',
        );
      }
    }
  }

  if (includeGlobalFallback) {
    final globalState = await readGlobalState();
    if (globalState != null) {
      return ResolvedLocalCliEnvironmentState(
        rootPath: paths.normalizeHomeDirectoryPath(),
        filePath: paths.globalEnvironmentStatePath(),
        state: globalState,
        scope: 'global',
      );
    }
  }

  return null;
}

Future<ResolvedLocalBackendWorkspaceState?> discoverLocalBackendWorkspaceState({
  required LocalCliStatePaths paths,
  required ReadLocalBackendWorkspaceState readLocalState,
  required ReadGlobalBackendWorkspaceState readGlobalState,
  String? currentWorkingDirectory,
  Iterable<String> additionalSearchRoots = const <String>[],
  bool includeGlobalFallback = true,
}) async {
  final startDirectories = _normalizedSearchRoots(
    currentWorkingDirectory: currentWorkingDirectory,
    additionalSearchRoots: additionalSearchRoots,
  );

  for (final startDirectory in startDirectories) {
    final rootPath = await _discoverRoot(
      startDirectory: startDirectory,
      statePathForRoot: paths.backendWorkspaceStatePath,
    );
    if (rootPath != null) {
      final state = await readLocalState(rootPath);
      if (state != null) {
        return ResolvedLocalBackendWorkspaceState(
          rootPath: rootPath,
          filePath: paths.backendWorkspaceStatePath(rootPath),
          state: state,
          scope: 'local',
        );
      }
    }
  }

  if (includeGlobalFallback) {
    final globalState = await readGlobalState();
    if (globalState != null) {
      return ResolvedLocalBackendWorkspaceState(
        rootPath: paths.normalizeHomeDirectoryPath(),
        filePath: paths.globalBackendWorkspaceStatePath(),
        state: globalState,
        scope: 'global',
      );
    }
  }

  return null;
}

Set<String> _normalizedSearchRoots({
  required String? currentWorkingDirectory,
  required Iterable<String> additionalSearchRoots,
}) => <String>{
  p.normalize(p.absolute(currentWorkingDirectory ?? Directory.current.path)),
  ...additionalSearchRoots
      .where((path) => path.trim().isNotEmpty)
      .map((path) => p.normalize(p.absolute(path))),
};

Future<String?> _discoverRoot({
  required String startDirectory,
  required String Function(String rootPath) statePathForRoot,
}) async {
  var cursor = p.normalize(p.absolute(startDirectory));
  while (true) {
    if (await File(statePathForRoot(cursor)).exists()) {
      return cursor;
    }

    final parent = p.dirname(cursor);
    if (parent == cursor) {
      return null;
    }
    cursor = parent;
  }
}
