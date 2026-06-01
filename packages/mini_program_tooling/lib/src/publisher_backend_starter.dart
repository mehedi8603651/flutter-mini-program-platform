import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

part 'publisher_backend/models.dart';
part 'publisher_backend/internal_models.dart';
part 'publisher_backend/generated_files.dart';
part 'publisher_backend/starter_helpers.dart';
part 'publisher_backend/firebase_starter_ui.dart';
part 'publisher_backend/firebase_helpers.dart';
part 'publisher_backend/aws_helpers.dart';
part 'publisher_backend/runtime_smoke_helpers.dart';

class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner = _defaultShellRunner,
    PublisherBackendProcessStarter processStarter = _defaultProcessStarter,
    PublisherBackendHealthGetter healthGetter = http.get,
    PublisherBackendPostRequester postRequester = _defaultPostRequester,
    PublisherBackendHttpRequester httpRequester = _defaultHttpRequester,
    PublisherBackendFirebaseAccessTokenProvider firebaseAccessTokenProvider =
        _defaultFirebaseAccessTokenProvider,
    PublisherBackendClock clock = _defaultClock,
    PublisherBackendDelay delay = _defaultDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _postRequester = postRequester,
       _httpRequester = httpRequester,
       _firebaseAccessTokenProvider = firebaseAccessTokenProvider,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendPostRequester _postRequester;
  final PublisherBackendHttpRequester _httpRequester;
  final PublisherBackendFirebaseAccessTokenProvider
  _firebaseAccessTokenProvider;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  Future<PublisherBackendScaffoldResult> scaffold(
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

  Future<PublisherBackendFirebaseStarterUiResult> firebaseStarterUi(
    PublisherBackendFirebaseStarterUiRequest request,
  ) => _writeFirebaseStarterUi(request);

  Future<PublisherBackendRunResult> run({
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

  Future<PublisherBackendStatusResult> status({
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

  Future<PublisherBackendStopResult> stop({
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

  PublisherBackendUrlsResult urls({int port = 9090}) {
    if (port <= 0 || port > 65535) {
      throw const PublisherBackendException(
        'publisher-backend urls --port must be 1-65535.',
      );
    }
    return PublisherBackendUrlsResult(port: port);
  }

  Future<PublisherBackendAwsDeployResult> awsDeploy(
    PublisherBackendAwsDeployRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    await _assertAwsBackendPaths(settings.backendRootPath);
    await _runSamCommand(settings, <String>[
      'build',
      '--template-file',
      p.join(settings.backendRootPath, 'template.yaml'),
    ], workingDirectory: settings.backendRootPath);
    await _runSamCommand(settings, <String>[
      'deploy',
      '--template-file',
      p.join(settings.backendRootPath, 'template.yaml'),
      '--stack-name',
      settings.stackName,
      '--region',
      settings.region,
      '--capabilities',
      'CAPABILITY_IAM',
      '--s3-bucket',
      settings.samS3Bucket,
      '--parameter-overrides',
      'StageName=${settings.stageName}',
      '--no-confirm-changeset',
      '--no-fail-on-empty-changeset',
    ], workingDirectory: settings.backendRootPath);

    final stack = await _describeStack(settings);
    if (stack == null) {
      throw const PublisherBackendException(
        'SAM deploy finished but the publisher backend stack could not be described.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    final healthUrl = outputs['PublisherBackendHealthUrl'];
    final health = healthUrl == null || healthUrl.trim().isEmpty
        ? const _PublisherBackendHealth(healthy: false)
        : await _waitForHealthCheck(
            Uri.parse(healthUrl),
            timeout: _awsDeployHealthWaitTimeout,
            attemptTimeout: _awsDeployHealthAttemptTimeout,
            retryDelay: _awsDeployHealthRetryDelay,
          );
    final deployedAtUtc = _clock().toUtc().toIso8601String();
    final state = PublisherBackendAwsState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: settings.backendRootPath,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      samS3Bucket: settings.samS3Bucket,
      outputs: outputs,
      deployedAtUtc: deployedAtUtc,
    );
    await _writeAwsState(rootPath, state);
    return PublisherBackendAwsDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      samS3Bucket: settings.samS3Bucket,
      backendRootPath: settings.backendRootPath,
      miniProgramRootPath: rootPath,
      outputs: outputs,
      backendBaseUrl: outputs['PublisherBackendBaseUrl'],
      healthUrl: outputs['PublisherBackendHealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      deployedAtUtc: deployedAtUtc,
    );
  }

  Future<PublisherBackendAwsStatusResult> awsStatus(
    PublisherBackendAwsStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final state = await _readAwsState(rootPath);
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        state: state,
        outputs: const <String, String>{},
      );
    }
    final outputs = _extractStackOutputs(stack);
    final healthUrl = outputs['PublisherBackendHealthUrl'];
    final health = healthUrl == null || healthUrl.trim().isEmpty
        ? const _PublisherBackendHealth(healthy: false)
        : await _probeHealth(Uri.parse(healthUrl));
    return PublisherBackendAwsStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      state: state,
      stackStatus: stack['StackStatus']?.toString(),
      stackStatusReason: stack['StackStatusReason']?.toString(),
      outputs: outputs,
      backendBaseUrl: outputs['PublisherBackendBaseUrl'],
      healthUrl: outputs['PublisherBackendHealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
    );
  }

  Future<PublisherBackendAwsOutputsResult> awsOutputs(
    PublisherBackendAwsOutputsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      throw PublisherBackendException(
        'AWS publisher backend stack "${settings.stackName}" was not found in '
        'region "${settings.region}". Run `miniprogram publisher-backend aws deploy` first.',
      );
    }
    return PublisherBackendAwsOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      outputs: _extractStackOutputs(stack),
    );
  }

  Future<PublisherBackendAwsSmokeResult> awsSmoke(
    PublisherBackendAwsSmokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        passed: false,
        routes: const <PublisherBackendAwsSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final backendBaseUrl = outputs['PublisherBackendBaseUrl']?.trim();
    if (backendBaseUrl == null || backendBaseUrl.isEmpty) {
      return PublisherBackendAwsSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        backendBaseUrl: backendBaseUrl,
        passed: false,
        routes: const <PublisherBackendAwsSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        error: 'PublisherBackendBaseUrl output is missing.',
      );
    }

    final baseUri = Uri.parse(backendBaseUrl);
    final routes = <PublisherBackendAwsSmokeRouteResult>[];
    for (final path in _publisherBackendAwsSmokeRoutePaths) {
      routes.add(
        await _probeSmokeRoute(
          method: 'GET',
          path: path,
          uri: _resolveBackendRoute(baseUri, path),
        ),
      );
    }
    if (request.includeWrite) {
      routes.add(
        await _probeSmokeWriteRoute(
          uri: _resolveBackendRoute(baseUri, '/coupon/redeem'),
          couponId: request.writeCouponId,
          userId: request.writeUserId,
        ),
      );
    }
    final passed = routes.every((route) => route.passed);
    return PublisherBackendAwsSmokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      backendBaseUrl: backendBaseUrl,
      passed: passed,
      routes: routes,
      includeWrite: request.includeWrite,
    );
  }

  Future<PublisherBackendFirebaseDeployResult> firebaseDeploy(
    PublisherBackendFirebaseDeployRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    await _assertFirebaseBackendPaths(settings.backendRootPath);
    final dependenciesInstalled = await _ensureFirebaseDependencies(settings);
    await _writeFirebaseEnvFile(settings);
    await _runFirebaseCommand(<String>[
      'deploy',
      '--only',
      'functions:${settings.functionName}',
      '--project',
      settings.projectId,
    ], workingDirectory: settings.backendRootPath);

    var publicInvokerConfigured = false;
    var publicInvokerChanged = false;
    String? publicInvokerError;
    if (request.configurePublicInvoker) {
      try {
        final publicInvoker = await _ensureFirebasePublicInvoker(settings);
        publicInvokerConfigured = publicInvoker.configured;
        publicInvokerChanged = publicInvoker.changed;
      } on PublisherBackendException catch (error) {
        publicInvokerError = error.message;
      }
    }

    var authTokenCreatorConfigured = false;
    var authTokenCreatorChanged = false;
    String? authTokenCreatorServiceAccount;
    String? authTokenCreatorError;
    if (settings.authWebApiKey?.trim().isNotEmpty == true) {
      try {
        final tokenCreator = await _ensureFirebaseAuthTokenCreator(settings);
        authTokenCreatorConfigured = tokenCreator.configured;
        authTokenCreatorChanged = tokenCreator.changed;
        authTokenCreatorServiceAccount = tokenCreator.serviceAccountEmail;
      } on PublisherBackendException catch (error) {
        authTokenCreatorError = error.message;
      }
    }

    final outputs = settings.outputs;
    final health = await _waitForHealthCheck(
      Uri.parse(settings.healthUrl),
      timeout: _firebaseDeployHealthWaitTimeout,
      attemptTimeout: _firebaseDeployHealthAttemptTimeout,
      retryDelay: _firebaseDeployHealthRetryDelay,
    );
    final deployedAtUtc = _clock().toUtc().toIso8601String();
    final state = PublisherBackendFirebaseState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      functionUrl: settings.functionUrl,
      outputs: outputs,
      deployedAtUtc: deployedAtUtc,
    );
    await _writeFirebaseState(rootPath, state);
    return PublisherBackendFirebaseDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      miniProgramRootPath: rootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      publicInvokerConfigured: publicInvokerConfigured,
      publicInvokerChanged: publicInvokerChanged,
      publicInvokerError: publicInvokerError,
      authTokenCreatorConfigured: authTokenCreatorConfigured,
      authTokenCreatorChanged: authTokenCreatorChanged,
      authTokenCreatorServiceAccount: authTokenCreatorServiceAccount,
      authTokenCreatorError: authTokenCreatorError,
      deployedAtUtc: deployedAtUtc,
      dependenciesInstalled: dependenciesInstalled,
      outputs: outputs,
    );
  }

  Future<PublisherBackendFirebaseStatusResult> firebaseStatus(
    PublisherBackendFirebaseStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final state = await _readFirebaseState(rootPath);
    final scaffoldExists = await _firebaseBackendPathsExist(
      settings.backendRootPath,
    );
    final health = scaffoldExists
        ? await _probeHealth(Uri.parse(settings.healthUrl))
        : const _PublisherBackendHealth(
            healthy: false,
            error:
                'Firebase Functions publisher backend scaffold was not found.',
          );
    return PublisherBackendFirebaseStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      scaffoldExists: scaffoldExists,
      state: state,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseOutputsResult> firebaseOutputs(
    PublisherBackendFirebaseOutputsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    return PublisherBackendFirebaseOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseAuthStatusResult> firebaseAuthStatus(
    PublisherBackendFirebaseAuthStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final authServiceFile = File(
      p.join(settings.functionsRootPath, 'auth_service.js'),
    );
    final routerFile = File(p.join(settings.functionsRootPath, 'router.js'));
    final packageJsonFile = File(
      p.join(settings.functionsRootPath, 'package.json'),
    );
    final envFile = File(p.join(settings.functionsRootPath, '.env'));

    final scaffoldExists = await _firebaseBackendPathsExist(
      settings.backendRootPath,
    );
    final authServiceFileExists = await authServiceFile.exists();
    final routerFileExists = await routerFile.exists();
    final packageJsonFileExists = await packageJsonFile.exists();
    final envFileExists = await envFile.exists();
    final routerSource = routerFileExists
        ? await routerFile.readAsString()
        : '';
    final packageSource = packageJsonFileExists
        ? await packageJsonFile.readAsString()
        : '';
    final envSource = envFileExists ? await envFile.readAsString() : '';

    const authRouteSnippets = <String>[
      'GET /auth/session',
      'POST /auth/email/sign-up',
      'POST /auth/email/sign-in',
      'POST /auth/refresh',
      'POST /auth/sign-out',
    ];
    final routerAuthRoutesReady = authRouteSnippets.every(
      routerSource.contains,
    );
    final routerAllowsAuthorizationHeader = routerSource.toLowerCase().contains(
      'authorization',
    );
    final packageJsonHasFirebaseAdmin = packageSource.contains(
      '"firebase-admin"',
    );
    final packageJsonHasFirebaseFunctions = packageSource.contains(
      '"firebase-functions"',
    );
    final envAuthKeyConfigured = envSource
        .split('\n')
        .map((line) => line.trim())
        .any(
          (line) =>
              line.startsWith('PUBLISHER_AUTH_WEB_API_KEY=') &&
              line.substring('PUBLISHER_AUTH_WEB_API_KEY='.length).isNotEmpty,
        );
    final envUsesReservedAuthKey = envSource
        .split('\n')
        .map((line) => line.trim())
        .any((line) => line.startsWith('FIREBASE_AUTH_WEB_API_KEY='));

    final issues = <String>[];
    final warnings = <String>[];
    if (settings.authWebApiKey?.trim().isNotEmpty != true) {
      issues.add(
        'Firebase environment is missing --auth-web-api-key. Re-run `miniprogram env configure ${settings.environmentName} --provider firebase ... --auth-web-api-key <firebase-web-api-key>`.',
      );
    }
    if (!scaffoldExists) {
      issues.add(
        'Firebase Functions scaffold is missing. Run `miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }
    if (!authServiceFileExists) {
      issues.add(
        'Generated auth service is missing: ${authServiceFile.path}. Re-scaffold with current tooling or copy the 0.3.43+ Firebase auth files.',
      );
    }
    if (!routerFileExists) {
      issues.add('Generated router is missing: ${routerFile.path}.');
    } else {
      if (!routerAuthRoutesReady) {
        issues.add(
          'Generated router is missing one or more publisher auth routes.',
        );
      }
      if (!routerAllowsAuthorizationHeader) {
        issues.add('Generated router CORS headers do not allow Authorization.');
      }
    }
    if (!packageJsonFileExists) {
      issues.add('Functions package.json is missing: ${packageJsonFile.path}.');
    } else {
      if (!packageJsonHasFirebaseAdmin) {
        issues.add('Functions package.json is missing firebase-admin.');
      }
      if (!packageJsonHasFirebaseFunctions) {
        issues.add('Functions package.json is missing firebase-functions.');
      }
    }
    if (!envFileExists) {
      warnings.add(
        'Functions .env was not found yet. `publisher-backend firebase deploy` writes PUBLISHER_AUTH_WEB_API_KEY before deployment.',
      );
    } else if (!envAuthKeyConfigured) {
      warnings.add(
        'Functions .env does not contain PUBLISHER_AUTH_WEB_API_KEY. Re-run `publisher-backend firebase deploy` after configuring --auth-web-api-key.',
      );
    }
    if (envUsesReservedAuthKey) {
      issues.add(
        'Functions .env still contains reserved FIREBASE_AUTH_WEB_API_KEY. Remove it and use PUBLISHER_AUTH_WEB_API_KEY.',
      );
    }

    return PublisherBackendFirebaseAuthStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      authWebApiKeyConfigured:
          settings.authWebApiKey?.trim().isNotEmpty == true,
      scaffoldExists: scaffoldExists,
      authServiceFileExists: authServiceFileExists,
      routerFileExists: routerFileExists,
      routerAuthRoutesReady: routerAuthRoutesReady,
      routerAllowsAuthorizationHeader: routerAllowsAuthorizationHeader,
      packageJsonFileExists: packageJsonFileExists,
      packageJsonHasFirebaseAdmin: packageJsonHasFirebaseAdmin,
      packageJsonHasFirebaseFunctions: packageJsonHasFirebaseFunctions,
      envFilePath: envFile.path,
      envFileExists: envFileExists,
      envAuthKeyConfigured: envAuthKeyConfigured,
      envUsesReservedAuthKey: envUsesReservedAuthKey,
      ready: issues.isEmpty,
      deployEnvReady:
          envFileExists && envAuthKeyConfigured && !envUsesReservedAuthKey,
      issues: issues,
      warnings: warnings,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyCreateResult> firebaseAccessKeyCreate(
    PublisherBackendFirebaseAccessKeyCreateRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final keyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final expiresAtUtc = _normalizeFirebaseAccessKeyExpiry(
      request.expiresAtUtc,
    );
    final existing = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, keyId),
    );
    final existingActive = existing == null
        ? false
        : _firebaseAccessKeyEntryFromDocument(keyId, existing).currentlyActive;
    if (existingActive) {
      throw PublisherBackendException(
        'Firebase publisher backend access key "$keyId" already exists for '
        '${settings.miniProgramId}. Revoke or rotate it first.',
      );
    }

    final accessKey = _normalizePublisherBackendAccessKey(
      request.accessKey ?? _generatePublisherBackendAccessKey(),
    );
    final createdAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, keyId),
      document: <String, Object?>{
        'keyId': keyId,
        'keyHash': _sha256Hex(accessKey),
        'lastFour': _lastFour(accessKey),
        'active': true,
        'createdAtUtc': createdAtUtc,
        'updatedAtUtc': createdAtUtc,
        if (expiresAtUtc != null) 'expiresAtUtc': expiresAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyCreateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keyId: keyId,
      accessKey: accessKey,
      createdAtUtc: createdAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyListResult> firebaseAccessKeyList(
    PublisherBackendFirebaseAccessKeyListRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final documents = await _listFirestoreCollectionDocuments(
      projectId: settings.projectId,
      collectionPath: 'miniPrograms/${settings.miniProgramId}/accessKeys',
    );
    final keys = documents.map((document) {
      final keyId =
          _firestoreDocumentIdFromName(document['name']?.toString()) ??
          document['keyId']?.toString().trim() ??
          'unknown';
      return _firebaseAccessKeyEntryFromDocument(
        keyId,
        _fromFirestoreDocument(document),
      );
    }).toList()..sort((a, b) => a.keyId.compareTo(b.keyId));
    return PublisherBackendFirebaseAccessKeyListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keys: keys,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyRevokeResult> firebaseAccessKeyRevoke(
    PublisherBackendFirebaseAccessKeyRevokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final keyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final documentPath = _firebaseAccessKeyDocumentPath(settings, keyId);
    final existing = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: documentPath,
    );
    if (existing == null) {
      throw PublisherBackendException(
        'No Firebase publisher backend access key "$keyId" was found for '
        '${settings.miniProgramId}.',
      );
    }
    final revokedAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: documentPath,
      document: <String, Object?>{
        ...existing,
        'keyId': keyId,
        'active': false,
        'revokedAtUtc': revokedAtUtc,
        'updatedAtUtc': revokedAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyRevokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keyId: keyId,
      revokedAtUtc: revokedAtUtc,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyRotateResult> firebaseAccessKeyRotate(
    PublisherBackendFirebaseAccessKeyRotateRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final oldKeyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final newKeyId = _normalizeFirebaseAccessKeyId(
      request.newKeyId?.trim().isNotEmpty == true
          ? request.newKeyId!.trim()
          : request.keyId,
    );
    final expiresAtUtc = _normalizeFirebaseAccessKeyExpiry(
      request.expiresAtUtc,
    );
    final oldDocumentPath = _firebaseAccessKeyDocumentPath(settings, oldKeyId);
    final oldDocument = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: oldDocumentPath,
    );
    if (oldDocument == null) {
      throw PublisherBackendException(
        'No Firebase publisher backend access key "$oldKeyId" was found for '
        '${settings.miniProgramId}.',
      );
    }
    if (newKeyId != oldKeyId) {
      final existingNewKey = await _readFirestoreDocument(
        projectId: settings.projectId,
        documentPath: _firebaseAccessKeyDocumentPath(settings, newKeyId),
      );
      if (existingNewKey != null &&
          _firebaseAccessKeyEntryFromDocument(
            newKeyId,
            existingNewKey,
          ).currentlyActive) {
        throw PublisherBackendException(
          'Firebase publisher backend access key "$newKeyId" already exists '
          'for ${settings.miniProgramId}.',
        );
      }
    }

    final accessKey = _normalizePublisherBackendAccessKey(
      request.accessKey ?? _generatePublisherBackendAccessKey(),
    );
    final rotatedAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: oldDocumentPath,
      document: <String, Object?>{
        ...oldDocument,
        'keyId': oldKeyId,
        'active': false,
        'revokedAtUtc': rotatedAtUtc,
        'updatedAtUtc': rotatedAtUtc,
      },
    );
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, newKeyId),
      document: <String, Object?>{
        'keyId': newKeyId,
        'keyHash': _sha256Hex(accessKey),
        'lastFour': _lastFour(accessKey),
        'active': true,
        'createdAtUtc': newKeyId == oldKeyId
            ? (oldDocument['createdAtUtc']?.toString() ?? rotatedAtUtc)
            : rotatedAtUtc,
        'updatedAtUtc': rotatedAtUtc,
        'rotatedAtUtc': rotatedAtUtc,
        if (expiresAtUtc != null) 'expiresAtUtc': expiresAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyRotateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      revokedKeyId: oldKeyId,
      newKeyId: newKeyId,
      accessKey: accessKey,
      rotatedAtUtc: rotatedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  Future<PublisherBackendFirebaseSmokeResult> firebaseSmoke(
    PublisherBackendFirebaseSmokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        backendBaseUrl: settings.functionUrl,
        passed: false,
        routes: const <PublisherBackendFirebaseSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        writeCouponId: request.writeCouponId,
        writeUserId: request.writeUserId,
        includeAuth: request.includeAuth,
        authCreateUser: request.authCreateUser,
        authEmail: request.includeAuth ? request.authEmail : null,
        accessKeyProvided: request.accessKey?.trim().isNotEmpty == true,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final baseUri = Uri.parse(settings.functionUrl);
    final routes = <PublisherBackendFirebaseSmokeRouteResult>[];
    for (final path in _publisherBackendFirebaseSmokeRoutePaths) {
      routes.add(
        await _probeFirebaseSmokeRoute(
          method: 'GET',
          path: path,
          uri: _resolveBackendRoute(baseUri, path),
          accessKey: request.accessKey,
        ),
      );
    }
    if (request.includeWrite) {
      routes.add(
        await _probeFirebaseSmokeWriteRoute(
          settings: settings,
          uri: _resolveBackendRoute(baseUri, '/coupon/redeem'),
          couponId: request.writeCouponId,
          userId: request.writeUserId,
          accessKey: request.accessKey,
        ),
      );
    }
    if (request.includeAuth) {
      routes.addAll(
        await _probeFirebaseSmokeAuthRoutes(
          baseUri: baseUri,
          email: request.authEmail?.trim() ?? '',
          password: request.authPassword ?? '',
          createUser: request.authCreateUser,
          accessKey: request.accessKey,
        ),
      );
    } else {
      routes.add(
        await _probeFirebaseProtectedSessionGuard(
          uri: _resolveBackendRoute(baseUri, '/auth/session'),
          accessKey: request.accessKey,
        ),
      );
    }
    return PublisherBackendFirebaseSmokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendBaseUrl: settings.functionUrl,
      passed: routes.every((route) => route.passed),
      routes: routes,
      includeWrite: request.includeWrite,
      writeCouponId: request.writeCouponId,
      writeUserId: request.writeUserId,
      includeAuth: request.includeAuth,
      authCreateUser: request.authCreateUser,
      authEmail: request.includeAuth ? request.authEmail : null,
      accessKeyProvided: request.accessKey?.trim().isNotEmpty == true,
    );
  }

  Future<PublisherBackendFirebaseSeedResult> firebaseSeed(
    PublisherBackendFirebaseSeedRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        seeded: false,
        itemCount: 0,
        appRecordCount: 0,
        couponCount: 0,
        authSessionCount: 0,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final seedData = await _readFirebaseSeedData(settings);
    final records = _buildFirestoreSeedRecords(settings, seedData);
    for (final record in records) {
      await _writeFirestoreDocument(
        projectId: settings.projectId,
        documentPath: record.documentPath,
        document: record.document,
      );
    }
    return PublisherBackendFirebaseSeedResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      seeded: true,
      itemCount: records.length,
      appRecordCount: records.length,
      couponCount: seedData.coupons.length,
      authSessionCount: 1,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
    );
  }

  Future<PublisherBackendFirebaseDataStatusResult> firebaseDataStatus(
    PublisherBackendFirebaseDataStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    try {
      final homeCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/home',
      );
      final sessionCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/sessions',
      );
      final couponCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/coupons',
      );
      final redemptionCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/redemptions',
      );
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: true,
        homeRecordCount: homeCount,
        authSessionCount: sessionCount,
        couponCount: couponCount,
        redemptionCount: redemptionCount,
        appRecordCount: homeCount + sessionCount + couponCount,
      );
    } on PublisherBackendException catch (error) {
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        error: error.message,
      );
    }
  }

  Future<PublisherBackendFirebaseDataExportResult> firebaseDataExport(
    PublisherBackendFirebaseDataExportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        exported: false,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final appRecords = <Map<String, Object?>>[
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'home',
        recordType: 'home',
      ),
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'sessions',
        recordType: 'session',
      ),
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'coupons',
        recordType: 'coupon',
      ),
    ];
    final redemptionRecords = request.includeRedemptions
        ? await _listFirestoreLogicalRecords(
            settings: settings,
            collection: 'redemptions',
            recordType: 'redemption',
          )
        : <Map<String, Object?>>[];
    final records = <Map<String, Object?>>[...appRecords, ...redemptionRecords]
      ..sort(_compareFirestoreLogicalRecords);
    final exportedAtUtc = _clock().toUtc().toIso8601String();
    final outputPath = _resolveFirebaseDataExportPath(
      settings,
      request.outputPath,
    );
    final exportFile = File(outputPath);
    await exportFile.parent.create(recursive: true);
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'command': 'publisher-backend firebase data export',
        'provider': request.environment.provider,
        'environmentName': request.environment.name,
        'projectId': settings.projectId,
        'region': settings.region,
        'functionName': settings.functionName,
        'miniProgramId': settings.miniProgramId,
        'storageMode': _publisherBackendStorageFirestore,
        'exportedAtUtc': exportedAtUtc,
        'includeRedemptions': request.includeRedemptions,
        'appRecordCount': appRecords.length,
        'redemptionCount': redemptionRecords.length,
        'itemCount': records.length,
        'records': records,
      }),
    );
    return PublisherBackendFirebaseDataExportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      exported: true,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: appRecords.length,
      redemptionCount: redemptionRecords.length,
      itemCount: records.length,
      outputPath: outputPath,
      exportedAtUtc: exportedAtUtc,
    );
  }

  Future<PublisherBackendFirebaseDataImportResult> firebaseDataImport(
    PublisherBackendFirebaseDataImportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final inputPath = p.normalize(p.absolute(request.inputPath));
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final importPlan = await _readFirebaseDataImportPlan(
      settings: settings,
      inputPath: inputPath,
      includeRedemptions: request.includeRedemptions,
    );
    if (!request.dryRun) {
      for (final record in importPlan.records) {
        await _writeFirestoreDocument(
          projectId: settings.projectId,
          documentPath: record.documentPath,
          document: record.data,
        );
      }
    }
    return PublisherBackendFirebaseDataImportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      succeeded: true,
      imported: !request.dryRun,
      dryRun: request.dryRun,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: importPlan.appRecordCount,
      redemptionCount: importPlan.redemptionCount,
      skippedRedemptionCount: importPlan.skippedRedemptionCount,
      itemCount: importPlan.records.length,
      inputPath: inputPath,
    );
  }

  Future<PublisherBackendFirebaseDataRedemptionsResult> firebaseDataRedemptions(
    PublisherBackendFirebaseDataRedemptionsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final records = await _listFirestoreLogicalRecords(
      settings: settings,
      collection: 'redemptions',
      recordType: 'redemption',
    );
    final matched = _filterRedemptionRecords(
      records,
      couponId: request.couponId,
      userId: request.userId,
    );
    final returned = matched.take(request.limit).toList();
    return PublisherBackendFirebaseDataRedemptionsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      available: true,
      limit: request.limit,
      matchedCount: matched.length,
      returnedCount: returned.length,
      records: returned,
      couponId: request.couponId,
      userId: request.userId,
    );
  }

  Future<PublisherBackendFirebaseDestroyResult> firebaseDestroy(
    PublisherBackendFirebaseDestroyRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    int? appRecordCount;
    int? redemptionCount;
    try {
      final status = await firebaseDataStatus(
        PublisherBackendFirebaseDataStatusRequest(
          miniProgramRootPath: rootPath,
          environment: request.environment,
        ),
      );
      appRecordCount = status.appRecordCount;
      redemptionCount = status.redemptionCount;
    } on Object catch (error) {
      if (!request.confirmDataLoss) {
        return PublisherBackendFirebaseDestroyResult(
          provider: request.environment.provider,
          environmentName: request.environment.name,
          projectId: settings.projectId,
          region: settings.region,
          functionName: settings.functionName,
          miniProgramId: settings.miniProgramId,
          backendBaseUrl: settings.functionUrl,
          deleted: false,
          dataLossConfirmed: false,
          appRecordCount: appRecordCount,
          redemptionCount: redemptionCount,
          blockedByData: true,
          error:
              'Could not inspect Firestore data before deleting the Firebase '
              'function. Export data first or pass --confirm-data-loss to '
              'continue. Detail: $error',
        );
      }
    }
    final totalRecords = (appRecordCount ?? 0) + (redemptionCount ?? 0);
    if (totalRecords > 0 && !request.confirmDataLoss) {
      return PublisherBackendFirebaseDestroyResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        backendBaseUrl: settings.functionUrl,
        deleted: false,
        dataLossConfirmed: false,
        appRecordCount: appRecordCount,
        redemptionCount: redemptionCount,
        blockedByData: true,
        error:
            'Firestore has $totalRecords publisher backend record(s). '
            'Run `miniprogram publisher-backend firebase data export` first, '
            'then pass --confirm-data-loss if you still want to delete the '
            'Firebase function. Firestore data will not be deleted.',
      );
    }

    await _runFirebaseCommand(<String>[
      'functions:delete',
      settings.functionName,
      '--region',
      settings.region,
      '--project',
      settings.projectId,
      '--force',
    ], workingDirectory: settings.backendRootPath);
    await _clearFirebaseState(rootPath);
    return PublisherBackendFirebaseDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      deleted: true,
      dataLossConfirmed: request.confirmDataLoss,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      deletedAtUtc: _clock().toUtc().toIso8601String(),
    );
  }

  Future<PublisherBackendAwsSeedResult> awsSeed(
    PublisherBackendAwsSeedRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        seeded: false,
        itemCount: 0,
        miniProgramId: settings.miniProgramId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        seeded: false,
        itemCount: 0,
        miniProgramId: settings.miniProgramId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final seedData = await _readAwsSeedData(settings);
    final items = _buildDynamoDbSeedItems(settings, seedData);
    await _batchWriteDynamoDbItems(
      settings: settings,
      tableName: tableName,
      items: items,
    );
    return PublisherBackendAwsSeedResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      seeded: true,
      itemCount: items.length,
      miniProgramId: settings.miniProgramId,
    );
  }

  Future<PublisherBackendAwsDataStatusResult> awsDataStatus(
    PublisherBackendAwsDataStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        available: false,
        miniProgramId: settings.miniProgramId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        available: false,
        miniProgramId: settings.miniProgramId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final table = await _describeDynamoDbTable(settings, tableName);
    final appRecordCount = await _queryDynamoDbCount(
      settings: settings,
      tableName: tableName,
      partitionKey: _appPartitionKey(settings.miniProgramId),
    );
    final redemptionCount = await _queryDynamoDbCount(
      settings: settings,
      tableName: tableName,
      partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
    );
    return PublisherBackendAwsDataStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      tableStatus: table['TableStatus']?.toString(),
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      available: true,
      miniProgramId: settings.miniProgramId,
    );
  }

  Future<PublisherBackendAwsDataExportResult> awsDataExport(
    PublisherBackendAwsDataExportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        exported: false,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        exported: false,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final appItems = await _queryDynamoDbItems(
      settings: settings,
      tableName: tableName,
      partitionKey: _appPartitionKey(settings.miniProgramId),
    );
    final redemptionItems = request.includeRedemptions
        ? await _queryDynamoDbItems(
            settings: settings,
            tableName: tableName,
            partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
          )
        : <Map<String, Object?>>[];
    final exportedAtUtc = _clock().toUtc().toIso8601String();
    final outputPath = _resolveAwsDataExportPath(settings, request.outputPath);
    final items = <Map<String, Object?>>[
      ..._sortedDynamoDbExportItems(appItems),
      ..._sortedDynamoDbExportItems(redemptionItems),
    ];
    final exportFile = File(outputPath);
    await exportFile.parent.create(recursive: true);
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'command': 'publisher-backend aws data export',
        'provider': request.environment.provider,
        'environmentName': request.environment.name,
        'stackName': settings.stackName,
        'region': settings.region,
        'miniProgramId': settings.miniProgramId,
        'storageMode': storageMode,
        'tableName': tableName,
        'exportedAtUtc': exportedAtUtc,
        'includeRedemptions': request.includeRedemptions,
        'appRecordCount': appItems.length,
        'redemptionCount': redemptionItems.length,
        'itemCount': items.length,
        'items': items,
      }),
    );
    return PublisherBackendAwsDataExportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      exported: true,
      miniProgramId: settings.miniProgramId,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: appItems.length,
      redemptionCount: redemptionItems.length,
      itemCount: items.length,
      outputPath: outputPath,
      exportedAtUtc: exportedAtUtc,
    );
  }

  Future<PublisherBackendAwsDataImportResult> awsDataImport(
    PublisherBackendAwsDataImportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final inputPath = p.normalize(p.absolute(request.inputPath));
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        miniProgramId: settings.miniProgramId,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final importPlan = await _readAwsDataImportPlan(
      settings: settings,
      inputPath: inputPath,
      includeRedemptions: request.includeRedemptions,
    );
    if (!request.dryRun && importPlan.items.isNotEmpty) {
      await _batchWriteDynamoDbItems(
        settings: settings,
        tableName: tableName,
        items: importPlan.items,
      );
    }
    return PublisherBackendAwsDataImportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      succeeded: true,
      imported: !request.dryRun,
      dryRun: request.dryRun,
      miniProgramId: settings.miniProgramId,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: importPlan.appRecordCount,
      redemptionCount: importPlan.redemptionCount,
      skippedRedemptionCount: importPlan.skippedRedemptionCount,
      itemCount: importPlan.items.length,
      inputPath: inputPath,
    );
  }

  Future<PublisherBackendAwsDataRedemptionsResult> awsDataRedemptions(
    PublisherBackendAwsDataRedemptionsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    if (stack == null) {
      return PublisherBackendAwsDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        available: false,
        miniProgramId: settings.miniProgramId,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }

    final outputs = _extractStackOutputs(stack);
    final tableName = outputs['PublisherBackendDataTableName']?.trim();
    final storageMode = outputs['PublisherBackendStorageMode']?.trim();
    if (tableName == null || tableName.isEmpty) {
      return PublisherBackendAwsDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: true,
        stackStatus: stack['StackStatus']?.toString(),
        storageMode: storageMode,
        available: false,
        miniProgramId: settings.miniProgramId,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error: 'PublisherBackendDataTableName output is missing.',
      );
    }

    final records = await _queryDynamoDbItems(
      settings: settings,
      tableName: tableName,
      partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
    );
    final matched = _filterRedemptionRecords(
      records,
      couponId: request.couponId,
      userId: request.userId,
    );
    final returned = matched.take(request.limit).toList();
    return PublisherBackendAwsDataRedemptionsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      storageMode: storageMode,
      tableName: tableName,
      available: true,
      miniProgramId: settings.miniProgramId,
      limit: request.limit,
      matchedCount: matched.length,
      returnedCount: returned.length,
      records: returned,
      couponId: request.couponId,
      userId: request.userId,
    );
  }

  Future<PublisherBackendAwsLogsResult> awsLogs(
    PublisherBackendAwsLogsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final functionName = await _resolveLambdaFunctionName(settings);
    if (functionName == null) {
      throw PublisherBackendException(
        'No Lambda function resource was found for publisher backend stack '
        '"${settings.stackName}". Run `miniprogram publisher-backend aws deploy` first.',
      );
    }
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      'logs',
      'tail',
      '/aws/lambda/$functionName',
      '--since',
      request.since,
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    return PublisherBackendAwsLogsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      lambdaFunctionName: functionName,
      since: request.since,
      stdoutText: '${result.stdout}'.trim(),
      stderrText: '${result.stderr}'.trim(),
    );
  }

  Future<PublisherBackendAwsDestroyResult> awsDestroy(
    PublisherBackendAwsDestroyRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendAwsSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
      stackNameOverride: request.stackName,
      stageNameOverride: request.stageName,
      samS3BucketOverride: request.samS3Bucket,
    );
    final stack = await _describeStack(settings);
    String? tableName;
    int? appRecordCount;
    int? redemptionCount;
    if (stack == null) {
      return PublisherBackendAwsDestroyResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        region: settings.region,
        deleted: false,
        dataLossConfirmed: request.confirmDataLoss,
        error:
            'AWS publisher backend stack "${settings.stackName}" was not found.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    tableName = outputs['PublisherBackendDataTableName']?.trim();
    if (tableName != null && tableName.isNotEmpty) {
      try {
        appRecordCount = await _queryDynamoDbCount(
          settings: settings,
          tableName: tableName,
          partitionKey: _appPartitionKey(settings.miniProgramId),
        );
        redemptionCount = await _queryDynamoDbCount(
          settings: settings,
          tableName: tableName,
          partitionKey: _redemptionsPartitionKey(settings.miniProgramId),
        );
      } on Object catch (error) {
        if (!request.confirmDataLoss) {
          return PublisherBackendAwsDestroyResult(
            provider: request.environment.provider,
            environmentName: request.environment.name,
            stackName: settings.stackName,
            region: settings.region,
            deleted: false,
            dataLossConfirmed: false,
            tableName: tableName,
            appRecordCount: appRecordCount,
            redemptionCount: redemptionCount,
            blockedByData: true,
            error:
                'Could not inspect DynamoDB table "$tableName" before deletion. '
                'Export data first or pass --confirm-data-loss to continue. '
                'Detail: $error',
          );
        }
      }
      final totalRecords = (appRecordCount ?? 0) + (redemptionCount ?? 0);
      if (totalRecords > 0 && !request.confirmDataLoss) {
        return PublisherBackendAwsDestroyResult(
          provider: request.environment.provider,
          environmentName: request.environment.name,
          stackName: settings.stackName,
          region: settings.region,
          deleted: false,
          dataLossConfirmed: false,
          tableName: tableName,
          appRecordCount: appRecordCount,
          redemptionCount: redemptionCount,
          blockedByData: true,
          error:
              'DynamoDB table "$tableName" has $totalRecords record(s). '
              'Run `miniprogram publisher-backend aws data export` first, '
              'then pass --confirm-data-loss if you still want to delete it.',
        );
      }
    }
    await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'delete-stack',
      '--stack-name',
      settings.stackName,
    ], allowEmptyJsonOutput: true);
    await _runAwsCommand(settings, <String>[
      'cloudformation',
      'wait',
      'stack-delete-complete',
      '--stack-name',
      settings.stackName,
    ]);
    await _clearAwsState(rootPath);
    return PublisherBackendAwsDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      deleted: true,
      dataLossConfirmed: request.confirmDataLoss,
      tableName: tableName?.isEmpty == true ? null : tableName,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      deletedAtUtc: _clock().toUtc().toIso8601String(),
    );
  }

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
  }

  static Future<StartedPublisherBackendProcess> _defaultProcessStarter({
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
    return StartedPublisherBackendProcess(pid: process.pid);
  }

  static Future<http.Response> _defaultPostRequester(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(uri, headers: headers, body: body);
  }

  static Future<http.Response> _defaultHttpRequester(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return switch (method.toUpperCase()) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: body),
      'PATCH' => http.patch(uri, headers: headers, body: body),
      'PUT' => http.put(uri, headers: headers, body: body),
      'DELETE' => http.delete(uri, headers: headers, body: body),
      _ => throw PublisherBackendException(
        'Unsupported HTTP method for publisher backend request: $method',
      ),
    };
  }

  static Future<String?> _defaultFirebaseAccessTokenProvider() async {
    final environmentToken = Platform.environment['FIREBASE_TOKEN']?.trim();
    if (environmentToken != null && environmentToken.isNotEmpty) {
      return await _exchangeFirebaseRefreshToken(environmentToken) ??
          environmentToken;
    }
    for (final path in _firebaseCliConfigStoreCandidates()) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) {
          continue;
        }
        final tokens = decoded['tokens'];
        if (tokens is! Map) {
          continue;
        }
        final refreshToken = tokens['refresh_token']?.toString().trim();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final accessToken = await _exchangeFirebaseRefreshToken(refreshToken);
          if (accessToken != null && accessToken.isNotEmpty) {
            return accessToken;
          }
        }
        final accessToken = tokens['access_token']?.toString().trim();
        if (accessToken != null && accessToken.isNotEmpty) {
          return accessToken;
        }
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  static Future<String?> _exchangeFirebaseRefreshToken(
    String refreshToken,
  ) async {
    try {
      final response = await http.post(
        Uri.https('www.googleapis.com', '/oauth2/v3/token'),
        body: <String, String>{
          'refresh_token': refreshToken,
          'client_id': _firebaseCliClientId,
          'client_secret': _firebaseCliClientSecret,
          'grant_type': 'refresh_token',
          'scope': _firebaseCliTokenScopes.join(' '),
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final accessToken = decoded['access_token']?.toString().trim();
      return accessToken == null || accessToken.isEmpty ? null : accessToken;
    } on FormatException {
      return null;
    } on http.ClientException {
      return null;
    } on SocketException {
      return null;
    } on TlsException {
      return null;
    }
  }

  static List<String> _firebaseCliConfigStoreCandidates() {
    final candidates = <String>{};
    final env = Platform.environment;
    void addCandidate(String? root) {
      if (root == null || root.trim().isEmpty) {
        return;
      }
      candidates.add(p.join(root, 'configstore', 'firebase-tools.json'));
    }

    addCandidate(env['XDG_CONFIG_HOME']);
    addCandidate(env['APPDATA']);
    addCandidate(env['HOME'] == null ? null : p.join(env['HOME']!, '.config'));
    addCandidate(
      env['USERPROFILE'] == null
          ? null
          : p.join(env['USERPROFILE']!, '.config'),
    );
    addCandidate(
      env['USERPROFILE'] == null
          ? null
          : p.join(env['USERPROFILE']!, 'AppData', 'Roaming'),
    );
    return candidates.toList();
  }

  static DateTime _defaultClock() => DateTime.now();

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}
