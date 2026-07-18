import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('publisher backend starter API remains available from the barrel', () {
    Future<ProcessResult> shellRunner(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    }) async => ProcessResult(1, 0, '', '');

    Future<StartedPublisherBackendProcess> processStarter({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    }) async => const StartedPublisherBackendProcess(pid: 1);

    Future<http.Response> healthGetter(Uri uri) async =>
        http.Response('offline', 503);
    DateTime clock() => DateTime.utc(2026, 7, 18);
    Future<void> delay(Duration duration) async {}

    final PublisherBackendShellRunner typedShellRunner = shellRunner;
    final PublisherBackendProcessStarter typedProcessStarter = processStarter;
    final PublisherBackendHealthGetter typedHealthGetter = healthGetter;
    final PublisherBackendClock typedClock = clock;
    final PublisherBackendDelay typedDelay = delay;
    final starter = PublisherBackendStarter(
      shellRunner: typedShellRunner,
      processStarter: typedProcessStarter,
      healthGetter: typedHealthGetter,
      clock: typedClock,
      delay: typedDelay,
    );
    const request = PublisherBackendScaffoldRequest(
      miniProgramRootPath: 'weather',
    );
    const state = PublisherBackendState(
      schemaVersion: 1,
      miniProgramRootPath: 'weather',
      backendRootPath: 'weather/backend/mock',
      pid: 1,
      port: 9090,
      bindHost: '0.0.0.0',
      healthCheckUrl: 'http://127.0.0.1:9090/health',
      stdoutLogPath: 'stdout.log',
      stderrLogPath: 'stderr.log',
      startedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    const scaffoldResult = PublisherBackendScaffoldResult(
      miniProgramRootPath: 'weather',
      backendRootPath: 'weather/backend/mock',
      template: 'mock',
      createdPaths: <String>[],
      storageMode: 'bundled',
    );
    const runResult = PublisherBackendRunResult(
      state: state,
      alreadyRunning: false,
    );
    const statusResult = PublisherBackendStatusResult(
      state: state,
      hasState: true,
      processAlive: true,
      healthy: true,
      healthStatusCode: 200,
    );
    const stopResult = PublisherBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
    const urls = PublisherBackendUrlsResult(port: 9090);
    const exception = PublisherBackendException('failure');

    expect(starter, isA<PublisherBackendStarter>());
    expect(request.template, 'mock');
    expect(scaffoldResult.storageMode, 'bundled');
    expect(runResult.state, same(state));
    expect(statusResult.healthStatusCode, 200);
    expect(stopResult.stopped, isTrue);
    expect(urls.androidEmulatorBaseUrl, 'http://10.0.2.2:9090/');
    expect(exception.toString(), 'failure');
  });
}
