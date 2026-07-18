import 'dart:io';

import 'models.dart';
import 'validation.dart';

Future<int> defaultMiniProgramHostProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<MiniProgramHostRunResult> runMiniProgramHost(
  MiniProgramHostRunRequest request, {
  required MiniProgramHostProcessRunner processRunner,
}) async {
  final projectRootPath = await validateHostProject(
    request.projectRootPath,
    requireRuntimeSetup: true,
  );
  final trimmedBackendApiBaseUrl = request.backendApiBaseUrl.trim();

  final invocation = <String>[
    'run',
    '-d',
    request.deviceId,
    if (trimmedBackendApiBaseUrl.isNotEmpty)
      '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=$trimmedBackendApiBaseUrl',
  ];
  final exitCode = await processRunner(
    'flutter',
    invocation,
    workingDirectory: projectRootPath,
  );

  return MiniProgramHostRunResult(
    projectRootPath: projectRootPath,
    deviceId: request.deviceId,
    backendApiBaseUrl: trimmedBackendApiBaseUrl,
    invocation: invocation,
    exitCode: exitCode,
  );
}
