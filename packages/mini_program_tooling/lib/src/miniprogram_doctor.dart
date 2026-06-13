import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_backend_controller.dart';
import 'local_cli_state.dart';
import 'mini_program_path_resolver.dart';

typedef DoctorShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

enum MiniprogramDoctorCheckStatus { ok, warning, error, skipped }

class MiniprogramDoctorCheck {
  const MiniprogramDoctorCheck({
    required this.label,
    required this.status,
    required this.summary,
    this.detail,
  });

  final String label;
  final MiniprogramDoctorCheckStatus status;
  final String summary;
  final String? detail;
}

class MiniprogramDoctorResult {
  const MiniprogramDoctorResult({required this.checks});

  final List<MiniprogramDoctorCheck> checks;

  bool get hasErrors =>
      checks.any((check) => check.status == MiniprogramDoctorCheckStatus.error);
}

class MiniprogramDoctor {
  const MiniprogramDoctor({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    MiniProgramPathResolver pathResolver = const MiniProgramPathResolver(),
    LocalBackendController backendController = const LocalBackendController(),
    DoctorShellRunner shellRunner = _defaultShellRunner,
    String? workingDirectory,
  }) : _stateStore = stateStore,
       _pathResolver = pathResolver,
       _backendController = backendController,
       _shellRunner = shellRunner,
       _workingDirectory = workingDirectory;

  final LocalCliStateStore _stateStore;
  final MiniProgramPathResolver _pathResolver;
  final LocalBackendController _backendController;
  final DoctorShellRunner _shellRunner;
  final String? _workingDirectory;

  Future<MiniprogramDoctorResult> diagnose({
    String? explicitRepoRootPath,
  }) async {
    final checks = <MiniprogramDoctorCheck>[];
    final cwd = p.normalize(
      p.absolute(_workingDirectory ?? Directory.current.path),
    );

    checks.add(
      MiniprogramDoctorCheck(
        label: 'Dart SDK',
        status: MiniprogramDoctorCheckStatus.ok,
        summary: Platform.version.split(' ').first,
        detail: 'Running from ${Platform.resolvedExecutable}',
      ),
    );

    checks.add(
      await _probeCommand(
        label: 'Flutter CLI',
        executable: 'flutter',
        arguments: const <String>['--version'],
        missingSummary: 'Flutter was not found on PATH.',
        missingDetail:
            'Install Flutter and ensure the `flutter` executable is available '
            'on PATH.',
      ),
    );

    ResolvedLocalCliEnvironmentState? environmentState;
    try {
      environmentState = await _stateStore.discoverEnvironmentState(
        currentWorkingDirectory: cwd,
      );
      if (environmentState == null) {
        checks.add(
          const MiniprogramDoctorCheck(
            label: 'Env config',
            status: MiniprogramDoctorCheckStatus.warning,
            summary: 'No miniprogram env configuration was found.',
            detail:
                'Run `miniprogram env init` from your mini-program workspace.',
          ),
        );
      } else {
        checks.add(
          MiniprogramDoctorCheck(
            label: 'Env config',
            status: MiniprogramDoctorCheckStatus.ok,
            summary:
                '${environmentState.scope} config at ${environmentState.filePath}',
            detail:
                'Active environment: ${environmentState.state.activeEnvironment}; '
                'repo root: ${environmentState.state.repoRootPath ?? 'not configured'}',
          ),
        );
      }
    } on LocalCliStateException catch (error) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Env config',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Failed to read miniprogram env configuration.',
          detail: error.message,
        ),
      );
    }

    String? repoRootPath;
    try {
      repoRootPath = await _pathResolver.resolveRepoRoot(
        explicitRepoRootPath:
            explicitRepoRootPath ?? environmentState?.state.repoRootPath,
        currentWorkingDirectory: cwd,
        additionalSearchPath: environmentState?.state.repoRootPath,
      );
      if (repoRootPath == null) {
        checks.add(
          const MiniprogramDoctorCheck(
            label: 'Platform repo',
            status: MiniprogramDoctorCheckStatus.skipped,
            summary: 'Platform repo root is not configured.',
            detail:
                'Standalone CLI workflows can continue without it. Older '
                'repo-managed commands can still pass `--repo-root` when '
                'needed.',
          ),
        );
      } else {
        checks.add(
          MiniprogramDoctorCheck(
            label: 'Platform repo',
            status: MiniprogramDoctorCheckStatus.ok,
            summary: repoRootPath,
          ),
        );
      }
    } on MiniProgramPathResolutionException catch (error) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Platform repo',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Platform repo resolution failed.',
          detail: error.message,
        ),
      );
    }

    ResolvedLocalBackendWorkspaceState? backendWorkspaceState;
    try {
      backendWorkspaceState = await _resolveUsableBackendWorkspaceState(
        currentWorkingDirectory: cwd,
        additionalSearchRoots: <String>[
          if (repoRootPath != null) repoRootPath,
          if (environmentState?.state.repoRootPath case final repoRoot?)
            repoRoot,
        ],
      );
    } on LocalCliStateException catch (error) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Artifact host workspace',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Failed to read artifact host workspace configuration.',
          detail: error.message,
        ),
      );
    }

    final backendRootPath =
        backendWorkspaceState?.state.backendRootPath ?? repoRootPath;
    if (backendRootPath == null) {
      checks.add(
        const MiniprogramDoctorCheck(
          label: 'Artifact host workspace',
          status: MiniprogramDoctorCheckStatus.warning,
          summary: 'No artifact host workspace was found.',
          detail:
              'Run `miniprogram artifact-host init` to scaffold a standalone '
              'local artifact host workspace.',
        ),
      );
      checks.add(
        const MiniprogramDoctorCheck(
          label: 'Artifact host status',
          status: MiniprogramDoctorCheckStatus.skipped,
          summary: 'Skipped because no artifact host workspace was resolved.',
        ),
      );
      return MiniprogramDoctorResult(checks: checks);
    }

    final serviceDirectoryPath = p.join(
      backendRootPath,
      'backend',
      'local_backend_service',
    );
    final apiRootPath = p.join(backendRootPath, 'backend', 'api');
    final serviceExists = await Directory(serviceDirectoryPath).exists();
    final apiExists = await Directory(apiRootPath).exists();
    if (serviceExists && apiExists) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Artifact host workspace',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: 'Found backend/local_backend_service and backend/api.',
          detail:
              '${backendWorkspaceState == null ? 'Repo-owned' : '${backendWorkspaceState.scope} config'} workspace at $backendRootPath',
        ),
      );
    } else {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Artifact host workspace',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Platform repo is missing local artifact host directories.',
          detail: 'Expected: $serviceDirectoryPath and $apiRootPath',
        ),
      );
    }

    try {
      final backendStatus = await _backendController.status(
        repoRootPath: backendRootPath,
      );
      if (!backendStatus.hasState) {
        checks.add(
          const MiniprogramDoctorCheck(
            label: 'Artifact host status',
            status: MiniprogramDoctorCheckStatus.warning,
            summary: 'Local artifact host is not running.',
            detail:
                'Run `miniprogram artifact-host start --port 8080` when you '
                'need local manifest delivery.',
          ),
        );
      } else if (backendStatus.healthy) {
        checks.add(
          MiniprogramDoctorCheck(
            label: 'Artifact host status',
            status: MiniprogramDoctorCheckStatus.ok,
            summary: 'Healthy at ${backendStatus.state!.healthCheckUrl}',
            detail:
                'Process alive: ${backendStatus.processAlive}; '
                'status: ${backendStatus.healthStatusCode ?? 200}',
          ),
        );
      } else {
        checks.add(
          MiniprogramDoctorCheck(
            label: 'Artifact host status',
            status: MiniprogramDoctorCheckStatus.warning,
            summary: 'Local artifact host state exists but is not healthy.',
            detail:
                backendStatus.healthError ??
                'Health status: ${backendStatus.healthStatusCode ?? 'unknown'}',
          ),
        );
      }
    } on LocalBackendControlException catch (error) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Artifact host status',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Artifact host status check failed.',
          detail: error.message,
        ),
      );
    } on LocalCliStateException catch (error) {
      checks.add(
        MiniprogramDoctorCheck(
          label: 'Backend status',
          status: MiniprogramDoctorCheckStatus.error,
          summary: 'Failed to read backend local state.',
          detail: error.message,
        ),
      );
    }

    return MiniprogramDoctorResult(checks: checks);
  }

  Future<ResolvedLocalBackendWorkspaceState?>
  _resolveUsableBackendWorkspaceState({
    required String currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final discovered = await _stateStore.discoverBackendWorkspaceState(
      currentWorkingDirectory: currentWorkingDirectory,
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

  Future<MiniprogramDoctorCheck> _probeCommand({
    required String label,
    required String executable,
    required List<String> arguments,
    required String missingSummary,
    required String missingDetail,
  }) async {
    try {
      final result = await _shellRunner(
        executable,
        arguments,
        workingDirectory: _workingDirectory,
      );
      if (result.exitCode != 0) {
        return MiniprogramDoctorCheck(
          label: label,
          status: MiniprogramDoctorCheckStatus.warning,
          summary: missingSummary,
          detail: _extractCommandDetail(result) ?? missingDetail,
        );
      }

      return MiniprogramDoctorCheck(
        label: label,
        status: MiniprogramDoctorCheckStatus.ok,
        summary: _extractCommandDetail(result) ?? '$executable is available.',
      );
    } on ProcessException catch (error) {
      return MiniprogramDoctorCheck(
        label: label,
        status: MiniprogramDoctorCheckStatus.warning,
        summary: missingSummary,
        detail: error.message.isEmpty ? missingDetail : error.message,
      );
    }
  }

  String? _extractCommandDetail(ProcessResult result) {
    final combined = <String>[
      '${result.stdout}'.trim(),
      '${result.stderr}'.trim(),
    ].where((value) => value.isNotEmpty).join('\n').trim();
    if (combined.isEmpty) {
      return null;
    }

    final lines = combined
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines.isEmpty ? null : lines.first;
  }

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );
  }
}
