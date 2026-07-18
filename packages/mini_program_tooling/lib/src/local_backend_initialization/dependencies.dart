import '../local_cli_state.dart';

class LocalBackendInitializationDependencies {
  const LocalBackendInitializationDependencies({
    required this.stateStore,
    required this.templateRootPath,
  });

  final LocalCliStateStore stateStore;
  final String? templateRootPath;
}
