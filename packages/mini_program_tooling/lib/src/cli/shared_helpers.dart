import 'package:path/path.dart' as p;

import 'command_imports.dart';
import 'context.dart';
import 'private_models.dart';

extension CliSharedHelpers on CliContext {
  LocalCliStateStore get _stateStore => dependencies.stateStore;
  MiniProgramPathResolver get _pathResolver => dependencies.pathResolver;
  String? get _workingDirectory => workingDirectory;

  Set<String> parseCapabilities(String rawCapabilities) => rawCapabilities
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  String resolvePublishTarget({
    required String? explicitTarget,
    required ResolvedLocalCliEnvironmentState? resolvedEnvironmentState,
  }) {
    if (explicitTarget case final target? when target.trim().isNotEmpty) {
      return target;
    }
    return 'local';
  }

  String normalizeAbsoluteUrl(String rawValue) {
    final trimmedValue = rawValue.trim();
    final uri = Uri.tryParse(trimmedValue);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('Expected an absolute URL, but got: $rawValue');
    }
    return trimmedValue.replaceFirst(RegExp(r'/+$'), '');
  }

  String resolvePartnerPackageApiBaseUrl({
    required String? explicitApiBaseUrl,
  }) {
    if (explicitApiBaseUrl case final rawValue?
        when rawValue.trim().isNotEmpty) {
      return normalizeAbsoluteUrl(rawValue);
    }

    throw const FormatException(
      'partner package requires --artifact-base-url <url>. Mini-program '
      'artifacts are static files and provider env lookup was removed.',
    );
  }

  String defaultTitleForAppId(String appId) {
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

  Future<CliMiniProgramManifestInfo> readMiniProgramManifestInfo(
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
    return CliMiniProgramManifestInfo(
      appId: appId,
      title: title?.isNotEmpty == true ? title : null,
    );
  }

  String currentWorkingDirectory() =>
      p.normalize(p.absolute(_workingDirectory ?? Directory.current.path));

  Future<String> resolveCurrentMiniProgramRootPath({
    required String? explicitMiniProgramRootPath,
  }) async {
    final miniProgramId = await _pathResolver.inferMiniProgramId(
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: currentWorkingDirectory(),
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
      currentWorkingDirectory: currentWorkingDirectory(),
    );
    return resolved.miniProgramRootPath;
  }

  bool isGroupHelpRequest(List<String> arguments) {
    if (arguments.length != 1) {
      return false;
    }
    return arguments.single == '--help' ||
        arguments.single == '-h' ||
        arguments.single == 'help';
  }

  Future<void> requireEmbeddedHostProject(String projectRootPath) async {
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

  Future<ResolvedLocalCliEnvironmentState?> discoverEnvironmentState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverEnvironmentState(
      currentWorkingDirectory: currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalBackendWorkspaceState?> discoverBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverBackendWorkspaceState(
      currentWorkingDirectory: currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalCliEnvironmentState?> resolveEnvironmentState({
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

    return discoverEnvironmentState(
      additionalSearchRoots: <String>[
        ...additionalSearchRoots,
        if (explicitRepoRootPath != null &&
            explicitRepoRootPath.trim().isNotEmpty)
          explicitRepoRootPath,
      ],
    );
  }

  Future<ResolvedLocalCliEnvironmentState> requireEnvironmentState({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final resolved = await resolveEnvironmentState(
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

  Future<String?> resolveRepoRootPath({
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    final envState = await discoverEnvironmentState(
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
      currentWorkingDirectory: currentWorkingDirectory(),
      additionalSearchPath: envState?.state.repoRootPath,
      required: required,
    );
  }

  Future<String?> resolveBackendRootPath({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    if (explicitRootPath != null && explicitRootPath.trim().isNotEmpty) {
      final normalizedRootPath = p.normalize(p.absolute(explicitRootPath));
      if (await looksLikeBackendWorkspaceRoot(normalizedRootPath)) {
        return normalizedRootPath;
      }
      throw MiniProgramPathResolutionException(
        'Artifact host root does not contain backend/local_backend_service '
        'and backend/api: $normalizedRootPath',
      );
    }

    final backendWorkspaceState = await resolveUsableBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (backendWorkspaceState != null) {
      return backendWorkspaceState.state.backendRootPath;
    }

    final repoRootPath = await resolveRepoRootPath(
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: additionalSearchRoots,
      required: false,
    );
    if (repoRootPath != null &&
        await looksLikeBackendWorkspaceRoot(repoRootPath)) {
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
  resolveUsableBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final discovered = await discoverBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (discovered != null &&
        await looksLikeBackendWorkspaceRoot(discovered.state.backendRootPath)) {
      return discovered;
    }

    final globalState = await _stateStore.readGlobalBackendWorkspaceState();
    if (globalState != null &&
        await looksLikeBackendWorkspaceRoot(globalState.backendRootPath)) {
      return ResolvedLocalBackendWorkspaceState(
        rootPath: Directory(_stateStore.globalStateDirectoryPath()).parent.path,
        filePath: _stateStore.globalBackendWorkspaceStatePath(),
        state: globalState,
        scope: 'global',
      );
    }

    return null;
  }

  Future<String> resolveMiniProgramId({
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
      currentWorkingDirectory: currentWorkingDirectory(),
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

  Future<bool> looksLikeBackendWorkspaceRoot(String rootPath) async {
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
