part of '../miniprogram_cli.dart';

extension _MiniprogramCliSharedHelpers on MiniprogramCli {
  Set<String> _parseCapabilities(String rawCapabilities) => rawCapabilities
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  String _resolvePublishTarget({
    required String? explicitTarget,
    required ResolvedLocalCliEnvironmentState? resolvedEnvironmentState,
  }) {
    if (explicitTarget case final target? when target.trim().isNotEmpty) {
      return target;
    }
    return 'local';
  }

  String _normalizeAbsoluteUrl(String rawValue) {
    final trimmedValue = rawValue.trim();
    final uri = Uri.tryParse(trimmedValue);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('Expected an absolute URL, but got: $rawValue');
    }
    return trimmedValue.replaceFirst(RegExp(r'/+$'), '');
  }

  String _defaultTitleForAppId(String appId) {
    final words = appId
        .trim()
        .split(RegExp(r'[._-]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return appId;
    }
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<_MiniProgramManifestInfo> _readMiniProgramManifestInfo(
    String miniProgramRootPath,
  ) async {
    final manifestPath = p.join(miniProgramRootPath, 'manifest.json');
    final manifestFile = File(manifestPath);
    if (!await manifestFile.exists()) {
      throw MiniProgramPathResolutionException(
        'Mini-program manifest was not found: $manifestPath',
      );
    }
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      throw FormatException('Mini-program manifest is not a JSON object.');
    }
    final appId = decoded['id']?.toString().trim() ?? '';
    if (appId.isEmpty) {
      throw const FormatException('Mini-program manifest is missing id.');
    }
    final title = decoded['title']?.toString().trim();
    return _MiniProgramManifestInfo(
      appId: appId,
      title: title?.isNotEmpty == true ? title : null,
    );
  }

  String _currentWorkingDirectory() =>
      p.normalize(p.absolute(_workingDirectory ?? Directory.current.path));

  Future<String> _resolveCurrentMiniProgramRootPath({
    required String? explicitMiniProgramRootPath,
  }) async {
    final miniProgramId = await _pathResolver.inferMiniProgramId(
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
    );
    if (miniProgramId == null || miniProgramId.trim().isEmpty) {
      throw const MiniProgramPathResolutionException(
        'Could not infer the mini-program id. Open the mini-program root or '
        'pass --mini-program-root.',
      );
    }
    final resolved = await _pathResolver.resolve(
      miniProgramId: miniProgramId,
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
    );
    return resolved.miniProgramRootPath;
  }

  bool _isGroupHelpRequest(List<String> arguments) {
    if (arguments.length != 1) {
      return false;
    }
    return arguments.single == '--help' ||
        arguments.single == '-h' ||
        arguments.single == 'help';
  }

  Future<void> _requireEmbeddedHostProject(String projectRootPath) async {
    final normalizedRootPath = p.normalize(p.absolute(projectRootPath));
    final pubspec = File(p.join(normalizedRootPath, 'pubspec.yaml'));
    final libDirectory = Directory(p.join(normalizedRootPath, 'lib'));
    if (!await pubspec.exists() || !await libDirectory.exists()) {
      throw MiniProgramHostException(
        'Host project root must contain pubspec.yaml and lib/: '
        '$normalizedRootPath',
      );
    }
  }

  Future<ResolvedLocalCliEnvironmentState?> _discoverEnvironmentState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverEnvironmentState(
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalBackendWorkspaceState?> _discoverBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverBackendWorkspaceState(
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalCliEnvironmentState?> _resolveEnvironmentState({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    if (explicitRootPath != null && explicitRootPath.trim().isNotEmpty) {
      final rootPath = p.normalize(p.absolute(explicitRootPath));
      final state = await _stateStore.readEnvironmentState(rootPath);
      if (state == null) {
        final globalState = await _stateStore.readGlobalEnvironmentState();
        if (globalState == null) {
          return null;
        }
        return ResolvedLocalCliEnvironmentState(
          rootPath: Directory(
            _stateStore.globalStateDirectoryPath(),
          ).parent.path,
          filePath: _stateStore.globalEnvironmentStatePath(),
          state: globalState,
          scope: 'global',
        );
      }
      return ResolvedLocalCliEnvironmentState(
        rootPath: rootPath,
        filePath: _stateStore.environmentStatePath(rootPath),
        state: state,
        scope: 'local',
      );
    }

    return _discoverEnvironmentState(
      additionalSearchRoots: <String>[
        ...additionalSearchRoots,
        if (explicitRepoRootPath != null &&
            explicitRepoRootPath.trim().isNotEmpty)
          explicitRepoRootPath,
      ],
    );
  }

  Future<ResolvedLocalCliEnvironmentState> _requireEnvironmentState({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final resolved = await _resolveEnvironmentState(
      explicitRootPath: explicitRootPath,
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: additionalSearchRoots,
    );
    if (resolved == null) {
      throw const FormatException(
        'No miniprogram env configuration was found. Run '
        '"miniprogram env init" first.',
      );
    }
    return resolved;
  }

  Future<String?> _resolveRepoRootPath({
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    final envState = await _discoverEnvironmentState(
      additionalSearchRoots: <String>[
        ...additionalSearchRoots,
        if (explicitRepoRootPath != null &&
            explicitRepoRootPath.trim().isNotEmpty)
          explicitRepoRootPath,
      ],
    );
    return _pathResolver.resolveRepoRoot(
      explicitRepoRootPath:
          explicitRepoRootPath ?? envState?.state.repoRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchPath: envState?.state.repoRootPath,
      required: required,
    );
  }

  Future<String?> _resolveBackendRootPath({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    if (explicitRootPath != null && explicitRootPath.trim().isNotEmpty) {
      final normalizedRootPath = p.normalize(p.absolute(explicitRootPath));
      if (await _looksLikeBackendWorkspaceRoot(normalizedRootPath)) {
        return normalizedRootPath;
      }
      throw MiniProgramPathResolutionException(
        'Artifact host root does not contain backend/local_backend_service '
        'and backend/api: $normalizedRootPath',
      );
    }

    final backendWorkspaceState = await _resolveUsableBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (backendWorkspaceState != null) {
      return backendWorkspaceState.state.backendRootPath;
    }

    final repoRootPath = await _resolveRepoRootPath(
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: additionalSearchRoots,
      required: false,
    );
    if (repoRootPath != null &&
        await _looksLikeBackendWorkspaceRoot(repoRootPath)) {
      return repoRootPath;
    }

    if (required) {
      throw const MiniProgramPathResolutionException(
        'Could not find a local artifact host workspace. Run '
        '`miniprogram artifact-host init` or provide --root / --repo-root.',
      );
    }
    return null;
  }

  Future<ResolvedLocalBackendWorkspaceState?>
  _resolveUsableBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final discovered = await _discoverBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (discovered != null &&
        await _looksLikeBackendWorkspaceRoot(
          discovered.state.backendRootPath,
        )) {
      return discovered;
    }

    final globalState = await _stateStore.readGlobalBackendWorkspaceState();
    if (globalState != null &&
        await _looksLikeBackendWorkspaceRoot(globalState.backendRootPath)) {
      return ResolvedLocalBackendWorkspaceState(
        rootPath: Directory(_stateStore.globalStateDirectoryPath()).parent.path,
        filePath: _stateStore.globalBackendWorkspaceStatePath(),
        state: globalState,
        scope: 'global',
      );
    }

    return null;
  }

  Future<String> _resolveMiniProgramId({
    required String commandName,
    required List<String> positionalArguments,
    String? explicitMiniProgramRootPath,
  }) async {
    if (positionalArguments.length > 1) {
      throw FormatException(
        '$commandName expects zero or one <mini-program-id> positional argument.',
      );
    }

    if (positionalArguments.length == 1) {
      return positionalArguments.single;
    }

    final inferredMiniProgramId = await _pathResolver.inferMiniProgramId(
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
    );
    if (inferredMiniProgramId != null) {
      return inferredMiniProgramId;
    }

    throw FormatException(
      'No <mini-program-id> was provided, and the current directory does not '
      'look like a mini-program root. Run `miniprogram $commandName '
      '<mini-program-id>` or change into the mini-program folder first.',
    );
  }

  Future<bool> _looksLikeBackendWorkspaceRoot(String rootPath) async {
    final normalizedRootPath = p.normalize(p.absolute(rootPath));
    final apiRoot = Directory(p.join(normalizedRootPath, 'backend', 'api'));
    final serverEntrypoint = File(
      p.join(
        normalizedRootPath,
        'backend',
        'local_backend_service',
        'bin',
        'server.dart',
      ),
    );
    return await apiRoot.exists() && await serverEntrypoint.exists();
  }
}
