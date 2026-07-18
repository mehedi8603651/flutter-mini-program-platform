import 'dart:io';

import 'package:path/path.dart' as p;

import '../local_cli_state.dart';
import 'adb_reverse.dart';
import 'dependencies.dart';
import 'health.dart';
import 'launcher.dart';
import 'models.dart';
import 'process_control.dart';
import 'service_preparation.dart';

class LocalBackendLifecycle {
  const LocalBackendLifecycle(this.dependencies);

  final LocalBackendDependencies dependencies;

  LocalBackendHealthMonitor get _health =>
      LocalBackendHealthMonitor(dependencies);
  LocalBackendProcessControl get _process =>
      LocalBackendProcessControl(dependencies);

  Future<LocalBackendStartResult> start({
    required String repoRootPath,
    int port = 8080,
  }) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final serviceDirectoryPath = p.join(
      normalizedRepoRoot,
      'backend',
      'local_backend_service',
    );
    final apiRootPath = p.join(normalizedRepoRoot, 'backend', 'api');
    final serverScriptPath = p.join(serviceDirectoryPath, 'bin', 'server.dart');

    await assertLocalBackendPaths(
      serviceDirectoryPath: serviceDirectoryPath,
      apiRootPath: apiRootPath,
      serverScriptPath: serverScriptPath,
    );
    await ensureLocalBackendPackageConfig(dependencies, serviceDirectoryPath);

    final healthCheckUri = Uri.parse('http://127.0.0.1:$port/health');
    final previousState = await dependencies.stateStore.readBackendState(
      normalizedRepoRoot,
    );
    if (previousState != null) {
      final previousStatus = await status(repoRootPath: normalizedRepoRoot);
      if (previousStatus.processAlive && previousStatus.healthy) {
        return LocalBackendStartResult(
          state: previousState,
          alreadyRunning: true,
        );
      }

      if (previousStatus.processAlive) {
        throw LocalBackendControlException(
          'A recorded backend process is still alive but not healthy. '
          'Stop it or inspect the logs before starting again.\n'
          '${previousStatus.healthError ?? 'Health URL: ${previousState.healthCheckUrl}'}',
        );
      }

      await dependencies.stateStore.clearBackendState(normalizedRepoRoot);
    }

    final preExistingHealth = await _health.probe(healthCheckUri);
    if (preExistingHealth.healthy) {
      throw LocalBackendControlException(
        'A local artifact host is already responding at '
        '${healthCheckUri.toString()}, but no tracked local artifact host '
        'state was found. Stop the existing server or use a different --port.',
      );
    }

    final stateDirectory = await dependencies.stateStore.ensureStateDirectory(
      normalizedRepoRoot,
    );
    final stdoutLogPath = p.join(stateDirectory.path, 'backend.local.out.log');
    final stderrLogPath = p.join(stateDirectory.path, 'backend.local.err.log');
    final launcherScriptPath = p.join(
      stateDirectory.path,
      Platform.isWindows
          ? 'backend.local.runner.cmd'
          : 'backend.local.runner.sh',
    );

    await File(stdoutLogPath).writeAsString('');
    await File(stderrLogPath).writeAsString('');
    const launcher = LocalBackendLauncher();
    await launcher.writeScript(
      launcherScriptPath: launcherScriptPath,
      serviceDirectoryPath: serviceDirectoryPath,
      serverScriptPath: serverScriptPath,
      apiRootPath: apiRootPath,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      port: port,
    );

    final startedProcess = await dependencies.processStarter(
      executable: launcher.executable(),
      arguments: launcher.arguments(launcherScriptPath),
      workingDirectory: stateDirectory.path,
    );
    final state = LocalBackendState(
      pid: startedProcess.pid,
      port: port,
      bindHost: '0.0.0.0',
      healthCheckUrl: healthCheckUri.toString(),
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: dependencies.clock().toUtc().toIso8601String(),
    );

    final startupHealth = await _health.waitUntilHealthy(
      healthCheckUri,
      timeout: const Duration(seconds: 20),
    );
    if (!startupHealth.healthy) {
      await _process.terminate(startedProcess.pid);
      final stderrTail = await _health.readLogTail(stderrLogPath);
      final details = <String>[
        'Failed to confirm local artifact host health at '
            '${state.healthCheckUrl} within 20 seconds.',
        if (startupHealth.statusCode != null)
          'Last health status code: ${startupHealth.statusCode}',
        if (startupHealth.error != null)
          'Last health detail: ${startupHealth.error}',
        if (stderrTail.isNotEmpty) 'stderr tail:\n$stderrTail',
      ];
      throw LocalBackendControlException(details.join('\n'));
    }

    await dependencies.stateStore.writeBackendState(normalizedRepoRoot, state);
    final reversedDeviceIds = await LocalBackendAdbReverse(
      dependencies,
    ).configure(port: port);

    return LocalBackendStartResult(
      state: state,
      alreadyRunning: false,
      reversedDeviceIds: reversedDeviceIds,
    );
  }

  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final state = await dependencies.stateStore.readBackendState(
      normalizedRepoRoot,
    );
    if (state == null) {
      return const LocalBackendStatusResult(
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
          'Recorded backend PID is stale, but a backend is still responding at '
          '${state.healthCheckUrl}.';
    } else if (!processAlive && !health.healthy && healthError == null) {
      healthError = 'Recorded backend PID is no longer running.';
    }

    return LocalBackendStatusResult(
      state: state,
      hasState: true,
      processAlive: processAlive,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: healthError,
    );
  }

  Future<LocalBackendStopResult> stop({required String repoRootPath}) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final state = await dependencies.stateStore.readBackendState(
      normalizedRepoRoot,
    );
    if (state == null) {
      return const LocalBackendStopResult(
        hadState: false,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: false,
      );
    }

    final processAlive = await _process.isAlive(state.pid);
    if (!processAlive) {
      await dependencies.stateStore.clearBackendState(normalizedRepoRoot);
      return const LocalBackendStopResult(
        hadState: true,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: true,
      );
    }

    final stopResult = await _process.terminate(state.pid);
    if (stopResult.exitCode != 0) {
      final stillAlive = await _process.isAlive(state.pid);
      if (stillAlive) {
        final stderrText = '${stopResult.stderr}'.trim();
        throw LocalBackendControlException(
          stderrText.isEmpty
              ? 'Failed to stop backend PID ${state.pid}.'
              : 'Failed to stop backend PID ${state.pid}.\n$stderrText',
        );
      }
    }

    final stopped = await _health.waitUntilUnavailable(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    if (!stopped) {
      throw LocalBackendControlException(
        'Backend PID ${state.pid} was signaled to stop, but '
        '${state.healthCheckUrl} is still serving after 5 seconds.',
      );
    }

    await dependencies.stateStore.clearBackendState(normalizedRepoRoot);
    return const LocalBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }
}
