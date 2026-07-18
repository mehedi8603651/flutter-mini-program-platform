import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('local backend public API remains available from the barrel', () {
    Future<ProcessResult> shellRunner(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    }) async => ProcessResult(1, 0, '', '');

    Future<StartedBackendProcess> processStarter({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    }) async => StartedBackendProcess(
      pid: 1,
      stdout: const Stream<List<int>>.empty(),
      stderr: const Stream<List<int>>.empty(),
      exitCode: Future<int>.value(0),
    );

    Future<http.Response> healthGetter(Uri uri) async =>
        http.Response('offline', 503);

    DateTime clock() => DateTime.utc(2026, 7, 18);

    final BackendShellRunner typedShellRunner = shellRunner;
    final BackendProcessStarter typedProcessStarter = processStarter;
    final BackendHealthGetter typedHealthGetter = healthGetter;
    final BackendClock typedClock = clock;
    final controller = LocalBackendController(
      shellRunner: typedShellRunner,
      processStarter: typedProcessStarter,
      healthGetter: typedHealthGetter,
      clock: typedClock,
      enableAdbReverse: false,
    );
    const startResult = LocalBackendStartResult(
      state: LocalBackendState(
        pid: 1,
        port: 8080,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:8080/health',
        stdoutLogPath: 'stdout.log',
        stderrLogPath: 'stderr.log',
        startedAtUtc: '2026-07-18T00:00:00.000Z',
      ),
      alreadyRunning: false,
    );
    const statusResult = LocalBackendStatusResult(
      state: null,
      hasState: false,
      processAlive: false,
      healthy: false,
    );
    const stopResult = LocalBackendStopResult(
      hadState: false,
      processWasAlive: false,
      stopped: false,
      clearedStaleState: false,
    );
    const resetResult = LocalBackendResetResult(removedPaths: <String>[]);
    const exception = LocalBackendControlException('failure');

    expect(controller, isA<LocalBackendController>());
    expect(startResult.state.port, 8080);
    expect(statusResult.hasState, isFalse);
    expect(stopResult.stopped, isFalse);
    expect(resetResult.removedPaths, isEmpty);
    expect(exception.toString(), 'failure');
  });
}
