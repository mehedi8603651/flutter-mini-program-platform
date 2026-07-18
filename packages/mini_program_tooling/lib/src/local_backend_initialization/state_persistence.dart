import '../local_cli_state.dart';
import 'dependencies.dart';
import 'models.dart';

Future<LocalBackendWorkspaceStatePaths> persistLocalBackendWorkspaceState(
  LocalBackendInitializationDependencies dependencies,
  LocalBackendWorkspacePaths paths,
) async {
  final now = DateTime.now().toUtc().toIso8601String();
  final existingState = await dependencies.stateStore.readBackendWorkspaceState(
    paths.backendRootPath,
  );
  final state = LocalBackendWorkspaceState(
    schemaVersion: 1,
    backendRootPath: paths.backendRootPath,
    apiRootPath: paths.apiRootPath,
    serviceDirectoryPath: paths.serviceDirectoryPath,
    initializedAtUtc: existingState?.initializedAtUtc ?? now,
    updatedAtUtc: now,
  );
  await dependencies.stateStore.writeBackendWorkspaceState(
    paths.backendRootPath,
    state,
  );
  await dependencies.stateStore.writeGlobalBackendWorkspaceState(state);

  return LocalBackendWorkspaceStatePaths(
    stateFilePath: dependencies.stateStore.backendWorkspaceStatePath(
      paths.backendRootPath,
    ),
    globalStateFilePath: dependencies.stateStore
        .globalBackendWorkspaceStatePath(),
  );
}
