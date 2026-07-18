import 'local_backend_initialization/coordinator.dart';
import 'local_backend_initialization/dependencies.dart';
import 'local_backend_initialization/models.dart';
import 'local_cli_state.dart';

export 'local_backend_initialization/models.dart'
    show
        LocalBackendInitException,
        LocalBackendInitRequest,
        LocalBackendInitResult;

/// Public facade for creating a local artifact-host workspace.
class LocalBackendInitializer {
  const LocalBackendInitializer({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    String? templateRootPath,
  }) : _stateStore = stateStore,
       _templateRootPath = templateRootPath;

  final LocalCliStateStore _stateStore;
  final String? _templateRootPath;

  LocalBackendInitializationDependencies get _dependencies =>
      LocalBackendInitializationDependencies(
        stateStore: _stateStore,
        templateRootPath: _templateRootPath,
      );

  Future<LocalBackendInitResult> initialize(LocalBackendInitRequest request) =>
      initializeLocalBackendWorkspace(_dependencies, request);
}
