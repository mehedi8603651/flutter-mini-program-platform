import 'dart:io';

import 'package:path/path.dart' as p;

class LocalCliStatePaths {
  const LocalCliStatePaths({
    String? homeDirectoryPath,
    String? localAppDataDirectoryPath,
  }) : _homeDirectoryPath = homeDirectoryPath,
       _localAppDataDirectoryPath = localAppDataDirectoryPath;

  final String? _homeDirectoryPath;
  final String? _localAppDataDirectoryPath;

  String stateDirectoryPath(String rootPath) =>
      p.join(normalizeRoot(rootPath), '.mini_program');

  String backendStatePath(String repoRootPath) =>
      p.join(stateDirectoryPath(repoRootPath), 'backend.local.json');

  String publishedArtifactsPath(String repoRootPath) => p.join(
    stateDirectoryPath(repoRootPath),
    'published_local_artifacts.json',
  );

  String environmentStatePath(String rootPath) =>
      p.join(stateDirectoryPath(rootPath), 'env.json');

  String backendWorkspaceStatePath(String rootPath) =>
      p.join(stateDirectoryPath(rootPath), 'backend_workspace.json');

  String globalStateDirectoryPath() =>
      p.join(normalizeHomeDirectoryPath(), '.mini_program');

  String globalEnvironmentStatePath() =>
      p.join(globalStateDirectoryPath(), 'global_env.json');

  String globalBackendWorkspaceStatePath() =>
      p.join(globalStateDirectoryPath(), 'global_backend_workspace.json');

  String defaultBackendWorkspaceRootPath() {
    if (Platform.isWindows) {
      return p.join(
        normalizeLocalAppDataDirectoryPath(),
        'mini_program',
        'backend',
      );
    }

    return p.join(globalStateDirectoryPath(), 'backend');
  }

  String normalizeRoot(String rootPath) => p.normalize(p.absolute(rootPath));

  String normalizeHomeDirectoryPath() => p.normalize(
    p.absolute(_homeDirectoryPath ?? _resolveHomeDirectoryPath()),
  );

  String normalizeLocalAppDataDirectoryPath() => p.normalize(
    p.absolute(
      _localAppDataDirectoryPath ?? _resolveLocalAppDataDirectoryPath(),
    ),
  );

  String _resolveHomeDirectoryPath() {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return home;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return userProfile;
    }

    final homeDrive = Platform.environment['HOMEDRIVE'];
    final homePath = Platform.environment['HOMEPATH'];
    if (homeDrive != null &&
        homeDrive.trim().isNotEmpty &&
        homePath != null &&
        homePath.trim().isNotEmpty) {
      return '$homeDrive$homePath';
    }

    return Directory.current.path;
  }

  String _resolveLocalAppDataDirectoryPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return localAppData;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'AppData', 'Local');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return p.join(home, 'AppData', 'Local');
    }

    return p.join(_resolveHomeDirectoryPath(), 'AppData', 'Local');
  }
}
