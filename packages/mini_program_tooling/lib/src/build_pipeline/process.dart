import 'dart:io';

import 'models.dart';

Future<void> runMiniProgramBuildProcessOrThrow({
  required ProcessRunner processRunner,
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  Map<String, String>? environment,
  required String failureLabel,
}) async {
  final result = await processRunner(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );

  if (result.exitCode == 0) {
    return;
  }

  final stdoutText = '${result.stdout}'.trim();
  final stderrText = '${result.stderr}'.trim();
  final details = <String>[
    failureLabel,
    'Command: $executable ${arguments.join(' ')}',
    if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
    if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
  ].join('\n');

  throw MiniProgramBuildException(details);
}

Future<ProcessResult> defaultMiniProgramBuildProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: true,
  );
}
