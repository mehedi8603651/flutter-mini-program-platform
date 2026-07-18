import '../local_backend_controller.dart';
import 'dependencies.dart';

Future<Map<String, Object?>> inspectWorkflowEnvironment(
  WorkflowStatusDependencies dependencies, {
  required String workspacePath,
  required String? explicitEnvironmentName,
}) async {
  final resolved = await dependencies.stateStore.discoverEnvironmentState(
    currentWorkingDirectory: workspacePath,
    additionalSearchRoots: <String>[workspacePath],
  );
  if (resolved == null) {
    return <String, Object?>{'configured': false};
  }
  final activeEnvironment = resolved.state.activeEnvironment;
  final requestedEnvironmentName =
      explicitEnvironmentName?.trim().isNotEmpty == true
      ? explicitEnvironmentName!.trim()
      : activeEnvironment;
  return <String, Object?>{
    'configured': true,
    'scope': resolved.scope,
    'rootPath': resolved.rootPath,
    'filePath': resolved.filePath,
    'activeEnvironment': activeEnvironment,
    'selectedEnvironment': requestedEnvironmentName,
  };
}

Future<Map<String, Object?>> inspectWorkflowBackend(
  WorkflowStatusDependencies dependencies,
  String workspacePath,
) async {
  final resolved = await dependencies.stateStore.discoverBackendWorkspaceState(
    currentWorkingDirectory: workspacePath,
    additionalSearchRoots: <String>[workspacePath],
  );
  if (resolved == null) {
    return <String, Object?>{'configured': false, 'statusChecked': false};
  }
  try {
    final status = await dependencies.backendController.status(
      repoRootPath: resolved.state.backendRootPath,
    );
    return <String, Object?>{
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'backendRootPath': resolved.state.backendRootPath,
      'apiRootPath': resolved.state.apiRootPath,
      'statusChecked': true,
      ...workflowStatusBackendJson(status),
    };
  } catch (error) {
    return <String, Object?>{
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'backendRootPath': resolved.state.backendRootPath,
      'apiRootPath': resolved.state.apiRootPath,
      'statusChecked': false,
      'error': error.toString(),
    };
  }
}

Map<String, Object?> workflowStatusBackendJson(
  LocalBackendStatusResult result,
) => <String, Object?>{
  'hasState': result.hasState,
  'processAlive': result.processAlive,
  'healthy': result.healthy,
  'healthStatusCode': result.healthStatusCode,
  'healthError': result.healthError,
  'state': result.state == null
      ? null
      : <String, Object?>{
          'pid': result.state!.pid,
          'port': result.state!.port,
          'bindHost': result.state!.bindHost,
          'healthCheckUrl': result.state!.healthCheckUrl,
          'stdoutLogPath': result.state!.stdoutLogPath,
          'stderrLogPath': result.state!.stderrLogPath,
          'startedAtUtc': result.state!.startedAtUtc,
        },
};
