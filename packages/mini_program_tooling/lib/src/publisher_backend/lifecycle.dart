import 'dart:io';

import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'health.dart';
import 'launcher.dart';
import 'models.dart';
import 'process_control.dart';
import 'state_store.dart';
import 'workspace.dart';

class PublisherBackendLifecycle {
  const PublisherBackendLifecycle(this.dependencies);

  final PublisherBackendDependencies dependencies;

  PublisherBackendHealthMonitor get _health =>
      PublisherBackendHealthMonitor(dependencies);
  PublisherBackendProcessControl get _process =>
      PublisherBackendProcessControl(dependencies);
  PublisherBackendStateStore get _stateStore =>
      const PublisherBackendStateStore();
  PublisherBackendWorkspace get _workspace => const PublisherBackendWorkspace();

  Future<PublisherBackendRunResult> run({
    required String miniProgramRootPath,
    int port = 9090,
  }) async {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend run --port must be 1-65535.',
      );
    }
    final rootPath = await _workspace.requireMiniProgramRoot(
      miniProgramRootPath,
    );
    final backendRootPath = p.join(rootPath, 'backend', 'mock');
    await _workspace.assertMockBackendPaths(backendRootPath);
    final previousState = await _stateStore.read(rootPath);
    if (previousState != null) {
      final previousStatus = await status(miniProgramRootPath: rootPath);
      if (previousStatus.processAlive && previousStatus.healthy) {
        return PublisherBackendRunResult(
          state: previousState,
          alreadyRunning: true,
        );
      }
      if (previousStatus.processAlive) {
        throw PublisherBackendException(
          'A recorded mock Publisher API process is alive but not healthy. '
          'Stop it or inspect logs before starting again.\n'
          '${previousStatus.healthError ?? previousState.healthCheckUrl}',
        );
      }
      await _stateStore.clear(rootPath);
    }

    final healthCheckUri = Uri.parse('http://127.0.0.1:$port/health');
    final preExisting = await _health.probe(healthCheckUri);
    if (preExisting.healthy) {
      throw PublisherBackendException(
        'A mock Publisher API is already responding at $healthCheckUri, but no '
        'tracked state was found. Stop that server or use another --port.',
      );
    }

    final stateDirectory = await _stateStore.ensureStateDirectory(rootPath);
    final stdoutLogPath = p.join(
      stateDirectory.path,
      'publisher_backend.local.out.log',
    );
    final stderrLogPath = p.join(
      stateDirectory.path,
      'publisher_backend.local.err.log',
    );
    final launcherScriptPath = p.join(
      stateDirectory.path,
      Platform.isWindows
          ? 'publisher_backend.local.runner.cmd'
          : 'publisher_backend.local.runner.sh',
    );
    await File(stdoutLogPath).writeAsString('');
    await File(stderrLogPath).writeAsString('');
    const launcher = PublisherBackendLauncher();
    await launcher.writeScript(
      launcherScriptPath: launcherScriptPath,
      backendRootPath: backendRootPath,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      port: port,
    );

    final startedProcess = await dependencies.processStarter(
      executable: launcher.executable(),
      arguments: launcher.arguments(launcherScriptPath),
      workingDirectory: stateDirectory.path,
    );
    final startupHealth = await _health.waitUntilHealthy(
      healthCheckUri,
      timeout: const Duration(seconds: 20),
    );
    if (!startupHealth.healthy) {
      await _process.terminate(startedProcess.pid);
      final stderrTail = await _health.readLogTail(stderrLogPath);
      throw PublisherBackendException(
        [
          'Failed to confirm mock Publisher API health at $healthCheckUri.',
          if (startupHealth.statusCode != null)
            'Last health status code: ${startupHealth.statusCode}',
          if (startupHealth.error != null)
            'Last health detail: ${startupHealth.error}',
          if (stderrTail.isNotEmpty) 'stderr tail:\n$stderrTail',
        ].join('\n'),
      );
    }

    final state = PublisherBackendState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: backendRootPath,
      pid: startedProcess.pid,
      port: port,
      bindHost: '0.0.0.0',
      healthCheckUrl: healthCheckUri.toString(),
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: dependencies.clock().toUtc().toIso8601String(),
    );
    await _stateStore.write(rootPath, state);
    return PublisherBackendRunResult(state: state, alreadyRunning: false);
  }

  Future<PublisherBackendStatusResult> status({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _workspace.requireMiniProgramRoot(
      miniProgramRootPath,
    );
    final state = await _stateStore.read(rootPath);
    if (state == null) {
      return const PublisherBackendStatusResult(
        state: null,
        hasState: false,
        processAlive: false,
        healthy: false,
      );
    }
    final processAlive = await _process.isAlive(state.pid);
    final health = await _health.probe(Uri.parse(state.healthCheckUrl));
    String? healthError = health.error;
    if (!processAlive && health.healthy) {
      healthError =
          'Recorded mock Publisher API PID is stale, but an API is still '
          'responding at ${state.healthCheckUrl}.';
    } else if (!processAlive && !health.healthy && healthError == null) {
      healthError = 'Recorded mock Publisher API PID is no longer running.';
    }
    return PublisherBackendStatusResult(
      state: state,
      hasState: true,
      processAlive: processAlive,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: healthError,
    );
  }

  Future<PublisherBackendStopResult> stop({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _workspace.requireMiniProgramRoot(
      miniProgramRootPath,
    );
    final state = await _stateStore.read(rootPath);
    if (state == null) {
      return const PublisherBackendStopResult(
        hadState: false,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: false,
      );
    }
    final processAlive = await _process.isAlive(state.pid);
    if (!processAlive) {
      await _stateStore.clear(rootPath);
      return const PublisherBackendStopResult(
        hadState: true,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: true,
      );
    }
    final stopResult = await _process.terminate(state.pid);
    if (stopResult.exitCode != 0 && await _process.isAlive(state.pid)) {
      final stderrText = '${stopResult.stderr}'.trim();
      throw PublisherBackendException(
        stderrText.isEmpty
            ? 'Failed to stop mock Publisher API PID ${state.pid}.'
            : 'Failed to stop mock Publisher API PID ${state.pid}.\n$stderrText',
      );
    }
    await _health.waitUntilUnavailable(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    await _stateStore.clear(rootPath);
    return const PublisherBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }
}
