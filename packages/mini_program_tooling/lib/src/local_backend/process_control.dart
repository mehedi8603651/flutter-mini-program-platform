import 'dart:convert';
import 'dart:io';

import 'dependencies.dart';
import 'models.dart';

Future<ProcessResult> defaultBackendShellRunner(
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

DateTime defaultBackendClock() => DateTime.now();

Future<StartedBackendProcess> defaultBackendProcessStarter({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );

  return StartedBackendProcess(
    pid: process.pid,
    stdout: const Stream<List<int>>.empty(),
    stderr: const Stream<List<int>>.empty(),
    exitCode: Future<int>.value(-1),
  );
}

class LocalBackendProcessControl {
  const LocalBackendProcessControl(this.dependencies);

  final LocalBackendDependencies dependencies;

  Future<ProcessResult?> tryShell(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await dependencies.shellRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return null;
    }
  }

  Future<bool> isAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await dependencies.shellRunner('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }

    final result = await dependencies.shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }

    final lines = const LineSplitter().convert('${result.stdout}'.trim());
    return lines.length > 1;
  }

  Future<ProcessResult> terminate(int pid) {
    if (Platform.isWindows) {
      return dependencies.shellRunner('taskkill', <String>[
        '/PID',
        '$pid',
        '/T',
        '/F',
      ]);
    }

    return dependencies.shellRunner('kill', <String>['$pid']);
  }
}
