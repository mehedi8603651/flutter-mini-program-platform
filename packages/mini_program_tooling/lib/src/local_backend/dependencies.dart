import '../local_cli_state.dart';
import 'models.dart';

class LocalBackendDependencies {
  const LocalBackendDependencies({
    required this.stateStore,
    required this.shellRunner,
    required this.processStarter,
    required this.healthGetter,
    required this.clock,
    required this.enableAdbReverse,
  });

  final LocalCliStateStore stateStore;
  final BackendShellRunner shellRunner;
  final BackendProcessStarter processStarter;
  final BackendHealthGetter healthGetter;
  final BackendClock clock;
  final bool enableAdbReverse;
}
