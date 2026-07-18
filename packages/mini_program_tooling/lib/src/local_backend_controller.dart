import 'package:http/http.dart' as http;

import 'local_backend/dependencies.dart';
import 'local_backend/lifecycle.dart';
import 'local_backend/models.dart';
import 'local_backend/process_control.dart';
import 'local_backend/reset.dart';
import 'local_cli_state.dart';

export 'local_backend/models.dart'
    show
        BackendClock,
        BackendHealthGetter,
        BackendProcessStarter,
        BackendShellRunner,
        LocalBackendControlException,
        LocalBackendResetResult,
        LocalBackendStartResult,
        LocalBackendStatusResult,
        LocalBackendStopResult,
        StartedBackendProcess;

/// Public compatibility facade for the local artifact backend lifecycle.
class LocalBackendController {
  const LocalBackendController({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    BackendShellRunner shellRunner = defaultBackendShellRunner,
    BackendProcessStarter processStarter = defaultBackendProcessStarter,
    BackendHealthGetter healthGetter = http.get,
    BackendClock clock = defaultBackendClock,
    bool enableAdbReverse = true,
  }) : _stateStore = stateStore,
       _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _clock = clock,
       _enableAdbReverse = enableAdbReverse;

  final LocalCliStateStore _stateStore;
  final BackendShellRunner _shellRunner;
  final BackendProcessStarter _processStarter;
  final BackendHealthGetter _healthGetter;
  final BackendClock _clock;
  final bool _enableAdbReverse;

  LocalBackendDependencies get _dependencies => LocalBackendDependencies(
    stateStore: _stateStore,
    shellRunner: _shellRunner,
    processStarter: _processStarter,
    healthGetter: _healthGetter,
    clock: _clock,
    enableAdbReverse: _enableAdbReverse,
  );

  Future<LocalBackendStartResult> start({
    required String repoRootPath,
    int port = 8080,
  }) => LocalBackendLifecycle(
    _dependencies,
  ).start(repoRootPath: repoRootPath, port: port);

  Future<LocalBackendStatusResult> status({required String repoRootPath}) =>
      LocalBackendLifecycle(_dependencies).status(repoRootPath: repoRootPath);

  Future<LocalBackendStopResult> stop({required String repoRootPath}) =>
      LocalBackendLifecycle(_dependencies).stop(repoRootPath: repoRootPath);

  Future<LocalBackendResetResult> resetLocal({required String repoRootPath}) =>
      resetTrackedLocalBackendArtifacts(
        _dependencies,
        repoRootPath: repoRootPath,
      );
}
