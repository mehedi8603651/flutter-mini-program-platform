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
    this.reversedDeviceIds = const <String>[],
  });

  final LocalBackendState state;
  final bool alreadyRunning;
  final List<String> reversedDeviceIds;
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
  const LocalBackendResetResult({required this.removedPaths});

  final List<String> removedPaths;
}

class LocalBackendController {
  const LocalBackendController({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    BackendShellRunner shellRunner = _defaultShellRunner,
    BackendProcessStarter processStarter = _defaultProcessStarter,
    BackendHealthGetter healthGetter = http.get,
    BackendClock clock = _defaultClock,
    bool enableAdbReverse = true,
  }) : _stateStore = stateStore,
       _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _clock = clock,
       _enableAdbReverse = enableAdbReverse;

  final LocalCliStateStore _stateStore;
  final BackendShellRunner _shellRunner;
  final BackendProcessStarter _processStarter;
  final BackendHealthGetter _healthGetter;
  final BackendClock _clock;
  final bool _enableAdbReverse;

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

    await _assertBackendPaths(
      serviceDirectoryPath: serviceDirectoryPath,
      apiRootPath: apiRootPath,
      serverScriptPath: serverScriptPath,
    );
    await _ensurePackageConfig(serviceDirectoryPath);

    final healthCheckUri = Uri.parse('http://127.0.0.1:$port/health');
    final previousState = await _stateStore.readBackendState(
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

      await _stateStore.clearBackendState(normalizedRepoRoot);
    }

    final preExistingHealth = await _probeHealth(healthCheckUri);
    if (preExistingHealth.healthy) {
      throw LocalBackendControlException(
        'A backend is already responding at ${healthCheckUri.toString()}, '
        'but no tracked local backend state was found. Stop the existing '
        'server or use a different --port.',
      );
    }

    final stateDirectory = await _stateStore.ensureStateDirectory(
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
    await _writeLauncherScript(
      launcherScriptPath: launcherScriptPath,
      serviceDirectoryPath: serviceDirectoryPath,
      serverScriptPath: serverScriptPath,
      apiRootPath: apiRootPath,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      port: port,
    );

    final startedProcess = await _processStarter(
      executable: _launcherExecutable(),
      arguments: _launcherArguments(launcherScriptPath),
      workingDirectory: stateDirectory.path,
    );
    final state = LocalBackendState(
      pid: startedProcess.pid,
      port: port,
      bindHost: '0.0.0.0',
      healthCheckUrl: healthCheckUri.toString(),
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: _clock().toUtc().toIso8601String(),
    );

    final startupHealth = await _waitForHealthCheck(
      healthCheckUri,
      timeout: const Duration(seconds: 20),
    );
    if (!startupHealth.healthy) {
      await _terminateProcess(startedProcess.pid);
      final stderrTail = await _readLogTail(stderrLogPath);
      final details = <String>[
        'Failed to confirm local backend health at ${state.healthCheckUrl} within 20 seconds.',
        if (startupHealth.statusCode != null)
          'Last health status code: ${startupHealth.statusCode}',
        if (startupHealth.error != null)
          'Last health detail: ${startupHealth.error}',
        if (stderrTail.isNotEmpty) 'stderr tail:\n$stderrTail',
      ];
      throw LocalBackendControlException(details.join('\n'));
    }

    await _stateStore.writeBackendState(normalizedRepoRoot, state);
    final reversedDeviceIds = await _configureAdbReverse(port: port);

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
    final health = await _probeHealth(Uri.parse(state.healthCheckUrl));

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
      final stillAlive = await _isProcessAlive(state.pid);
      if (stillAlive) {
        final stderrText = '${stopResult.stderr}'.trim();
        throw LocalBackendControlException(
          stderrText.isEmpty
              ? 'Failed to stop backend PID ${state.pid}.'
              : 'Failed to stop backend PID ${state.pid}.\n$stderrText',
        );
      }
    }

    final stopped = await _waitForBackendUnavailable(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    if (!stopped) {
      throw LocalBackendControlException(
        'Backend PID ${state.pid} was signaled to stop, but '
        '${state.healthCheckUrl} is still serving after 5 seconds.',
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

    final latestManifestPaths =
        artifactsState.records
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

    final versionedManifestPaths =
        artifactsState.records
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

    final screenDirectories =
        artifactsState.records
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

  Future<void> _assertBackendPaths({
    required String serviceDirectoryPath,
    required String apiRootPath,
    required String serverScriptPath,
  }) async {
    if (!await Directory(serviceDirectoryPath).exists()) {
      throw LocalBackendControlException(
        'Local backend service was not found: $serviceDirectoryPath',
      );
    }
    if (!await Directory(apiRootPath).exists()) {
      throw LocalBackendControlException(
        'Local backend api root was not found: $apiRootPath',
      );
    }
    if (!await File(serverScriptPath).exists()) {
      throw LocalBackendControlException(
        'Local backend entrypoint was not found: $serverScriptPath',
      );
    }
  }

  Future<void> _ensurePackageConfig(String serviceDirectoryPath) async {
    final pubspecPath = p.join(serviceDirectoryPath, 'pubspec.yaml');
    final packageConfigPath = p.join(
      serviceDirectoryPath,
      '.dart_tool',
      'package_config.json',
    );
    if (!await File(pubspecPath).exists() ||
        await File(packageConfigPath).exists()) {
      return;
    }

    final result = await _shellRunner(
      Platform.resolvedExecutable,
      const <String>['pub', 'get'],
      workingDirectory: serviceDirectoryPath,
    );
    if (result.exitCode == 0) {
      return;
    }

    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    throw LocalBackendControlException(
      [
        'Failed to prepare backend/local_backend_service before launch.',
        'Command: ${Platform.resolvedExecutable} pub get',
        if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
        if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
      ].join('\n'),
    );
  }

  Future<void> _writeLauncherScript({
    required String launcherScriptPath,
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final content = Platform.isWindows
        ? _buildWindowsLauncherScript(
            serviceDirectoryPath: serviceDirectoryPath,
            serverScriptPath: serverScriptPath,
            apiRootPath: apiRootPath,
            stdoutLogPath: stdoutLogPath,
            stderrLogPath: stderrLogPath,
            port: port,
          )
        : _buildUnixLauncherScript(
            serviceDirectoryPath: serviceDirectoryPath,
            serverScriptPath: serverScriptPath,
            apiRootPath: apiRootPath,
            stdoutLogPath: stdoutLogPath,
            stderrLogPath: stderrLogPath,
            port: port,
          );
    await File(launcherScriptPath).writeAsString(content);
  }

  String _buildWindowsLauncherScript({
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) {
    final quotedDart = _quoteForCmd(Platform.resolvedExecutable);
    final quotedServiceDirectory = _quoteForCmd(serviceDirectoryPath);
    final quotedServerScript = _quoteForCmd(serverScriptPath);
    final quotedHostArg = _quoteForCmd('--host=0.0.0.0');
    final quotedPortArg = _quoteForCmd('--port=$port');
    final quotedApiRootArg = _quoteForCmd('--api-root=$apiRootPath');
    final quotedStdoutLog = _quoteForCmd(stdoutLogPath);
    final quotedStderrLog = _quoteForCmd(stderrLogPath);

    return [
      '@echo off',
      'setlocal',
      'cd /d $quotedServiceDirectory',
      '$quotedDart $quotedServerScript $quotedHostArg $quotedPortArg '
          '$quotedApiRootArg 1>>$quotedStdoutLog 2>>$quotedStderrLog',
    ].join('\r\n');
  }

  String _buildUnixLauncherScript({
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) {
    final quotedDart = _quoteForSh(Platform.resolvedExecutable);
    final quotedServiceDirectory = _quoteForSh(serviceDirectoryPath);
    final quotedServerScript = _quoteForSh(serverScriptPath);
    final quotedHostArg = _quoteForSh('--host=0.0.0.0');
    final quotedPortArg = _quoteForSh('--port=$port');
    final quotedApiRootArg = _quoteForSh('--api-root=$apiRootPath');
    final quotedStdoutLog = _quoteForSh(stdoutLogPath);
    final quotedStderrLog = _quoteForSh(stderrLogPath);

    return [
      '#!/usr/bin/env sh',
      'set -eu',
      'cd $quotedServiceDirectory',
      'exec $quotedDart $quotedServerScript $quotedHostArg $quotedPortArg '
          '$quotedApiRootArg >>$quotedStdoutLog 2>>$quotedStderrLog',
      '',
    ].join('\n');
  }

  String _launcherExecutable() => Platform.isWindows ? 'cmd.exe' : 'sh';

  List<String> _launcherArguments(String launcherScriptPath) =>
      Platform.isWindows
      ? <String>['/c', launcherScriptPath]
      : <String>[launcherScriptPath];

  String _quoteForCmd(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _quoteForSh(String value) {
    final escaped = value.replaceAll("'", r"'\''");
    return "'$escaped'";
  }

  Future<List<String>> _configureAdbReverse({required int port}) async {
    if (!_enableAdbReverse) {
      return const <String>[];
    }

    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      return const <String>[];
    }

    final devicesResult = await _tryShell(adbExecutable, const <String>[
      'devices',
    ]);
    if (devicesResult == null || devicesResult.exitCode != 0) {
      return const <String>[];
    }

    final deviceIds = const LineSplitter()
        .convert('${devicesResult.stdout}')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('List of devices attached'),
        )
        .map((line) => line.split(RegExp(r'\s+')))
        .where((parts) => parts.length >= 2 && parts[1] == 'device')
        .map((parts) => parts.first)
        .toList();

    if (deviceIds.isEmpty) {
      return const <String>[];
    }

    final reversedDeviceIds = <String>[];
    for (final deviceId in deviceIds) {
      final reverseResult = await _tryShell(adbExecutable, <String>[
        '-s',
        deviceId,
        'reverse',
        'tcp:$port',
        'tcp:$port',
      ]);
      if (reverseResult != null && reverseResult.exitCode == 0) {
        reversedDeviceIds.add(deviceId);
      }
    }

    return reversedDeviceIds;
  }

  Future<String?> _resolveAdbExecutable() async {
    final candidates = <String>[
      if (Platform.isWindows)
        p.join(
          _resolveLocalAppDataDirectoryPath(),
          'Android',
          'Sdk',
          'platform-tools',
          'adb.exe',
        ),
      if (Platform.environment['ANDROID_SDK_ROOT'] case final sdkRoot?
          when sdkRoot.trim().isNotEmpty)
        p.join(
          sdkRoot,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      if (Platform.environment['ANDROID_HOME'] case final androidHome?
          when androidHome.trim().isNotEmpty)
        p.join(
          androidHome,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      Platform.isWindows ? 'adb.exe' : 'adb',
    ];

    for (final candidate in candidates.toSet()) {
      final result = await _tryShell(candidate, const <String>['version']);
      if (result != null && result.exitCode == 0) {
        return candidate;
      }
    }

    return null;
  }

  Future<ProcessResult?> _tryShell(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await _shellRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return null;
    }
  }

  Future<bool> _isProcessAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await _shellRunner('tasklist', <String>[
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

    final result = await _shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }

    final lines = const LineSplitter().convert('${result.stdout}'.trim());
    return lines.length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner('taskkill', <String>['/PID', '$pid', '/T', '/F']);
    }

    return _shellRunner('kill', <String>['$pid']);
  }

  Future<_BackendHealthCheckResult> _probeHealth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      return _BackendHealthCheckResult(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const _BackendHealthCheckResult(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return _BackendHealthCheckResult(healthy: false, error: '$error');
    }
  }

  Future<_BackendHealthCheckResult> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    _BackendHealthCheckResult lastResult = const _BackendHealthCheckResult(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );

    while (_clock().isBefore(deadline)) {
      lastResult = await _probeHealth(uri, timeout: const Duration(seconds: 1));
      if (lastResult.healthy) {
        return lastResult;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return lastResult;
  }

  Future<bool> _waitForBackendUnavailable(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      final result = await _probeHealth(
        uri,
        timeout: const Duration(milliseconds: 750),
      );
      if (!result.healthy) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final finalProbe = await _probeHealth(
      uri,
      timeout: const Duration(milliseconds: 750),
    );
    return !finalProbe.healthy;
  }

  Future<String> _readLogTail(String filePath, {int lineCount = 20}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }

    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return '';
    }
    final startIndex = lines.length > lineCount ? lines.length - lineCount : 0;
    return lines.sublist(startIndex).join('\n').trim();
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

  void _assertContainedPath({required String path, required String root}) {
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

  static String _resolveLocalAppDataDirectoryPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return localAppData;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'AppData', 'Local');
    }

    return Directory.current.path;
  }

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

class _BackendHealthCheckResult {
  const _BackendHealthCheckResult({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}
