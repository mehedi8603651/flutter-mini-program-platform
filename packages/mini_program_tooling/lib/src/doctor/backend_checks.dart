import 'dart:io';

import 'package:path/path.dart' as p;

import '../local_backend_controller.dart';
import '../local_cli_state.dart';
import 'dependencies.dart';
import 'models.dart';

MiniprogramDoctorCheck missingDoctorBackendWorkspaceCheck() =>
    const MiniprogramDoctorCheck(
      label: 'Artifact host workspace',
      status: MiniprogramDoctorCheckStatus.warning,
      summary: 'No artifact host workspace was found.',
      detail:
          'Run `miniprogram artifact-host init` to scaffold a standalone '
          'local artifact host workspace.',
    );

MiniprogramDoctorCheck skippedDoctorBackendStatusCheck() =>
    const MiniprogramDoctorCheck(
      label: 'Artifact host status',
      status: MiniprogramDoctorCheckStatus.skipped,
      summary: 'Skipped because no artifact host workspace was resolved.',
    );

Future<MiniprogramDoctorCheck> inspectDoctorBackendWorkspace({
  required String backendRootPath,
  required ResolvedLocalBackendWorkspaceState? backendWorkspaceState,
}) async {
  final serviceDirectoryPath = p.join(
    backendRootPath,
    'backend',
    'local_backend_service',
  );
  final apiRootPath = p.join(backendRootPath, 'backend', 'api');
  final serviceExists = await Directory(serviceDirectoryPath).exists();
  final apiExists = await Directory(apiRootPath).exists();
  if (serviceExists && apiExists) {
    return MiniprogramDoctorCheck(
      label: 'Artifact host workspace',
      status: MiniprogramDoctorCheckStatus.ok,
      summary: 'Found backend/local_backend_service and backend/api.',
      detail:
          '${backendWorkspaceState == null ? 'Repo-owned' : '${backendWorkspaceState.scope} config'} workspace at $backendRootPath',
    );
  }

  return MiniprogramDoctorCheck(
    label: 'Artifact host workspace',
    status: MiniprogramDoctorCheckStatus.error,
    summary: 'Platform repo is missing local artifact host directories.',
    detail: 'Expected: $serviceDirectoryPath and $apiRootPath',
  );
}

Future<MiniprogramDoctorCheck> inspectDoctorBackendStatus(
  DoctorDependencies dependencies, {
  required String backendRootPath,
}) async {
  try {
    final backendStatus = await dependencies.backendController.status(
      repoRootPath: backendRootPath,
    );
    if (!backendStatus.hasState) {
      return const MiniprogramDoctorCheck(
        label: 'Artifact host status',
        status: MiniprogramDoctorCheckStatus.warning,
        summary: 'Local artifact host is not running.',
        detail:
            'Run `miniprogram artifact-host start --port 8080` when you '
            'need local manifest delivery.',
      );
    }
    if (backendStatus.healthy) {
      return MiniprogramDoctorCheck(
        label: 'Artifact host status',
        status: MiniprogramDoctorCheckStatus.ok,
        summary: 'Healthy at ${backendStatus.state!.healthCheckUrl}',
        detail:
            'Process alive: ${backendStatus.processAlive}; '
            'status: ${backendStatus.healthStatusCode ?? 200}',
      );
    }

    return MiniprogramDoctorCheck(
      label: 'Artifact host status',
      status: MiniprogramDoctorCheckStatus.warning,
      summary: 'Local artifact host state exists but is not healthy.',
      detail:
          backendStatus.healthError ??
          'Health status: ${backendStatus.healthStatusCode ?? 'unknown'}',
    );
  } on LocalBackendControlException catch (error) {
    return MiniprogramDoctorCheck(
      label: 'Artifact host status',
      status: MiniprogramDoctorCheckStatus.error,
      summary: 'Artifact host status check failed.',
      detail: error.message,
    );
  } on LocalCliStateException catch (error) {
    return MiniprogramDoctorCheck(
      label: 'Backend status',
      status: MiniprogramDoctorCheckStatus.error,
      summary: 'Failed to read backend local state.',
      detail: error.message,
    );
  }
}
