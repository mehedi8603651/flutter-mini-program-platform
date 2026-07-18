import 'dart:io';

import 'package:path/path.dart' as p;

import '../local_cli_state.dart';
import 'dependencies.dart';
import 'models.dart';

class DoctorEnvironmentInspection {
  const DoctorEnvironmentInspection({required this.check, this.state});

  final MiniprogramDoctorCheck check;
  final ResolvedLocalCliEnvironmentState? state;
}

Future<DoctorEnvironmentInspection> inspectDoctorEnvironment(
  DoctorDependencies dependencies, {
  required String currentWorkingDirectory,
}) async {
  try {
    final environmentState = await dependencies.stateStore
        .discoverEnvironmentState(
          currentWorkingDirectory: currentWorkingDirectory,
        );
    if (environmentState == null) {
      return const DoctorEnvironmentInspection(
        check: MiniprogramDoctorCheck(
          label: 'Env config',
          status: MiniprogramDoctorCheckStatus.warning,
          summary: 'No miniprogram env configuration was found.',
          detail:
              'Run `miniprogram env init` from your mini-program workspace.',
        ),
      );
    }

    return DoctorEnvironmentInspection(
      state: environmentState,
      check: MiniprogramDoctorCheck(
        label: 'Env config',
        status: MiniprogramDoctorCheckStatus.ok,
        summary:
            '${environmentState.scope} config at ${environmentState.filePath}',
        detail:
            'Active environment: ${environmentState.state.activeEnvironment}; '
            'repo root: ${environmentState.state.repoRootPath ?? 'not configured'}',
      ),
    );
  } on LocalCliStateException catch (error) {
    return DoctorEnvironmentInspection(
      check: MiniprogramDoctorCheck(
        label: 'Env config',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'Failed to read miniprogram env configuration.',
        detail: error.message,
      ),
    );
  }
}

Future<ResolvedLocalBackendWorkspaceState?> resolveUsableDoctorBackendWorkspace(
  DoctorDependencies dependencies, {
  required String currentWorkingDirectory,
  Iterable<String> additionalSearchRoots = const <String>[],
}) async {
  final discovered = await dependencies.stateStore
      .discoverBackendWorkspaceState(
        currentWorkingDirectory: currentWorkingDirectory,
        additionalSearchRoots: additionalSearchRoots,
      );
  if (discovered != null &&
      await looksLikeDoctorBackendWorkspaceRoot(
        discovered.state.backendRootPath,
      )) {
    return discovered;
  }

  final globalState = await dependencies.stateStore
      .readGlobalBackendWorkspaceState();
  if (globalState != null &&
      await looksLikeDoctorBackendWorkspaceRoot(globalState.backendRootPath)) {
    return ResolvedLocalBackendWorkspaceState(
      rootPath: Directory(
        dependencies.stateStore.globalStateDirectoryPath(),
      ).parent.path,
      filePath: dependencies.stateStore.globalBackendWorkspaceStatePath(),
      state: globalState,
      scope: 'global',
    );
  }

  return null;
}

Future<bool> looksLikeDoctorBackendWorkspaceRoot(String rootPath) async {
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
