part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterCoreOperations on PublisherBackendStarter {
  Future<PublisherBackendScaffoldResult> _scaffoldImpl(
    PublisherBackendScaffoldRequest request,
  ) async {
    if (request.template != 'mock') {
      throw PublisherBackendException(
        'Publisher API provider templates were removed. Use your own '
        'middle server and connect it with '
        '`miniprogram publisher-api contract init --publisher-api-url <url>`, '
        'or use `--template mock` for local API testing.',
      );
    }
    if (request.storageMode != _publisherBackendStorageBundled) {
      throw PublisherBackendException(
        'publisher-backend scaffold --storage is not supported. The mock '
        'publisher API uses bundled local JSON only; real storage belongs on '
        'your external middle server.',
      );
    }
    if (request.withStarterUi) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --with-starter-ui was removed. Author '
        'mini-program UI with provider-neutral backend API endpoints instead.',
      );
    }
    final miniProgramRootPath = await _requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(miniProgramRootPath, 'backend', 'mock');
    final createdPaths = <String>[];
    final files = buildMockPublisherBackendFiles(
      miniProgramRootPath: miniProgramRootPath,
    );
    for (final entry in files.entries) {
      await _writeManagedFile(
        filePath: p.join(backendRootPath, entry.key),
        contents: entry.value,
        force: request.force,
        createdPaths: createdPaths,
      );
    }
    createdPaths.sort();
    return PublisherBackendScaffoldResult(
      miniProgramRootPath: miniProgramRootPath,
      backendRootPath: backendRootPath,
      template: request.template,
      createdPaths: createdPaths,
      storageMode: request.storageMode,
    );
  }

  Future<PublisherBackendRunResult> _runImpl({
    required String miniProgramRootPath,
    int port = 9090,
  }) async {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend run --port must be 1-65535.',
      );
    }
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final backendRootPath = p.join(rootPath, 'backend', 'mock');
    await _assertMockBackendPaths(backendRootPath);
    final previousState = await _readState(rootPath);
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
      await _clearState(rootPath);
    }

    final healthCheckUri = Uri.parse('http://127.0.0.1:$port/health');
    final preExisting = await _probeHealth(healthCheckUri);
    if (preExisting.healthy) {
      throw PublisherBackendException(
        'A mock Publisher API is already responding at $healthCheckUri, but no '
        'tracked state was found. Stop that server or use another --port.',
      );
    }

    final stateDirectory = await _ensureStateDirectory(rootPath);
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
    await _writeLauncherScript(
      launcherScriptPath: launcherScriptPath,
      backendRootPath: backendRootPath,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      port: port,
    );

    final startedProcess = await _processStarter(
      executable: Platform.isWindows ? 'cmd.exe' : 'sh',
      arguments: Platform.isWindows
          ? <String>['/c', launcherScriptPath]
          : <String>[launcherScriptPath],
      workingDirectory: stateDirectory.path,
    );
    final startupHealth = await _waitForHealthCheck(
      healthCheckUri,
      timeout: const Duration(seconds: 20),
    );
    if (!startupHealth.healthy) {
      await _terminateProcess(startedProcess.pid);
      final stderrTail = await _readLogTail(stderrLogPath);
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
      startedAtUtc: _clock().toUtc().toIso8601String(),
    );
    await _writeState(rootPath, state);
    return PublisherBackendRunResult(state: state, alreadyRunning: false);
  }

  Future<PublisherBackendStatusResult> _statusImpl({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final state = await _readState(rootPath);
    if (state == null) {
      return const PublisherBackendStatusResult(
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

  Future<PublisherBackendStopResult> _stopImpl({
    required String miniProgramRootPath,
  }) async {
    final rootPath = await _requireMiniProgramRoot(miniProgramRootPath);
    final state = await _readState(rootPath);
    if (state == null) {
      return const PublisherBackendStopResult(
        hadState: false,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: false,
      );
    }
    final processAlive = await _isProcessAlive(state.pid);
    if (!processAlive) {
      await _clearState(rootPath);
      return const PublisherBackendStopResult(
        hadState: true,
        processWasAlive: false,
        stopped: false,
        clearedStaleState: true,
      );
    }
    final stopResult = await _terminateProcess(state.pid);
    if (stopResult.exitCode != 0 && await _isProcessAlive(state.pid)) {
      final stderrText = '${stopResult.stderr}'.trim();
      throw PublisherBackendException(
        stderrText.isEmpty
            ? 'Failed to stop mock Publisher API PID ${state.pid}.'
            : 'Failed to stop mock Publisher API PID ${state.pid}.\n$stderrText',
      );
    }
    await _waitForBackendUnavailable(
      Uri.parse(state.healthCheckUrl),
      timeout: const Duration(seconds: 5),
    );
    await _clearState(rootPath);
    return const PublisherBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  PublisherBackendUrlsResult _urlsImpl({int port = 9090}) {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend urls --port must be 1-65535.',
      );
    }
    return PublisherBackendUrlsResult(port: port);
  }
}
