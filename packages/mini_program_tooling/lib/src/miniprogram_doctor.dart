import 'doctor/coordinator.dart';
import 'doctor/dependencies.dart';
import 'doctor/models.dart';
import 'local_backend_controller.dart';
import 'local_cli_state.dart';
import 'mini_program_path_resolver.dart';

export 'doctor/dependencies.dart' show DoctorShellRunner;
export 'doctor/models.dart'
    show
        MiniprogramDoctorCheck,
        MiniprogramDoctorCheckStatus,
        MiniprogramDoctorResult;

/// Public compatibility facade for environment and workspace diagnostics.
class MiniprogramDoctor {
  const MiniprogramDoctor({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    MiniProgramPathResolver pathResolver = const MiniProgramPathResolver(),
    LocalBackendController backendController = const LocalBackendController(),
    DoctorShellRunner shellRunner = defaultDoctorShellRunner,
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

  DoctorDependencies get _dependencies => DoctorDependencies(
    stateStore: _stateStore,
    pathResolver: _pathResolver,
    backendController: _backendController,
    shellRunner: _shellRunner,
    workingDirectory: _workingDirectory,
  );

  Future<MiniprogramDoctorResult> diagnose({String? explicitRepoRootPath}) =>
      diagnoseMiniprogramEnvironment(
        _dependencies,
        explicitRepoRootPath: explicitRepoRootPath,
      );
}
