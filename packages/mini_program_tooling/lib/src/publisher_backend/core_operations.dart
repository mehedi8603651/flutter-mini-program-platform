part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterCoreOperations on PublisherBackendStarter {
  Future<PublisherBackendScaffoldResult> _scaffoldImpl(
    PublisherBackendScaffoldRequest request,
  ) async {
    if (!const <String>[
      'mock',
      'aws-lambda',
      'firebase-functions',
    ].contains(request.template)) {
      throw PublisherBackendException(
        'Unsupported publisher backend template: ${request.template}',
      );
    }
    if (!const <String>[
      _publisherBackendStorageBundled,
      _publisherBackendStorageDynamoDb,
      _publisherBackendStorageFirestore,
    ].contains(request.storageMode)) {
      throw PublisherBackendException(
        'Unsupported publisher backend storage mode: ${request.storageMode}',
      );
    }
    if (request.template == 'mock' &&
        request.storageMode != _publisherBackendStorageBundled) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --storage is not supported with '
        '--template mock.',
      );
    }
    if (request.template == 'aws-lambda' &&
        !const <String>[
          _publisherBackendStorageBundled,
          _publisherBackendStorageDynamoDb,
        ].contains(request.storageMode)) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --template aws-lambda supports '
        '--storage bundled or --storage dynamodb.',
      );
    }
    if (request.template == 'firebase-functions' &&
        request.storageMode != _publisherBackendStorageFirestore) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --template firebase-functions requires '
        '--storage firestore.',
      );
    }
    if (request.withStarterUi &&
        (request.template != 'firebase-functions' ||
            request.storageMode != _publisherBackendStorageFirestore)) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --with-starter-ui is only supported with '
        '--template firebase-functions --storage firestore.',
      );
    }
    final miniProgramRootPath = await _requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      switch (request.template) {
        'mock' => 'mock',
        'aws-lambda' => 'aws_lambda',
        'firebase-functions' => 'firebase_functions',
        _ => request.template,
      },
    );
    final createdPaths = <String>[];
    final files = switch (request.template) {
      'mock' => buildMockPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
      ),
      'aws-lambda' => buildAwsLambdaPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
        storageMode: request.storageMode,
      ),
      'firebase-functions' => buildFirebaseFunctionsPublisherBackendFiles(
        miniProgramRootPath: miniProgramRootPath,
      ),
      _ => throw PublisherBackendException(
        'Unsupported publisher backend template: ${request.template}',
      ),
    };
    for (final entry in files.entries) {
      await _writeManagedFile(
        filePath: p.join(backendRootPath, entry.key),
        contents: entry.value,
        force: request.force,
        createdPaths: createdPaths,
      );
    }
    final starterUi = request.withStarterUi
        ? await _writeFirebaseStarterUi(
            PublisherBackendFirebaseStarterUiRequest(
              miniProgramRootPath: miniProgramRootPath,
              force: true,
            ),
          )
        : null;
    createdPaths.sort();
    return PublisherBackendScaffoldResult(
      miniProgramRootPath: miniProgramRootPath,
      backendRootPath: backendRootPath,
      template: request.template,
      createdPaths: createdPaths,
      storageMode:
          request.template == 'aws-lambda' ||
              request.template == 'firebase-functions'
          ? request.storageMode
          : null,
      starterUi: starterUi,
    );
  }

  Future<PublisherBackendFirebaseStarterUiResult> _firebaseStarterUiImpl(
    PublisherBackendFirebaseStarterUiRequest request,
  ) => _writeFirebaseStarterUi(request);

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
          'A recorded publisher backend process is alive but not healthy. '
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
        'A publisher backend is already responding at $healthCheckUri, but no '
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
          'Failed to confirm publisher backend health at $healthCheckUri.',
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
          'Recorded publisher backend PID is stale, but a backend is still '
          'responding at ${state.healthCheckUrl}.';
    } else if (!processAlive && !health.healthy && healthError == null) {
      healthError = 'Recorded publisher backend PID is no longer running.';
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
            ? 'Failed to stop publisher backend PID ${state.pid}.'
            : 'Failed to stop publisher backend PID ${state.pid}.\n$stderrText',
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
