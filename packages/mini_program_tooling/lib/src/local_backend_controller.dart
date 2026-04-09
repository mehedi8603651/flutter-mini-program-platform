import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

typedef BackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });
typedef BackendProcessStarter =
    Future<StartedBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef BackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef BackendClock = DateTime Function();

class LocalBackendControlException implements Exception {
  const LocalBackendControlException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackendStartResult {
  const LocalBackendStartResult({
    required this.state,
    required this.alreadyRunning,
  });

  final LocalBackendState state;
  final bool alreadyRunning;
}

class LocalBackendStatusResult {
  const LocalBackendStatusResult({
    required this.state,
    required this.hasState,
    required this.processAlive,
    required this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final LocalBackendState? state;
  final bool hasState;
  final bool processAlive;
  final bool healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class LocalBackendStopResult {
  const LocalBackendStopResult({
    required this.hadState,
    required this.processWasAlive,
    required this.stopped,
    required this.clearedStaleState,
  });

  final bool hadState;
  final bool processWasAlive;
  final bool stopped;
  final bool clearedStaleState;
}

class LocalBackendResetResult {
  const LocalBackendResetResult({
    required this.removedPaths,
  });

  final List<String> removedPaths;
}

class LocalBackendController {
  const LocalBackendController({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    BackendShellRunner shellRunner = _defaultShellRunner,
    BackendProcessStarter processStarter = _defaultProcessStarter,
    BackendHealthGetter healthGetter = http.get,
    BackendClock clock = _defaultClock,
  }) : _stateStore = stateStore,
       _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _clock = clock;

  final LocalCliStateStore _stateStore;
  final BackendShellRunner _shellRunner;
  final BackendProcessStarter _processStarter;
  final BackendHealthGetter _healthGetter;
  final BackendClock _clock;

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
    if (!await Directory(serviceDirectoryPath).exists()) {
      throw LocalBackendControlException(
        'Local backend service was not found: $serviceDirectoryPath',
      );
    }

    final previousState = await _stateStore.readBackendState(normalizedRepoRoot);
    if (previousState != null) {
      final previousStatus = await status(repoRootPath: normalizedRepoRoot);
      if (previousStatus.processAlive) {
        return LocalBackendStartResult(
          state: previousState,
          alreadyRunning: true,
        );
      }
      await _stateStore.clearBackendState(normalizedRepoRoot);
    }

    final stateDirectory = await _stateStore.ensureStateDirectory(
      normalizedRepoRoot,
    );
    final stdoutLogPath = p.join(stateDirectory.path, 'backend.local.out.log');
    final stderrLogPath = p.join(stateDirectory.path, 'backend.local.err.log');
    await File(stdoutLogPath).writeAsString('');
    await File(stderrLogPath).writeAsString('');

    final startedProcess = await _processStarter(
      executable: Platform.resolvedExecutable,
      arguments: <String>[
        'run',
        'bin/server.dart',
        '--host=0.0.0.0',
        '--port=$port',
      ],
      workingDirectory: serviceDirectoryPath,
    );
    final state = LocalBackendState(
      pid: startedProcess.pid,
      port: port,
      bindHost: '0.0.0.0',
      healthCheckUrl: 'http://127.0.0.1:$port/health',
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: _clock().toUtc().toIso8601String(),
    );

    final startupHealthy = await _waitForHealthCheck(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    if (!startupHealthy) {
      await _terminateProcess(startedProcess.pid);
      throw LocalBackendControlException(
        'Failed to confirm local backend health at ${state.healthCheckUrl} '
        'within 5 seconds.',
      );
    }

    await _stateStore.writeBackendState(normalizedRepoRoot, state);

    return LocalBackendStartResult(
      state: state,
      alreadyRunning: false,
    );
  }

  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final state = await _stateStore.readBackendState(normalizedRepoRoot);
    if (state == null) {
      return const LocalBackendStatusResult(
        state: null,
        hasState: false,
        processAlive: false,
        healthy: false,
      );
    }

    final processAlive = await _isProcessAlive(state.pid);
    if (!processAlive) {
      return LocalBackendStatusResult(
        state: state,
        hasState: true,
        processAlive: false,
        healthy: false,
        healthError: 'Recorded backend PID is no longer running.',
      );
    }

    try {
      final response = await _healthGetter(
        Uri.parse(state.healthCheckUrl),
      ).timeout(const Duration(seconds: 2));
      return LocalBackendStatusResult(
        state: state,
        hasState: true,
        processAlive: true,
        healthy: response.statusCode == 200,
        healthStatusCode: response.statusCode,
        healthError: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return LocalBackendStatusResult(
        state: state,
        hasState: true,
        processAlive: true,
        healthy: false,
        healthError: 'Health check timed out.',
      );
    } catch (error) {
      return LocalBackendStatusResult(
        state: state,
        hasState: true,
        processAlive: true,
        healthy: false,
        healthError: '$error',
      );
    }
  }

  Future<LocalBackendStopResult> stop({
    required String repoRootPath,
  }) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final state = await _stateStore.readBackendState(normalizedRepoRoot);
    if (state == null) {
      return const LocalBackendStopResult(
        hadState: false,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: false,
      );
    }

    final processAlive = await _isProcessAlive(state.pid);
    if (!processAlive) {
      await _stateStore.clearBackendState(normalizedRepoRoot);
      return const LocalBackendStopResult(
        hadState: true,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: true,
      );
    }

    final stopResult = await _terminateProcess(state.pid);
    if (stopResult.exitCode != 0) {
      final stderrText = '${stopResult.stderr}'.trim();
      throw LocalBackendControlException(
        stderrText.isEmpty
            ? 'Failed to stop backend PID ${state.pid}.'
            : 'Failed to stop backend PID ${state.pid}.\n$stderrText',
      );
    }

    await _stateStore.clearBackendState(normalizedRepoRoot);
    return const LocalBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  Future<LocalBackendResetResult> resetLocal({
    required String repoRootPath,
  }) async {
    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final artifactsState = await _stateStore.readPublishedArtifactsState(
      normalizedRepoRoot,
    );
    final removedPaths = <String>[];
    final backendApiRoot = p.join(normalizedRepoRoot, 'backend', 'api');
    final manifestRoot = p.join(backendApiRoot, 'manifests');
    final screenRoot = p.join(backendApiRoot, 'screens');

    final latestManifestPaths = artifactsState.records
        .map((record) => record.latestManifestPath)
        .toSet()
        .toList()
      ..sort();
    for (final filePath in latestManifestPaths) {
      final normalizedFilePath = p.normalize(p.absolute(filePath));
      _assertContainedPath(path: normalizedFilePath, root: manifestRoot);
      if (await File(normalizedFilePath).exists()) {
        await File(normalizedFilePath).delete();
        removedPaths.add(normalizedFilePath);
      }
      await _pruneEmptyParents(
        startDirectoryPath: p.dirname(normalizedFilePath),
        stopAtRootPath: manifestRoot,
      );
    }

    final versionedManifestPaths = artifactsState.records
        .map((record) => record.versionedManifestPath)
        .toSet()
        .toList()
      ..sort();
    for (final filePath in versionedManifestPaths) {
      final normalizedFilePath = p.normalize(p.absolute(filePath));
      _assertContainedPath(path: normalizedFilePath, root: manifestRoot);
      if (await File(normalizedFilePath).exists()) {
        await File(normalizedFilePath).delete();
        removedPaths.add(normalizedFilePath);
      }
      await _pruneEmptyParents(
        startDirectoryPath: p.dirname(normalizedFilePath),
        stopAtRootPath: manifestRoot,
      );
    }

    final screenDirectories = artifactsState.records
        .map((record) => record.screensDirectoryPath)
        .toSet()
        .toList()
      ..sort();
    for (final directoryPath in screenDirectories) {
      final normalizedDirectoryPath = p.normalize(p.absolute(directoryPath));
      _assertContainedPath(path: normalizedDirectoryPath, root: screenRoot);
      final directory = Directory(normalizedDirectoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        removedPaths.add(normalizedDirectoryPath);
      }
      await _pruneEmptyParents(
        startDirectoryPath: p.dirname(normalizedDirectoryPath),
        stopAtRootPath: screenRoot,
      );
    }

    await _stateStore.clearPublishedArtifactsState(normalizedRepoRoot);
    return LocalBackendResetResult(removedPaths: removedPaths);
  }

  Future<bool> _isProcessAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await _shellRunner(
        'tasklist',
        <String>['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
      );
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }

    final result = await _shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }

    final lines = const LineSplitter().convert('${result.stdout}'.trim());
    return lines.length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner(
        'taskkill',
        <String>['/PID', '$pid', '/T', '/F'],
      );
    }

    return _shellRunner('kill', <String>['$pid']);
  }

  Future<bool> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      try {
        final response = await _healthGetter(uri).timeout(
          const Duration(seconds: 1),
        );
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Keep retrying until timeout.
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return false;
  }

  Future<void> _pruneEmptyParents({
    required String startDirectoryPath,
    required String stopAtRootPath,
  }) async {
    var current = p.normalize(p.absolute(startDirectoryPath));
    final normalizedStopAtRootPath = p.normalize(p.absolute(stopAtRootPath));

    while (p.isWithin(normalizedStopAtRootPath, current) &&
        current != normalizedStopAtRootPath) {
      final directory = Directory(current);
      if (!await directory.exists()) {
        current = p.dirname(current);
        continue;
      }

      final entries = await directory.list(followLinks: false).toList();
      if (entries.isNotEmpty) {
        return;
      }

      await directory.delete();
      current = p.dirname(current);
    }
  }

  void _assertContainedPath({
    required String path,
    required String root,
  }) {
    final normalizedPath = p.normalize(p.absolute(path));
    final normalizedRoot = p.normalize(p.absolute(root));
    if (!p.isWithin(normalizedRoot, normalizedPath) &&
        normalizedPath != normalizedRoot) {
      throw LocalBackendControlException(
        'Local reset path escaped backend root: $normalizedPath',
      );
    }
  }

  static Future<ProcessResult> _defaultShellRunner(
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

  static DateTime _defaultClock() => DateTime.now();

  static Future<StartedBackendProcess> _defaultProcessStarter({
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
}

class StartedBackendProcess {
  const StartedBackendProcess({
    required this.pid,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final int pid;
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Future<int> exitCode;
}
