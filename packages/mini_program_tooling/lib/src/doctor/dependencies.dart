import 'dart:io';

import '../local_backend_controller.dart';
import '../local_cli_state.dart';
import '../mini_program_path_resolver.dart';

typedef DoctorShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class DoctorDependencies {
  const DoctorDependencies({
    required this.stateStore,
    required this.pathResolver,
    required this.backendController,
    required this.shellRunner,
    required this.workingDirectory,
  });

  final LocalCliStateStore stateStore;
  final MiniProgramPathResolver pathResolver;
  final LocalBackendController backendController;
  final DoctorShellRunner shellRunner;
  final String? workingDirectory;
}

Future<ProcessResult> defaultDoctorShellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) => Process.run(
  executable,
  arguments,
  workingDirectory: workingDirectory,
  environment: environment,
  runInShell: true,
);
