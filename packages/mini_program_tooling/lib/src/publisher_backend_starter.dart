import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

typedef PublisherBackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef PublisherBackendProcessStarter =
    Future<StartedPublisherBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef PublisherBackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef PublisherBackendPostRequester =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });
typedef PublisherBackendClock = DateTime Function();
typedef PublisherBackendDelay = Future<void> Function(Duration duration);

const List<String> _publisherBackendAwsSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
  '/auth/session',
];

const Duration _awsDeployHealthWaitTimeout = Duration(seconds: 45);
const Duration _awsDeployHealthAttemptTimeout = Duration(seconds: 5);
const Duration _awsDeployHealthRetryDelay = Duration(seconds: 1);
const int _dynamoDbBatchWriteMaxAttempts = 5;

const String _publisherBackendStorageBundled = 'bundled';
const String _publisherBackendStorageDynamoDb = 'dynamodb';
const String _awsSdkJavaScriptV3Version = '^3.1052.0';

class PublisherBackendException implements Exception {
  const PublisherBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublisherBackendScaffoldRequest {
  const PublisherBackendScaffoldRequest({
    required this.miniProgramRootPath,
    this.template = 'mock',
    this.storageMode = 'bundled',
    this.force = false,
  });

  final String miniProgramRootPath;
  final String template;
  final String storageMode;
  final bool force;
}

class PublisherBackendScaffoldResult {
  const PublisherBackendScaffoldResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.template,
    required this.createdPaths,
    this.storageMode,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String template;
  final List<String> createdPaths;
  final String? storageMode;
}

class PublisherBackendAwsDeployRequest {
  const PublisherBackendAwsDeployRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsDeployResult {
  const PublisherBackendAwsDeployResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    required this.backendRootPath,
    required this.outputs,
    required this.deployedAtUtc,
    this.miniProgramRootPath,
    this.backendBaseUrl,
    this.healthUrl,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final String backendRootPath;
  final String? miniProgramRootPath;
  final Map<String, String> outputs;
  final String deployedAtUtc;
  final String? backendBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendAwsStatusRequest {
  const PublisherBackendAwsStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsStatusResult {
  const PublisherBackendAwsStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.outputs,
    this.state,
    this.stackStatus,
    this.stackStatusReason,
    this.backendBaseUrl,
    this.healthUrl,
    this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final PublisherBackendAwsState? state;
  final String? stackStatus;
  final String? stackStatusReason;
  final Map<String, String> outputs;
  final String? backendBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendAwsOutputsRequest {
  const PublisherBackendAwsOutputsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsOutputsResult {
  const PublisherBackendAwsOutputsResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.outputs,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final Map<String, String> outputs;
}

class PublisherBackendAwsSmokeRequest {
  const PublisherBackendAwsSmokeRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.includeWrite = false,
    this.writeCouponId = 'coupon-10',
    this.writeUserId = 'smoke-user',
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final bool includeWrite;
  final String writeCouponId;
  final String writeUserId;
}

class PublisherBackendAwsSmokeRouteResult {
  const PublisherBackendAwsSmokeRouteResult({
    required this.method,
    required this.path,
    required this.uri,
    required this.passed,
    this.statusCode,
    this.responseStatus,
    this.error,
  });

  final String method;
  final String path;
  final Uri uri;
  final bool passed;
  final int? statusCode;
  final String? responseStatus;
  final String? error;
}

class PublisherBackendAwsSmokeResult {
  const PublisherBackendAwsSmokeResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.passed,
    required this.routes,
    required this.includeWrite,
    this.backendBaseUrl,
    this.stackStatus,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool passed;
  final List<PublisherBackendAwsSmokeRouteResult> routes;
  final bool includeWrite;
  final String? backendBaseUrl;
  final String? stackStatus;
  final String? error;
}

class PublisherBackendAwsSeedRequest {
  const PublisherBackendAwsSeedRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsSeedResult {
  const PublisherBackendAwsSeedResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.seeded,
    required this.itemCount,
    required this.miniProgramId,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool seeded;
  final int itemCount;
  final String miniProgramId;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? error;
}

class PublisherBackendAwsDataStatusRequest {
  const PublisherBackendAwsDataStatusRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsDataStatusResult {
  const PublisherBackendAwsDataStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.available,
    required this.miniProgramId,
    this.stackStatus,
    this.storageMode,
    this.tableName,
    this.tableStatus,
    this.appRecordCount,
    this.redemptionCount,
    this.error,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final bool stackExists;
  final bool available;
  final String miniProgramId;
  final String? stackStatus;
  final String? storageMode;
  final String? tableName;
  final String? tableStatus;
  final int? appRecordCount;
  final int? redemptionCount;
  final String? error;
}

class PublisherBackendAwsLogsRequest {
  const PublisherBackendAwsLogsRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
    this.since = '1h',
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
  final String since;
}

class PublisherBackendAwsLogsResult {
  const PublisherBackendAwsLogsResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.lambdaFunctionName,
    required this.since,
    required this.stdoutText,
    required this.stderrText,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final String lambdaFunctionName;
  final String since;
  final String stdoutText;
  final String stderrText;
}

class PublisherBackendAwsDestroyRequest {
  const PublisherBackendAwsDestroyRequest({
    required this.miniProgramRootPath,
    required this.environment,
    this.stackName,
    this.stageName,
    this.samS3Bucket,
  });

  final String miniProgramRootPath;
  final CloudEnvironmentConfiguration environment;
  final String? stackName;
  final String? stageName;
  final String? samS3Bucket;
}

class PublisherBackendAwsDestroyResult {
  const PublisherBackendAwsDestroyResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.region,
    required this.deletedAtUtc,
  });

  final String provider;
  final String environmentName;
  final String stackName;
  final String region;
  final String deletedAtUtc;
}

class PublisherBackendRunResult {
  const PublisherBackendRunResult({
    required this.state,
    required this.alreadyRunning,
  });

  final PublisherBackendState state;
  final bool alreadyRunning;
}

class PublisherBackendStatusResult {
  const PublisherBackendStatusResult({
    required this.state,
    required this.hasState,
    required this.processAlive,
    required this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final PublisherBackendState? state;
  final bool hasState;
  final bool processAlive;
  final bool healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendStopResult {
  const PublisherBackendStopResult({
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

class PublisherBackendUrlsResult {
  const PublisherBackendUrlsResult({required this.port});

  final int port;

  String get desktopBaseUrl => 'http://127.0.0.1:$port/';
  String get androidEmulatorBaseUrl => 'http://10.0.2.2:$port/';
  String get androidUsbBaseUrl => 'http://127.0.0.1:$port/';
}

class PublisherBackendState {
  const PublisherBackendState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.pid,
    required this.port,
    required this.bindHost,
    required this.healthCheckUrl,
    required this.stdoutLogPath,
    required this.stderrLogPath,
    required this.startedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final int pid;
  final int port;
  final String bindHost;
  final String healthCheckUrl;
  final String stdoutLogPath;
  final String stderrLogPath;
  final String startedAtUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'pid': pid,
    'port': port,
    'bindHost': bindHost,
    'healthCheckUrl': healthCheckUrl,
    'stdoutLogPath': stdoutLogPath,
    'stderrLogPath': stderrLogPath,
    'startedAtUtc': startedAtUtc,
  };

  static PublisherBackendState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final pid = json['pid'];
    final port = json['port'];
    final bindHost = json['bindHost'];
    final healthCheckUrl = json['healthCheckUrl'];
    final stdoutLogPath = json['stdoutLogPath'];
    final stderrLogPath = json['stderrLogPath'];
    final startedAtUtc = json['startedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        pid is! int ||
        port is! int ||
        bindHost is! String ||
        healthCheckUrl is! String ||
        stdoutLogPath is! String ||
        stderrLogPath is! String ||
        startedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.local.json is missing required fields.',
      );
    }
    return PublisherBackendState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      pid: pid,
      port: port,
      bindHost: bindHost,
      healthCheckUrl: healthCheckUrl,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: startedAtUtc,
    );
  }
}

class PublisherBackendAwsState {
  const PublisherBackendAwsState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    required this.outputs,
    required this.deployedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final String environmentName;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final Map<String, String> outputs;
  final String deployedAtUtc;

  String? get backendBaseUrl => outputs['PublisherBackendBaseUrl'];
  String? get healthUrl => outputs['PublisherBackendHealthUrl'];
  String? get functionName => outputs['PublisherBackendFunctionName'];

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'environmentName': environmentName,
    'stackName': stackName,
    'stageName': stageName,
    'region': region,
    'samS3Bucket': samS3Bucket,
    'outputs': outputs,
    'deployedAtUtc': deployedAtUtc,
  };

  static PublisherBackendAwsState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final environmentName = json['environmentName'];
    final stackName = json['stackName'];
    final stageName = json['stageName'];
    final region = json['region'];
    final samS3Bucket = json['samS3Bucket'];
    final outputs = json['outputs'];
    final deployedAtUtc = json['deployedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        environmentName is! String ||
        stackName is! String ||
        stageName is! String ||
        region is! String ||
        samS3Bucket is! String ||
        outputs is! Map ||
        deployedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.aws.json is missing required fields.',
      );
    }
    return PublisherBackendAwsState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      environmentName: environmentName,
      stackName: stackName,
      stageName: stageName,
      region: region,
      samS3Bucket: samS3Bucket,
      outputs: outputs.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      deployedAtUtc: deployedAtUtc,
    );
  }
}

class StartedPublisherBackendProcess {
  const StartedPublisherBackendProcess({required this.pid});

  final int pid;
}

class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner = _defaultShellRunner,
    PublisherBackendProcessStarter processStarter = _defaultProcessStarter,
    PublisherBackendHealthGetter healthGetter = http.get,
    PublisherBackendPostRequester postRequester = _defaultPostRequester,
    PublisherBackendClock clock = _defaultClock,
    PublisherBackendDelay delay = _defaultDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _postRequester = postRequester,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendPostRequester _postRequester;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) async {
    if (!const <String>['mock', 'aws-lambda'].contains(request.template)) {
      throw PublisherBackendException(
        'Unsupported publisher backend template: ${request.template}',
      );
    }
    if (!const <String>[
      _publisherBackendStorageBundled,
      _publisherBackendStorageDynamoDb,
    ].contains(request.storageMode)) {
      throw PublisherBackendException(
        'Unsupported publisher backend storage mode: ${request.storageMode}',
      );
    }
    if (request.template != 'aws-lambda' &&
        request.storageMode != _publisherBackendStorageBundled) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --storage is only supported with '
        '--template aws-lambda.',
      );
    }
    final miniProgramRootPath = await _requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      request.template == 'mock' ? 'mock' : 'aws_lambda',
    );
    final createdPaths = <String>[];
    final files = request.template == 'mock'
        ? buildMockPublisherBackendFiles(
            miniProgramRootPath: miniProgramRootPath,
          )
        : buildAwsLambdaPublisherBackendFiles(
            miniProgramRootPath: miniProgramRootPath,
            storageMode: request.storageMode,
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
      storageMode: request.template == 'aws-lambda'
          ? request.storageMode
          : null,
    );
  }

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
      deletedAtUtc: _clock().toUtc().toIso8601String(),
    );
  }

  Future<String> _requireMiniProgramRoot(String rawRootPath) async {
    final rootPath = p.normalize(p.absolute(rawRootPath));
    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $rootPath',
      );
    }
    return rootPath;
  }

  Future<void> _assertMockBackendPaths(String backendRootPath) async {
    final serverFile = File(p.join(backendRootPath, 'bin', 'server.dart'));
    final dataDirectory = Directory(p.join(backendRootPath, 'data'));
    if (!await serverFile.exists() || !await dataDirectory.exists()) {
      throw PublisherBackendException(
        'Publisher mock backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template mock` first.',
      );
    }
  }

  Future<void> _assertAwsBackendPaths(String backendRootPath) async {
    final templateFile = File(p.join(backendRootPath, 'template.yaml'));
    final handlerFile = File(p.join(backendRootPath, 'src', 'handler.mjs'));
    if (!await templateFile.exists() || !await handlerFile.exists()) {
      throw const PublisherBackendException(
        'AWS Lambda publisher backend was not found. Run '
        '`miniprogram publisher-backend scaffold --template aws-lambda` first.',
      );
    }
  }

  Future<void> _writeManagedFile({
    required String filePath,
    required String contents,
    required bool force,
    required List<String> createdPaths,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final existing = await file.readAsString();
      if (existing == contents) {
        return;
      }
      if (!force) {
        throw PublisherBackendException(
          'Publisher backend scaffold would overwrite an existing file. '
          'Re-run with --force if you want to replace scaffold-managed files.\n'
          '$filePath',
        );
      }
    } else {
      createdPaths.add(filePath);
    }
    await file.writeAsString(contents);
  }

  Future<void> _writeLauncherScript({
    required String launcherScriptPath,
    required String backendRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final serverScriptPath = p.join(backendRootPath, 'bin', 'server.dart');
    final content = Platform.isWindows
        ? <String>[
            '@echo off',
            'setlocal',
            'cd /d ${_quoteForCmd(backendRootPath)}',
            '${_quoteForCmd(Platform.resolvedExecutable)} '
                '${_quoteForCmd(serverScriptPath)} '
                '${_quoteForCmd('--host=0.0.0.0')} '
                '${_quoteForCmd('--port=$port')} '
                '1>>${_quoteForCmd(stdoutLogPath)} '
                '2>>${_quoteForCmd(stderrLogPath)}',
          ].join('\r\n')
        : <String>[
            '#!/usr/bin/env sh',
            'set -eu',
            'cd ${_quoteForSh(backendRootPath)}',
            'exec ${_quoteForSh(Platform.resolvedExecutable)} '
                '${_quoteForSh(serverScriptPath)} '
                '${_quoteForSh('--host=0.0.0.0')} '
                '${_quoteForSh('--port=$port')} '
                '>>${_quoteForSh(stdoutLogPath)} '
                '2>>${_quoteForSh(stderrLogPath)}',
            '',
          ].join('\n');
    await File(launcherScriptPath).writeAsString(content);
  }

  Future<Directory> _ensureStateDirectory(String miniProgramRootPath) async {
    final directory = Directory(p.join(miniProgramRootPath, '.mini_program'));
    await directory.create(recursive: true);
    return directory;
  }

  String _statePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.local.json',
  );

  Future<PublisherBackendState?> _readState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.local.json must contain a JSON object.',
      );
    }
    return PublisherBackendState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeState(
    String miniProgramRootPath,
    PublisherBackendState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.local.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _awsStatePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.aws.json',
  );

  Future<PublisherBackendAwsState?> _readAwsState(
    String miniProgramRootPath,
  ) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.aws.json must contain a JSON object.',
      );
    }
    return PublisherBackendAwsState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeAwsState(
    String miniProgramRootPath,
    PublisherBackendAwsState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.aws.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearAwsState(String miniProgramRootPath) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _runSamCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final arguments = <String>[
      ...commandArguments,
      if (settings.awsProfile != null) '--profile',
      if (settings.awsProfile != null) settings.awsProfile!,
    ];
    final result = await _shellRunner(
      'sam',
      arguments,
      workingDirectory: workingDirectory,
    );
    _requireSuccess(
      executable: 'sam',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS SAM CLI',
    );
  }

  Future<void> _runAwsCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    bool allowEmptyJsonOutput = false,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
      '--output',
      'json',
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      if (allowEmptyJsonOutput) {
        return <String, dynamic>{};
      }
      throw PublisherBackendException(
        'AWS CLI returned no JSON output for command: aws ${arguments.join(' ')}',
      );
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned non-object JSON for command: aws ${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, dynamic>?> _describeStack(
    _PublisherBackendAwsSettings settings,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      'cloudformation',
      'describe-stacks',
      '--stack-name',
      settings.stackName,
      '--output',
      'json',
    ];
    final result = await _shellRunner('aws', arguments);
    if (result.exitCode != 0) {
      final stderrText = '${result.stderr}'.trim();
      if (stderrText.contains('does not exist') ||
          stderrText.contains('Stack with id') ||
          stderrText.contains('ValidationError')) {
        return null;
      }
      _requireSuccess(
        executable: 'aws',
        arguments: arguments,
        result: result,
        toolLabel: 'AWS CLI',
      );
    }
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'AWS CLI returned non-object JSON for stack describe command.',
      );
    }
    final stacks = decoded['Stacks'];
    if (stacks is! List || stacks.isEmpty || stacks.first is! Map) {
      return null;
    }
    return (stacks.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<String?> _resolveLambdaFunctionName(
    _PublisherBackendAwsSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'describe-stack-resources',
      '--stack-name',
      settings.stackName,
    ]);
    final resources = response['StackResources'];
    if (resources is! List) {
      return null;
    }
    for (final resource in resources) {
      if (resource is! Map) {
        continue;
      }
      final mapped = resource.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (mapped['ResourceType'] == 'AWS::Lambda::Function') {
        final physicalId = mapped['PhysicalResourceId']?.toString().trim();
        if (physicalId != null && physicalId.isNotEmpty) {
          return physicalId;
        }
      }
    }
    return null;
  }

  Future<_PublisherBackendAwsSeedData> _readAwsSeedData(
    _PublisherBackendAwsSettings settings,
  ) async {
    final dataRootPath = p.join(settings.backendRootPath, 'src', 'data');
    final home = await _readJsonObjectFile(
      p.join(dataRootPath, 'home_bootstrap.json'),
      label: 'home_bootstrap.json',
    );
    final session = await _readJsonObjectFile(
      p.join(dataRootPath, 'session.json'),
      label: 'session.json',
    );
    final couponsRoot = await _readJsonObjectFile(
      p.join(dataRootPath, 'coupons_list.json'),
      label: 'coupons_list.json',
    );
    final rawCoupons = couponsRoot['coupons'];
    if (rawCoupons is! List) {
      throw const PublisherBackendException(
        'coupons_list.json must contain a "coupons" list.',
      );
    }
    final coupons = <Map<String, Object?>>[];
    for (final rawCoupon in rawCoupons) {
      if (rawCoupon is! Map) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must be a JSON object.',
        );
      }
      final coupon = rawCoupon.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final couponId = coupon['id']?.toString().trim();
      if (couponId == null || couponId.isEmpty) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must contain a non-empty "id".',
        );
      }
      coupons.add(coupon);
    }
    return _PublisherBackendAwsSeedData(
      home: home,
      session: session,
      coupons: coupons,
    );
  }

  Future<Map<String, Object?>> _readJsonObjectFile(
    String filePath, {
    required String label,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw PublisherBackendException(
        'AWS publisher backend sample data is missing: $label',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS publisher backend sample data must be a JSON object: $label',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, Object?>> _buildDynamoDbSeedItems(
    _PublisherBackendAwsSettings settings,
    _PublisherBackendAwsSeedData seedData,
  ) {
    final now = _clock().toUtc().toIso8601String();
    final appPk = _appPartitionKey(settings.miniProgramId);
    final items = <Map<String, Object?>>[
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'HOME#bootstrap',
        recordType: 'home',
        payload: seedData.home,
        updatedAtUtc: now,
      ),
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'SESSION#demo',
        recordType: 'session',
        payload: seedData.session,
        updatedAtUtc: now,
      ),
    ];
    for (var i = 0; i < seedData.coupons.length; i++) {
      final coupon = seedData.coupons[i];
      final couponId = coupon['id']!.toString();
      items.add(
        _dynamoDbSeedItem(
          pk: appPk,
          sk: 'COUPON#$couponId',
          recordType: 'coupon',
          payload: coupon,
          updatedAtUtc: now,
          extraAttributes: <String, Object?>{
            'couponId': couponId,
            'sortIndex': i,
          },
        ),
      );
    }
    return items;
  }

  Map<String, Object?> _dynamoDbSeedItem({
    required String pk,
    required String sk,
    required String recordType,
    required Map<String, Object?> payload,
    required String updatedAtUtc,
    Map<String, Object?> extraAttributes = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'pk': pk,
      'sk': sk,
      'recordType': recordType,
      'payload': payload,
      'updatedAtUtc': updatedAtUtc,
      ...extraAttributes,
    };
  }

  Future<void> _batchWriteDynamoDbItems({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required List<Map<String, Object?>> items,
  }) async {
    for (var index = 0; index < items.length; index += 25) {
      final chunk = items.skip(index).take(25).toList();
      var requestItems = <String, Object?>{
        tableName: chunk
            .map(
              (item) => <String, Object?>{
                'PutRequest': <String, Object?>{
                  'Item': item.map(
                    (key, value) =>
                        MapEntry(key, _toDynamoDbAttributeValue(value)),
                  ),
                },
              },
            )
            .toList(),
      };
      for (
        var attempt = 1;
        attempt <= _dynamoDbBatchWriteMaxAttempts;
        attempt++
      ) {
        final response = await _runAwsJsonCommand(settings, <String>[
          'dynamodb',
          'batch-write-item',
          '--request-items',
          jsonEncode(requestItems),
        ]);
        final unprocessed = _dynamoDbRequestItems(response['UnprocessedItems']);
        if (!_hasDynamoDbRequestItems(unprocessed)) {
          break;
        }
        if (attempt == _dynamoDbBatchWriteMaxAttempts) {
          throw PublisherBackendException(
            'DynamoDB seed left unprocessed items for table "$tableName" after '
            '$_dynamoDbBatchWriteMaxAttempts attempts.',
          );
        }
        requestItems = unprocessed;
        await _delay(Duration(milliseconds: 200 * (1 << (attempt - 1))));
      }
    }
  }

  Map<String, Object?> _dynamoDbRequestItems(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }
    return value.map((key, nestedValue) {
      return MapEntry(key.toString(), nestedValue);
    });
  }

  bool _hasDynamoDbRequestItems(Map<String, Object?> requestItems) {
    for (final value in requestItems.values) {
      if (value is List && value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _describeDynamoDbTable(
    _PublisherBackendAwsSettings settings,
    String tableName,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'dynamodb',
      'describe-table',
      '--table-name',
      tableName,
    ]);
    final table = response['Table'];
    if (table is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned no DynamoDB table details for "$tableName".',
      );
    }
    return table.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<int> _queryDynamoDbCount({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required String partitionKey,
  }) async {
    var total = 0;
    Map<String, Object?>? exclusiveStartKey;
    do {
      final arguments = <String>[
        'dynamodb',
        'query',
        '--table-name',
        tableName,
        '--key-condition-expression',
        'pk = :pk',
        '--expression-attribute-values',
        jsonEncode(<String, Object?>{
          ':pk': <String, Object?>{'S': partitionKey},
        }),
        '--select',
        'COUNT',
        '--consistent-read',
        if (exclusiveStartKey != null) ...<String>[
          '--exclusive-start-key',
          jsonEncode(exclusiveStartKey),
        ],
      ];
      final response = await _runAwsJsonCommand(settings, arguments);
      total += _dynamoDbCountValue(response['Count']);
      final lastEvaluatedKey = response['LastEvaluatedKey'];
      exclusiveStartKey = lastEvaluatedKey is Map && lastEvaluatedKey.isNotEmpty
          ? lastEvaluatedKey.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
    } while (exclusiveStartKey != null);
    return total;
  }

  int _dynamoDbCountValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, Object?> _toDynamoDbAttributeValue(Object? value) {
    if (value == null) {
      return const <String, Object?>{'NULL': true};
    }
    if (value is bool) {
      return <String, Object?>{'BOOL': value};
    }
    if (value is num) {
      return <String, Object?>{'N': value.toString()};
    }
    if (value is String) {
      return <String, Object?>{'S': value};
    }
    if (value is List) {
      return <String, Object?>{
        'L': value.map(_toDynamoDbAttributeValue).toList(),
      };
    }
    if (value is Map) {
      return <String, Object?>{
        'M': value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _toDynamoDbAttributeValue(nestedValue)),
        ),
      };
    }
    return <String, Object?>{'S': value.toString()};
  }

  Map<String, String> _extractStackOutputs(Map<String, dynamic> stack) {
    final outputs = <String, String>{};
    final rawOutputs = stack['Outputs'];
    if (rawOutputs is! List) {
      return outputs;
    }
    for (final output in rawOutputs) {
      if (output is! Map) {
        continue;
      }
      final mapped = output.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final key = mapped['OutputKey']?.toString().trim();
      final value = mapped['OutputValue']?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      outputs[key] = value;
    }
    final sortedKeys = outputs.keys.toList()..sort();
    return <String, String>{for (final key in sortedKeys) key: outputs[key]!};
  }

  List<String> _awsGlobalArguments(_PublisherBackendAwsSettings settings) {
    final arguments = <String>['--region', settings.region];
    if (settings.awsProfile case final profile?
        when profile.trim().isNotEmpty) {
      arguments.addAll(<String>['--profile', profile]);
    }
    return arguments;
  }

  void _requireSuccess({
    required String executable,
    required List<String> arguments,
    required ProcessResult result,
    required String toolLabel,
  }) {
    if (result.exitCode == 0) {
      return;
    }
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    throw PublisherBackendException(
      '$toolLabel command failed.\n'
      'Command: $executable ${arguments.join(' ')}\n'
      'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
      'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
    );
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
    return const LineSplitter().convert('${result.stdout}'.trim()).length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner('taskkill', <String>['/PID', '$pid', '/T', '/F']);
    }
    return _shellRunner('kill', <String>['$pid']);
  }

  Future<_PublisherBackendHealth> _probeHealth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      return _PublisherBackendHealth(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const _PublisherBackendHealth(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return _PublisherBackendHealth(healthy: false, error: '$error');
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeRoute({
    required String method,
    required String path,
    required Uri uri,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      final passed = response.statusCode == 200;
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        error: passed ? null : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeWriteRoute({
    required Uri uri,
    required String couponId,
    required String userId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const path = '/coupon/redeem';
    try {
      final response = await _postRequester(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'couponId': couponId,
          'userId': userId,
        }),
      ).timeout(timeout);
      final responseStatus = _responseStatus(response.body);
      final passed =
          response.statusCode == 200 &&
          (responseStatus == 'redeemed' ||
              responseStatus == 'already_redeemed');
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: responseStatus,
        error: passed
            ? null
            : response.statusCode == 200
            ? 'Write route returned 200 without redeemed status.'
            : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  String? _responseStatus(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final status = decoded['status']?.toString().trim();
        return status == null || status.isEmpty ? null : status;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _resolveBackendRoute(Uri baseUri, String path) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBaseUrl).resolve(relativePath);
  }

  Future<_PublisherBackendHealth> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final deadline = _clock().add(timeout);
    _PublisherBackendHealth lastResult = const _PublisherBackendHealth(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );
    while (_clock().isBefore(deadline)) {
      lastResult = await _probeHealth(uri, timeout: attemptTimeout);
      if (lastResult.healthy) {
        return lastResult;
      }
      await _delay(retryDelay);
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
      await _delay(const Duration(milliseconds: 250));
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
    return lines
        .skip(lines.length > lineCount ? lines.length - lineCount : 0)
        .join('\n');
  }

  String _quoteForCmd(String value) => '"${value.replaceAll('"', '""')}"';

  String _quoteForSh(String value) => "'${value.replaceAll("'", r"'\''")}'";

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

  static DateTime _defaultClock() => DateTime.now();

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}

class _PublisherBackendHealth {
  const _PublisherBackendHealth({
    required this.healthy,
    this.statusCode,
    this.error,
  });

  final bool healthy;
  final int? statusCode;
  final String? error;
}

class _PublisherBackendAwsSeedData {
  const _PublisherBackendAwsSeedData({
    required this.home,
    required this.session,
    required this.coupons,
  });

  final Map<String, Object?> home;
  final Map<String, Object?> session;
  final List<Map<String, Object?>> coupons;
}

class _PublisherBackendAwsSettings {
  const _PublisherBackendAwsSettings({
    required this.environmentName,
    required this.miniProgramId,
    required this.backendRootPath,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.samS3Bucket,
    this.awsProfile,
  });

  final String environmentName;
  final String miniProgramId;
  final String backendRootPath;
  final String stackName;
  final String stageName;
  final String region;
  final String samS3Bucket;
  final String? awsProfile;

  static _PublisherBackendAwsSettings fromEnvironment({
    required CloudEnvironmentConfiguration environment,
    required String miniProgramRootPath,
    String? stackNameOverride,
    String? stageNameOverride,
    String? samS3BucketOverride,
  }) {
    if (environment.provider != 'aws') {
      throw PublisherBackendException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw PublisherBackendException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String? explicit, String key, String fallback) {
      if (explicit != null && explicit.trim().isNotEmpty) {
        return explicit.trim();
      }
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
    final region = requiredValue('region');
    final bucket = requiredValue('bucket');
    final stageName = optionalValue(stageNameOverride, 'stageName', 'prod');
    final samS3Bucket = optionalValue(
      samS3BucketOverride,
      'samS3Bucket',
      bucket,
    );
    final stackName = stackNameOverride?.trim().isNotEmpty == true
        ? stackNameOverride!.trim()
        : _defaultAwsPublisherBackendStackName(appId, environment.name);
    final awsProfile =
        environment.values['awsProfile']?.toString().trim().isEmpty == true
        ? null
        : environment.values['awsProfile']?.toString().trim();

    return _PublisherBackendAwsSettings(
      environmentName: environment.name,
      miniProgramId: appId,
      backendRootPath: p.join(miniProgramRootPath, 'backend', 'aws_lambda'),
      stackName: stackName,
      stageName: stageName,
      region: region,
      samS3Bucket: samS3Bucket,
      awsProfile: awsProfile,
    );
  }
}

Map<String, String> buildAwsLambdaPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
  String storageMode = 'bundled',
}) {
  if (!const <String>[
    _publisherBackendStorageBundled,
    _publisherBackendStorageDynamoDb,
  ].contains(storageMode)) {
    throw PublisherBackendException(
      'Unsupported AWS Lambda publisher backend storage mode: $storageMode',
    );
  }
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'template.yaml': _awsLambdaTemplateYaml(
      displayTitle,
      appId: appId,
      storageMode: storageMode,
    ),
    'README.md': _awsLambdaReadme(appId, displayTitle, storageMode),
    p.join('src', 'package.json'): _awsLambdaPackageJson(appId, storageMode),
    p.join('src', 'handler.mjs'): _awsLambdaHandlerSource(),
    p.join('src', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('src', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('src', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildMockPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  return <String, String>{
    'pubspec.yaml': _mockBackendPubspec(appId),
    'README.md': _mockBackendReadme(appId, displayTitle),
    p.join('bin', 'server.dart'): _mockBackendServerSource(),
    p.join('data', 'home_bootstrap.json'): _prettyJson(<String, Object?>{
      'title': '$displayTitle backend starter',
      'subtitle': 'Loaded from the publisher-owned mock backend.',
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'tier': 'Gold',
      },
      'heroImageUrl': 'https://picsum.photos/seed/${appId}_hero/960/480',
    }),
    p.join('data', 'coupons_list.json'): _prettyJson(<String, Object?>{
      'coupons': <Object?>[
        <String, Object?>{
          'id': 'coupon-10',
          'title': '10% starter coupon',
          'description': 'Backend-driven coupon item from mock data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_10/320/200',
        },
        <String, Object?>{
          'id': 'coupon-20',
          'title': '20% weekend reward',
          'description':
              'Replace this JSON with Firebase, AWS, or custom API data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_20/320/200',
        },
      ],
    }),
    p.join('data', 'session.json'): _prettyJson(<String, Object?>{
      'authenticated': true,
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'email': 'preview@example.com',
      },
      'note': 'Mock auth only. Real auth belongs on publisher servers.',
    }),
  };
}

String _mockBackendPubspec(String appId) =>
    '''
name: ${appId}_mock_backend
description: Local mock publisher backend for $appId.
publish_to: none

environment:
  sdk: '>=3.9.0 <4.0.0'
''';

String _mockBackendReadme(String appId, String title) =>
    '''
# $title mock publisher backend

This is a local-only mock backend for mini-program data calls. It is not the
mini-program delivery backend and it does not contain production secrets.

Run it from the mini-program root:

```powershell
miniprogram publisher-backend run --port 9090
```

Useful base URLs:

- desktop/web host: `http://127.0.0.1:9090/`
- Android emulator host: `http://10.0.2.2:9090/`

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url http://127.0.0.1:9090/
```

Production Firebase, AWS, GCP, or custom server SDKs should live on your
publisher backend server, not in the Flutter host app or mini_program_sdk.
''';

String _mockBackendServerSource() => r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final host = _option(arguments, 'host') ?? '0.0.0.0';
  final port = int.tryParse(_option(arguments, 'port') ?? '9090') ?? 9090;
  final dataRoot = Directory(
    _option(arguments, 'data-root') ??
        '${File.fromUri(Platform.script).parent.parent.path}${Platform.pathSeparator}data',
  );
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Mock publisher backend listening on http://$host:$port');
  stdout.writeln('Data root: ${dataRoot.path}');
  await for (final request in server) {
    await _handleRequest(request, dataRoot);
  }
}

Future<void> _handleRequest(HttpRequest request, Directory dataRoot) async {
  _writeCorsHeaders(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  final path = request.uri.path.replaceAll(RegExp(r'/+$'), '');
  if (request.method == 'GET' && path == '/health') {
    await _writeJson(request.response, <String, Object?>{
      'status': 'ok',
      'service': 'mini_program_mock_publisher_backend',
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }
  if (request.method == 'GET' && path == '/home/bootstrap') {
    await _writeDataFile(request.response, dataRoot, 'home_bootstrap.json');
    return;
  }
  if (request.method == 'GET' && path == '/coupons/list') {
    await _writeDataFile(request.response, dataRoot, 'coupons_list.json');
    return;
  }
  if (request.method == 'GET' && path == '/auth/session') {
    await _writeDataFile(request.response, dataRoot, 'session.json');
    return;
  }
  if (request.method == 'POST' && path == '/coupon/redeem') {
    final body = await utf8.decoder.bind(request).join();
    final decoded = body.trim().isEmpty ? <String, Object?>{} : jsonDecode(body);
    await _writeJson(request.response, <String, Object?>{
      'status': 'redeemed',
      'couponId': decoded is Map ? decoded['couponId']?.toString() : null,
      'message': 'Mock redeem succeeded. Replace this route on your real backend.',
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await _writeJson(request.response, <String, Object?>{
    'errorCode': 'not_found',
    'message': 'No mock backend route matches ${request.uri.path}.',
  });
}

Future<void> _writeDataFile(
  HttpResponse response,
  Directory dataRoot,
  String fileName,
) async {
  final file = File('${dataRoot.path}${Platform.pathSeparator}$fileName');
  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, <String, Object?>{
      'errorCode': 'mock_data_missing',
      'message': 'Mock data file was not found: $fileName',
    });
    return;
  }
  response.headers.contentType = ContentType.json;
  await response.addStream(file.openRead());
  await response.close();
}

Future<void> _writeJson(HttpResponse response, Object? body) async {
  response.headers.contentType = ContentType.json;
  response.write(const JsonEncoder.withIndent('  ').convert(body));
  await response.close();
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers.set('access-control-allow-origin', '*');
  response.headers.set(
    'access-control-allow-methods',
    'GET, POST, OPTIONS',
  );
  response.headers.set(
    'access-control-allow-headers',
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  );
}

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (var i = 0; i < arguments.length; i++) {
    final value = arguments[i];
    if (value.startsWith(prefix)) {
      return value.substring(prefix.length);
    }
    if (value == '--$name' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  return null;
}
''';

String _awsLambdaTemplateYaml(
  String title, {
  required String appId,
  required String storageMode,
}) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final dataTableResource = usesDynamoDb
      ? '''
  PublisherBackendDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE

'''
      : '';
  final functionEnvironment =
      '''
      Environment:
        Variables:
          PUBLISHER_BACKEND_STORAGE: $storageMode
          MINI_PROGRAM_ID: $appId
${usesDynamoDb ? '          PUBLISHER_BACKEND_TABLE_NAME: !Ref PublisherBackendDataTable\n' : ''}''';
  final functionPolicies = usesDynamoDb
      ? '''
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref PublisherBackendDataTable
'''
      : '';
  final dataTableOutput = usesDynamoDb
      ? '''
  PublisherBackendDataTableName:
    Description: DynamoDB table used by the publisher backend.
    Value: !Ref PublisherBackendDataTable
'''
      : '';
  return '''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Publisher-owned business API backend for $title.

Parameters:
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.

Globals:
  Function:
    Runtime: nodejs24.x
    Timeout: 8
    MemorySize: 256
    Architectures:
      - arm64

Resources:
  PublisherBackendHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName
      CorsConfiguration:
        AllowOrigins:
          - '*'
        AllowMethods:
          - GET
          - POST
          - OPTIONS
        AllowHeaders:
          - content-type
          - x-mini-program-access-key
          - x-mini-program-app-id
          - x-mini-program-host-app
          - x-mini-program-host-version
          - x-mini-program-id
          - x-mini-program-sdk-version
          - x-mini-program-platform
          - x-mini-program-locale

$dataTableResource  PublisherBackendFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Description: Publisher-owned mini-program business API.
$functionEnvironment$functionPolicies      Events:
        ProxyApi:
          Type: HttpApi
          Properties:
            ApiId: !Ref PublisherBackendHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  PublisherBackendBaseUrl:
    Description: Base URL for MiniProgramBackendEndpoint.baseUri.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/'
  PublisherBackendHealthUrl:
    Description: Publisher backend health URL.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/health'
  PublisherBackendFunctionName:
    Description: Publisher backend Lambda function name.
    Value: !Ref PublisherBackendFunction
  PublisherBackendStackName:
    Description: Publisher backend CloudFormation stack name.
    Value: !Ref AWS::StackName
  PublisherBackendStorageMode:
    Description: Publisher backend storage mode.
    Value: $storageMode
$dataTableOutput''';
}

String _awsLambdaReadme(String appId, String title, String storageMode) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final storageSection = usesDynamoDb
      ? '''
Storage mode: DynamoDB.

After deploying the stack, seed the starter data into DynamoDB:

```powershell
miniprogram publisher-backend aws seed --env <env-name>
miniprogram publisher-backend aws data status --env <env-name>
miniprogram publisher-backend aws smoke --env <env-name> --include-write
```

The DynamoDB table is owned by this SAM stack. `aws destroy --yes` deletes the
stack-owned table and its data. Seed retries unprocessed DynamoDB batch writes;
data status counts paginated app and redemption records.
'''
      : '''
Storage mode: bundled JSON.

The sample Lambda returns bundled JSON from `src/data/`. To create a persistent
DynamoDB starter instead, re-run scaffold with:

```powershell
miniprogram publisher-backend scaffold --template aws-lambda --storage dynamodb
```
''';
  return '''
# $title AWS Lambda publisher backend

This backend is for publisher-owned business APIs. It is not the mini-program
delivery backend. Host apps only receive the resulting `backendBaseUrl`; AWS
secrets and future database credentials stay on the publisher server.

$storageSection

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`
- `OPTIONS *`

Deploy from the mini-program root:

```powershell
miniprogram publisher-backend aws deploy --env <env-name>
```

Deploy waits for the health endpoint with cold-start-aware retries. The default
smoke command is read-only; add `--include-write` only when you want to verify
`POST /coupon/redeem`.

After deploy, connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url <PublisherBackendBaseUrl>
```

Do not put publisher backend secrets in mini-program JSON, host source, APK,
IPA, or web JavaScript.
''';
}

String _awsLambdaPackageJson(String appId, String storageMode) {
  final dependencies = storageMode == _publisherBackendStorageDynamoDb
      ? ''',
  "dependencies": {
    "@aws-sdk/client-dynamodb": "$_awsSdkJavaScriptV3Version",
    "@aws-sdk/lib-dynamodb": "$_awsSdkJavaScriptV3Version"
  }'''
      : '';
  return '''
{
  "name": "${appId}_aws_publisher_backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda publisher backend starter for $appId"$dependencies
}
''';
}

String _awsLambdaHandlerSource() => r'''
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));
const dataRoot = join(currentDir, 'data');
const storageMode = process.env.PUBLISHER_BACKEND_STORAGE ?? 'bundled';
const miniProgramId = process.env.MINI_PROGRAM_ID ?? 'mini_program';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers':
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  'content-type': 'application/json; charset=utf-8',
};

let testStore = null;
let cachedStore = null;

export function setPublisherBackendStoreForTesting(store) {
  testStore = store;
  cachedStore = null;
}

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? event.httpMethod ?? 'GET';
  const path = normalizePath(
    event.rawPath ?? event.path ?? '/',
    event.requestContext?.stage,
  );

  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: corsHeaders,
      body: '',
    };
  }

  const store = await resolveStore();

  if (method === 'GET' && path === '/health') {
    return json(200, {
      status: 'ok',
      service: 'mini_program_aws_publisher_backend',
      storageMode,
      generatedAtUtc: new Date().toISOString(),
    });
  }

  if (method === 'GET' && path === '/home/bootstrap') {
    return jsonFromStore(await store.homeBootstrap(), 'home/bootstrap');
  }

  if (method === 'GET' && path === '/coupons/list') {
    return jsonFromStore(await store.couponsList(), 'coupons/list');
  }

  if (method === 'GET' && path === '/auth/session') {
    return jsonFromStore(await store.authSession(), 'auth/session');
  }

  if (method === 'POST' && path === '/coupon/redeem') {
    const body = parseJsonBody(event.body, event.isBase64Encoded);
    const result = await store.redeemCoupon(body);
    return json(result.statusCode, result.body);
  }

  return json(404, {
    errorCode: 'not_found',
    message: `No publisher backend route matches ${path}.`,
  });
}

async function resolveStore() {
  if (testStore) {
    return testStore;
  }
  if (cachedStore) {
    return cachedStore;
  }
  cachedStore =
    storageMode === 'dynamodb'
      ? await createDynamoDbStore()
      : new BundledJsonStore(dataRoot);
  return cachedStore;
}

function jsonFromStore(body, label) {
  if (body == null) {
    return json(404, {
      errorCode: 'backend_data_missing',
      message: `Backend data was not found: ${label}`,
    });
  }
  return json(200, body);
}

class BundledJsonStore {
  constructor(root) {
    this.root = root;
  }

  homeBootstrap() {
    return this.dataFile('home_bootstrap.json');
  }

  couponsList() {
    return this.dataFile('coupons_list.json');
  }

  authSession() {
    return this.dataFile('session.json');
  }

  async redeemCoupon(body) {
    return {
      statusCode: body?.couponId ? 200 : 400,
      body: body?.couponId
        ? {
            status: 'redeemed',
            couponId: body.couponId,
            message:
              'AWS sample redeem succeeded. Use --storage dynamodb for persistent redemptions.',
          }
        : {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          },
    };
  }

  async dataFile(fileName) {
    try {
      const raw = await readFile(join(this.root, fileName), 'utf8');
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  }
}

async function createDynamoDbStore() {
  const tableName = process.env.PUBLISHER_BACKEND_TABLE_NAME;
  if (!tableName) {
    throw new Error('PUBLISHER_BACKEND_TABLE_NAME is required for DynamoDB storage.');
  }
  const [{ DynamoDBClient }, dynamodbLib] = await Promise.all([
    import('@aws-sdk/client-dynamodb'),
    import('@aws-sdk/lib-dynamodb'),
  ]);
  const docClient = dynamodbLib.DynamoDBDocumentClient.from(
    new DynamoDBClient({}),
  );
  return new DynamoDbStore({
    docClient,
    tableName,
    appId: miniProgramId,
    commands: dynamodbLib,
  });
}

class DynamoDbStore {
  constructor({ docClient, tableName, appId, commands }) {
    this.docClient = docClient;
    this.tableName = tableName;
    this.appPk = `APP#${appId}`;
    this.redemptionsPk = `APP#${appId}#REDEMPTIONS`;
    this.GetCommand = commands.GetCommand;
    this.PutCommand = commands.PutCommand;
    this.QueryCommand = commands.QueryCommand;
  }

  homeBootstrap() {
    return this.payloadFor('HOME#bootstrap');
  }

  async couponsList() {
    const items = [];
    let exclusiveStartKey;
    do {
      const response = await this.docClient.send(
        new this.QueryCommand({
          TableName: this.tableName,
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
          ExpressionAttributeValues: {
            ':pk': this.appPk,
            ':prefix': 'COUPON#',
          },
          ConsistentRead: true,
          ExclusiveStartKey: exclusiveStartKey,
        }),
      );
      items.push(...(response.Items ?? []));
      exclusiveStartKey = response.LastEvaluatedKey;
    } while (exclusiveStartKey);
    const coupons = items
      .sort((left, right) => (left.sortIndex ?? 0) - (right.sortIndex ?? 0))
      .map((item) => item.payload)
      .filter((item) => item != null);
    return { coupons };
  }

  authSession() {
    return this.payloadFor('SESSION#demo');
  }

  async redeemCoupon(body) {
    const couponId = body?.couponId?.toString()?.trim();
    if (!couponId) {
      return {
        statusCode: 400,
        body: {
          errorCode: 'missing_coupon_id',
          message: 'couponId is required.',
        },
      };
    }

    const coupon = await this.payloadFor(`COUPON#${couponId}`);
    if (coupon == null) {
      return {
        statusCode: 404,
        body: {
          errorCode: 'coupon_not_found',
          couponId,
          message: `Coupon was not found: ${couponId}`,
        },
      };
    }

    const userId =
      body?.userId?.toString()?.trim() ||
      body?.user?.id?.toString()?.trim() ||
      'anonymous';
    const redeemedAtUtc = new Date().toISOString();
    const redemption = {
      status: 'redeemed',
      couponId,
      userId,
      redeemedAtUtc,
    };

    try {
      await this.docClient.send(
        new this.PutCommand({
          TableName: this.tableName,
          Item: {
            pk: this.redemptionsPk,
            sk: `USER#${userId}#COUPON#${couponId}`,
            recordType: 'redemption',
            couponId,
            userId,
            payload: redemption,
            createdAtUtc: redeemedAtUtc,
          },
          ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
        }),
      );
      return {
        statusCode: 200,
        body: {
          ...redemption,
          message: 'Coupon redeemed.',
        },
      };
    } catch (error) {
      if (error?.name === 'ConditionalCheckFailedException') {
        return {
          statusCode: 200,
          body: {
            status: 'already_redeemed',
            couponId,
            userId,
            message: 'Coupon was already redeemed for this user.',
          },
        };
      }
      throw error;
    }
  }

  async payloadFor(sk) {
    const response = await this.docClient.send(
      new this.GetCommand({
        TableName: this.tableName,
        Key: {
          pk: this.appPk,
          sk,
        },
        ConsistentRead: true,
      }),
    );
    return response.Item?.payload ?? null;
  }
}

function parseJsonBody(rawBody, isBase64Encoded) {
  if (!rawBody) {
    return {};
  }
  const decoded = isBase64Encoded
    ? Buffer.from(rawBody, 'base64').toString('utf8')
    : rawBody;
  try {
    return JSON.parse(decoded);
  } catch (_) {
    return {};
  }
}

function normalizePath(rawPath, stage) {
  let value = rawPath.replace(/\/+$/g, '');
  if (stage && stage !== '$default') {
    const stagePrefix = `/${stage}`;
    if (value === stagePrefix) {
      value = '/';
    } else if (value.startsWith(`${stagePrefix}/`)) {
      value = value.substring(stagePrefix.length);
    }
  }
  return value.length === 0 ? '/' : value;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body, null, 2),
  };
}
''';

String _defaultAwsPublisherBackendStackName(
  String appId,
  String environmentName,
) {
  final safeAppId = _safeAwsSegment(appId);
  final safeEnv = _safeAwsSegment(environmentName);
  return 'mini-program-publisher-backend-$safeAppId-$safeEnv';
}

String _appPartitionKey(String appId) => 'APP#$appId';

String _redemptionsPartitionKey(String appId) => 'APP#$appId#REDEMPTIONS';

String _safeAwsSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'default' : normalized;
}

String? _readManifestIdSync(String miniProgramRootPath) {
  try {
    final file = File(p.join(miniProgramRootPath, 'manifest.json'));
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) {
      final id = decoded['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _titleFromAppId(String appId) => appId
    .split(RegExp(r'[_-]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
