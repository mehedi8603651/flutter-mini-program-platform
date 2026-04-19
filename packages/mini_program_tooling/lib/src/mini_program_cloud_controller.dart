import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'local_cli_state.dart';
import 'miniprogram_doctor.dart';

typedef MiniProgramCloudProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

Future<ProcessResult> _defaultMiniProgramCloudProcessRunner(
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
    runInShell: Platform.isWindows,
  );
}

class MiniProgramCloudException implements Exception {
  const MiniProgramCloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramCloudDeployRequest {
  const MiniProgramCloudDeployRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudStatusRequest {
  const MiniProgramCloudStatusRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudOutputsRequest {
  const MiniProgramCloudOutputsRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudLogsRequest {
  const MiniProgramCloudLogsRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    this.since = '1h',
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String since;
}

class MiniProgramCloudDestroyRequest {
  const MiniProgramCloudDestroyRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudDoctorRequest {
  const MiniProgramCloudDoctorRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
}

class MiniProgramCloudRollbackRequest {
  const MiniProgramCloudRollbackRequest({
    required this.resolvedEnvironmentState,
    required this.environment,
    required this.miniProgramId,
    required this.version,
  });

  final ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramId;
  final String version;
}

class MiniProgramCloudDeployResult {
  const MiniProgramCloudDeployResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.bucketName,
    required this.backendProjectRootPath,
    required this.outputs,
    required this.deployedAtUtc,
    this.apiBaseUrl,
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
  final String bucketName;
  final String backendProjectRootPath;
  final Map<String, String> outputs;
  final String deployedAtUtc;
  final String? apiBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class MiniProgramCloudStatusResult {
  const MiniProgramCloudStatusResult({
    required this.provider,
    required this.environmentName,
    required this.stackName,
    required this.stageName,
    required this.region,
    required this.stackExists,
    required this.outputs,
    this.stackStatus,
    this.stackStatusReason,
    this.apiBaseUrl,
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
  final String? stackStatus;
  final String? stackStatusReason;
  final Map<String, String> outputs;
  final String? apiBaseUrl;
  final String? healthUrl;
  final bool? healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class MiniProgramCloudOutputsResult {
  const MiniProgramCloudOutputsResult({
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

class MiniProgramCloudLogsResult {
  const MiniProgramCloudLogsResult({
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

class MiniProgramCloudDestroyResult {
  const MiniProgramCloudDestroyResult({
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

class MiniProgramCloudDoctorResult {
  const MiniProgramCloudDoctorResult({required this.checks});

  final List<MiniprogramDoctorCheck> checks;

  bool get hasErrors =>
      checks.any((check) => check.status == MiniprogramDoctorCheckStatus.error);
}

class MiniProgramCloudRollbackResult {
  const MiniProgramCloudRollbackResult({
    required this.provider,
    required this.environmentName,
    required this.miniProgramId,
    required this.version,
    required this.bucketName,
    required this.region,
    required this.catalogKey,
    required this.releaseKey,
    required this.rolledBackAtUtc,
  });

  final String provider;
  final String environmentName;
  final String miniProgramId;
  final String version;
  final String bucketName;
  final String region;
  final String catalogKey;
  final String releaseKey;
  final String rolledBackAtUtc;
}

class MiniProgramCloudController {
  MiniProgramCloudController({
    MiniProgramCloudProcessRunner processRunner =
        _defaultMiniProgramCloudProcessRunner,
    http.Client? httpClient,
  }) : _processRunner = processRunner,
       _httpClient = httpClient ?? http.Client();

  final MiniProgramCloudProcessRunner _processRunner;
  final http.Client _httpClient;

  Future<MiniProgramCloudDeployResult> deploy(
    MiniProgramCloudDeployRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final backendProjectRootPath = await _ensureAwsBackendProject(
      request.resolvedEnvironmentState,
    );

    await _runSamCommand(settings, <String>[
      'build',
      '--template-file',
      p.join(backendProjectRootPath, 'template.yaml'),
    ], workingDirectory: backendProjectRootPath);

    final parameterOverrides = <String>[
      'ArtifactBucketName=${settings.bucketName}',
      'ArtifactsPrefix=${settings.artifactsPrefix}',
      'MetadataPrefix=${settings.metadataPrefix}',
      'StageName=${settings.stageName}',
      'FunctionTimeoutSeconds=${settings.functionTimeoutSeconds}',
      'FunctionMemorySize=${settings.functionMemorySize}',
      'LogLevel=${settings.logLevel}',
    ];
    await _runSamCommand(settings, <String>[
      'deploy',
      '--template-file',
      p.join(backendProjectRootPath, 'template.yaml'),
      '--stack-name',
      settings.stackName,
      '--region',
      settings.region,
      '--capabilities',
      'CAPABILITY_IAM',
      '--s3-bucket',
      settings.samS3Bucket,
      '--parameter-overrides',
      ...parameterOverrides,
      '--no-confirm-changeset',
      '--no-fail-on-empty-changeset',
    ], workingDirectory: backendProjectRootPath);

    final stack = await _describeStack(settings);
    if (stack == null) {
      throw const MiniProgramCloudException(
        'SAM deploy finished but the AWS CloudFormation stack could not be described.',
      );
    }
    final outputs = _extractStackOutputs(stack);
    final health = await _probeHealth(outputs['HealthUrl']);

    return MiniProgramCloudDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      bucketName: settings.bucketName,
      backendProjectRootPath: backendProjectRootPath,
      outputs: outputs,
      apiBaseUrl: outputs['BackendApiBaseUrl'],
      healthUrl: outputs['HealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      deployedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<MiniProgramCloudStatusResult> status(
    MiniProgramCloudStatusRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final stack = await _describeStack(settings);
    if (stack == null) {
      return MiniProgramCloudStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        stackName: settings.stackName,
        stageName: settings.stageName,
        region: settings.region,
        stackExists: false,
        outputs: const <String, String>{},
      );
    }

    final outputs = _extractStackOutputs(stack);
    final health = await _probeHealth(outputs['HealthUrl']);
    return MiniProgramCloudStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      stageName: settings.stageName,
      region: settings.region,
      stackExists: true,
      stackStatus: stack['StackStatus']?.toString(),
      stackStatusReason: stack['StackStatusReason']?.toString(),
      outputs: outputs,
      apiBaseUrl: outputs['BackendApiBaseUrl'],
      healthUrl: outputs['HealthUrl'],
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
    );
  }

  Future<MiniProgramCloudOutputsResult> outputs(
    MiniProgramCloudOutputsRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final stack = await _describeStack(settings);
    if (stack == null) {
      throw MiniProgramCloudException(
        'AWS stack "${settings.stackName}" was not found in region '
        '"${settings.region}". Run `miniprogram cloud deploy` first.',
      );
    }

    return MiniProgramCloudOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      outputs: _extractStackOutputs(stack),
    );
  }

  Future<MiniProgramCloudLogsResult> logs(
    MiniProgramCloudLogsRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final lambdaFunctionName = await _resolveLambdaFunctionName(settings);
    if (lambdaFunctionName == null) {
      throw MiniProgramCloudException(
        'No Lambda function resource was found for stack "${settings.stackName}". '
        'Run `miniprogram cloud deploy` first.',
      );
    }

    final result = await _runCommand('aws', <String>[
      ..._awsGlobalArguments(settings),
      'logs',
      'tail',
      '/aws/lambda/$lambdaFunctionName',
      '--since',
      request.since,
    ]);
    _requireSuccess(
      executable: 'aws',
      arguments: <String>[
        ..._awsGlobalArguments(settings),
        'logs',
        'tail',
        '/aws/lambda/$lambdaFunctionName',
        '--since',
        request.since,
      ],
      result: result,
      toolLabel: 'AWS CLI',
    );

    return MiniProgramCloudLogsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      lambdaFunctionName: lambdaFunctionName,
      since: request.since,
      stdoutText: '${result.stdout}'.trim(),
      stderrText: '${result.stderr}'.trim(),
    );
  }

  Future<MiniProgramCloudDestroyResult> destroy(
    MiniProgramCloudDestroyRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
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

    return MiniProgramCloudDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: settings.stackName,
      region: settings.region,
      deletedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<MiniProgramCloudDoctorResult> doctor(
    MiniProgramCloudDoctorRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    final checks = <MiniprogramDoctorCheck>[];

    checks.add(await _checkCommandAvailable('aws', <String>['--version']));
    checks.add(await _checkCommandAvailable('sam', <String>['--version']));
    checks.add(await _checkCommandAvailable('node', <String>['--version']));

    checks.add(await _checkAwsIdentity(settings));
    checks.add(await _checkBucketVersioning(settings));
    checks.add(await _checkCloudStack(settings));

    return MiniProgramCloudDoctorResult(checks: checks);
  }

  Future<MiniProgramCloudRollbackResult> rollback(
    MiniProgramCloudRollbackRequest request,
  ) async {
    final settings = AwsCloudStackSettings.fromEnvironment(request.environment);
    _validateRollbackVersion(request.version);
    _validateSafeSegment(request.miniProgramId, 'miniProgramId');
    final releaseKey = _objectJoin(
      settings.metadataPrefix,
      'releases',
      request.miniProgramId,
      '${request.version}.json',
    );
    final catalogKey = _objectJoin(
      settings.metadataPrefix,
      'catalog',
      '${request.miniProgramId}.json',
    );

    final tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_cloud_rollback_',
    );
    try {
      final releaseFile = p.join(tempDirectory.path, 'release.json');
      final catalogFile = p.join(tempDirectory.path, 'catalog.json');
      final updatedCatalogFile = p.join(
        tempDirectory.path,
        'catalog.updated.json',
      );

      await _downloadObject(
        settings,
        key: releaseKey,
        destinationPath: releaseFile,
      );
      await _downloadObject(
        settings,
        key: catalogKey,
        destinationPath: catalogFile,
      );

      final catalogJson = _readJsonFile(catalogFile);
      catalogJson['latestVersion'] = request.version;
      catalogJson['releaseKey'] = releaseKey;
      catalogJson['updatedAtUtc'] = DateTime.now().toUtc().toIso8601String();
      await File(
        updatedCatalogFile,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(catalogJson));

      await _putJsonObject(
        settings,
        key: catalogKey,
        localSourcePath: updatedCatalogFile,
        cacheControl: 'no-cache, no-store, must-revalidate',
      );

      return MiniProgramCloudRollbackResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        miniProgramId: request.miniProgramId,
        version: request.version,
        bucketName: settings.bucketName,
        region: settings.region,
        catalogKey: catalogKey,
        releaseKey: releaseKey,
        rolledBackAtUtc: DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<MiniprogramDoctorCheck> _checkCommandAvailable(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await _runCommand(executable, arguments);
      if (result.exitCode == 0) {
        final output = '${result.stdout}'.trim();
        final errorOutput = '${result.stderr}'.trim();
        final summary = output.isNotEmpty ? output : errorOutput;
        return MiniprogramDoctorCheck(
          label: '$executable available',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: summary.isEmpty ? 'available' : summary,
        );
      }
      return MiniprogramDoctorCheck(
        label: '$executable available',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'failed to run',
        detail: '${result.stderr}'.trim(),
      );
    } on ProcessException catch (error) {
      return MiniprogramDoctorCheck(
        label: '$executable available',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'not found on PATH',
        detail: error.toString(),
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkAwsIdentity(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final identity = await _runAwsJsonCommand(settings, <String>[
        'sts',
        'get-caller-identity',
        '--output',
        'json',
      ]);
      final account = identity['Account']?.toString() ?? 'unknown';
      final arn = identity['Arn']?.toString() ?? 'unknown';
      return MiniprogramDoctorCheck(
        label: 'AWS credentials',
        status: MiniprogramDoctorCheckStatus.ok,
        summary: 'resolved caller identity',
        detail: 'Account: $account\nARN: $arn',
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS credentials',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not resolve caller identity',
        detail: error.message,
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkBucketVersioning(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final response = await _runAwsJsonCommand(settings, <String>[
        's3api',
        'get-bucket-versioning',
        '--bucket',
        settings.bucketName,
        '--output',
        'json',
      ]);
      final status = response['Status']?.toString().trim();
      if (status == 'Enabled') {
        return MiniprogramDoctorCheck(
          label: 'AWS artifact bucket',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: 'versioning enabled',
          detail: 'Bucket: ${settings.bucketName}\nRegion: ${settings.region}',
        );
      }
      return MiniprogramDoctorCheck(
        label: 'AWS artifact bucket',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'versioning not enabled',
        detail: 'Bucket: ${settings.bucketName}\nRegion: ${settings.region}',
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS artifact bucket',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not inspect bucket',
        detail: error.message,
      );
    }
  }

  Future<MiniprogramDoctorCheck> _checkCloudStack(
    AwsCloudStackSettings settings,
  ) async {
    try {
      final stack = await _describeStack(settings);
      if (stack == null) {
        return MiniprogramDoctorCheck(
          label: 'AWS cloud stack',
          status: MiniprogramDoctorCheckStatus.warning,
          summary: 'stack not deployed yet',
          detail: 'Stack: ${settings.stackName}\nRegion: ${settings.region}',
        );
      }
      final outputs = _extractStackOutputs(stack);
      final health = await _probeHealth(outputs['HealthUrl']);
      final status = stack['StackStatus']?.toString() ?? 'unknown';
      return MiniprogramDoctorCheck(
        label: 'AWS cloud stack',
        status: health.healthy == false
            ? MiniprogramDoctorCheckStatus.warning
            : MiniprogramDoctorCheckStatus.ok,
        summary: status,
        detail: [
          'Stack: ${settings.stackName}',
          if (outputs['BackendApiBaseUrl'] != null)
            'BackendApiBaseUrl: ${outputs['BackendApiBaseUrl']}',
          if (health.healthy != null) 'Healthy: ${health.healthy}',
          if (health.statusCode != null)
            'Health status code: ${health.statusCode}',
          if (health.error != null) 'Health detail: ${health.error}',
        ].join('\n'),
      );
    } on MiniProgramCloudException catch (error) {
      return MiniprogramDoctorCheck(
        label: 'AWS cloud stack',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'could not inspect stack',
        detail: error.message,
      );
    }
  }

  Future<String> _ensureAwsBackendProject(
    ResolvedLocalCliEnvironmentState resolvedEnvironmentState,
  ) async {
    final projectRootPath = p.join(
      resolvedEnvironmentState.rootPath,
      '.mini_program',
      'cloud',
      'aws_backend',
    );
    await Directory(p.join(projectRootPath, 'src')).create(recursive: true);

    final repoInfraRoot = resolvedEnvironmentState.state.repoRootPath == null
        ? null
        : p.join(
            resolvedEnvironmentState.state.repoRootPath!,
            'infra',
            'aws',
            'mini_program_cloud_api',
          );
    final copiedFromRepo =
        repoInfraRoot != null &&
        await _copyRepoAwsBackendProject(
          sourceRootPath: repoInfraRoot,
          destinationRootPath: projectRootPath,
        );
    if (!copiedFromRepo) {
      await File(
        p.join(projectRootPath, 'template.yaml'),
      ).writeAsString(_bundledAwsTemplateYaml);
      await File(
        p.join(projectRootPath, 'src', 'handler.mjs'),
      ).writeAsString(_bundledAwsHandlerSource);
      await File(
        p.join(projectRootPath, 'src', 'package.json'),
      ).writeAsString(_bundledAwsPackageJson);
    }

    return projectRootPath;
  }

  Future<bool> _copyRepoAwsBackendProject({
    required String sourceRootPath,
    required String destinationRootPath,
  }) async {
    final sourceTemplate = File(p.join(sourceRootPath, 'template.yaml'));
    final sourceHandler = File(p.join(sourceRootPath, 'src', 'handler.mjs'));
    final sourcePackage = File(p.join(sourceRootPath, 'src', 'package.json'));
    if (!await sourceTemplate.exists() ||
        !await sourceHandler.exists() ||
        !await sourcePackage.exists()) {
      return false;
    }

    await File(
      p.join(destinationRootPath, 'template.yaml'),
    ).writeAsString(await sourceTemplate.readAsString());
    await File(
      p.join(destinationRootPath, 'src', 'handler.mjs'),
    ).writeAsString(await sourceHandler.readAsString());
    await File(
      p.join(destinationRootPath, 'src', 'package.json'),
    ).writeAsString(await sourcePackage.readAsString());
    return true;
  }

  Future<ProcessResult> _runCommand(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      return await _processRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      throw MiniProgramCloudException(
        'Failed to launch $executable. Make sure it is installed and on your PATH.\n$error',
      );
    }
  }

  Future<void> _runSamCommand(
    AwsCloudStackSettings settings,
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final arguments = <String>[
      ...commandArguments,
      if (settings.awsProfile != null) '--profile',
      if (settings.awsProfile != null) settings.awsProfile!,
    ];
    final result = await _runCommand(
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
    AwsCloudStackSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _runCommand('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    AwsCloudStackSettings settings,
    List<String> commandArguments, {
    bool allowEmptyJsonOutput = false,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _runCommand('aws', arguments);
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
      throw MiniProgramCloudException(
        'AWS CLI returned no JSON output for command: aws ${arguments.join(' ')}',
      );
    }

    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw MiniProgramCloudException(
        'AWS CLI returned non-object JSON for command: aws ${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _downloadObject(
    AwsCloudStackSettings settings, {
    required String key,
    required String destinationPath,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      's3api',
      'get-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      destinationPath,
      '--output',
      'json',
    ];
    final result = await _runCommand('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<void> _putJsonObject(
    AwsCloudStackSettings settings, {
    required String key,
    required String localSourcePath,
    required String cacheControl,
  }) async {
    await _runAwsJsonCommand(settings, <String>[
      's3api',
      'put-object',
      '--bucket',
      settings.bucketName,
      '--key',
      key,
      '--body',
      localSourcePath,
      '--cache-control',
      cacheControl,
      '--content-type',
      'application/json',
      '--output',
      'json',
    ]);
  }

  Future<Map<String, dynamic>?> _describeStack(
    AwsCloudStackSettings settings,
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
    final result = await _runCommand('aws', arguments);
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
      throw MiniProgramCloudException(
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
    AwsCloudStackSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'describe-stack-resources',
      '--stack-name',
      settings.stackName,
      '--output',
      'json',
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

  Future<_HealthProbeResult> _probeHealth(String? healthUrl) async {
    if (healthUrl == null || healthUrl.trim().isEmpty) {
      return const _HealthProbeResult();
    }

    try {
      final response = await _httpClient
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));
      return _HealthProbeResult(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      return _HealthProbeResult(healthy: false, error: error.toString());
    }
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

  List<String> _awsGlobalArguments(AwsCloudStackSettings settings) {
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
    throw MiniProgramCloudException(
      '$toolLabel command failed.\n'
      'Command: $executable ${arguments.join(' ')}\n'
      'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
      'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
    );
  }

  Map<String, dynamic> _readJsonFile(String filePath) {
    final decoded = jsonDecode(File(filePath).readAsStringSync());
    if (decoded is! Map) {
      throw MiniProgramCloudException('Expected a JSON object in $filePath.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  void _validateRollbackVersion(String version) {
    try {
      Version.parse(version.trim());
    } on FormatException {
      throw MiniProgramCloudException(
        'Rollback version "$version" is not a valid semantic version.',
      );
    }
  }

  void _validateSafeSegment(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
      throw MiniProgramCloudException('Path segment "$label" is invalid.');
    }
  }
}

class AwsCloudStackSettings {
  const AwsCloudStackSettings({
    required this.bucketName,
    required this.region,
    required this.artifactsPrefix,
    required this.metadataPrefix,
    required this.stackName,
    required this.stageName,
    required this.samS3Bucket,
    required this.functionTimeoutSeconds,
    required this.functionMemorySize,
    required this.logLevel,
    this.cloudFrontBaseUrl,
    this.apiBaseUrl,
    this.awsProfile,
  });

  final String bucketName;
  final String region;
  final String artifactsPrefix;
  final String metadataPrefix;
  final String stackName;
  final String stageName;
  final String samS3Bucket;
  final int functionTimeoutSeconds;
  final int functionMemorySize;
  final String logLevel;
  final String? cloudFrontBaseUrl;
  final String? apiBaseUrl;
  final String? awsProfile;

  factory AwsCloudStackSettings.fromEnvironment(
    CloudEnvironmentConfiguration environment,
  ) {
    if (environment.provider != 'aws') {
      throw MiniProgramCloudException(
        'Cloud environment "${environment.name}" is not an aws environment.',
      );
    }

    String requiredValue(String key) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw MiniProgramCloudException(
          'Cloud environment "${environment.name}" is missing required aws '
          'setting "$key". Run `miniprogram env configure ${environment.name} '
          '--provider aws ...` again.',
        );
      }
      return value;
    }

    String optionalValue(String key, String fallback) {
      final rawValue = environment.values[key];
      final value = rawValue?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    int optionalInt(String key, int fallback) {
      final rawValue = environment.values[key];
      if (rawValue == null) {
        return fallback;
      }
      final parsed = int.tryParse(rawValue.toString().trim());
      if (parsed == null) {
        throw MiniProgramCloudException(
          'Cloud environment "${environment.name}" has a non-integer aws '
          'setting "$key".',
        );
      }
      return parsed;
    }

    final stackName = optionalValue(
      'stackName',
      _defaultStackName(environment.name),
    );
    final stageName = optionalValue('stageName', 'prod');
    final samS3Bucket = optionalValue('samS3Bucket', requiredValue('bucket'));
    final logLevel = optionalValue('logLevel', 'INFO').toUpperCase();
    if (!const <String>['DEBUG', 'INFO', 'WARN', 'ERROR'].contains(logLevel)) {
      throw MiniProgramCloudException(
        'Cloud environment "${environment.name}" has an unsupported aws '
        'logLevel "$logLevel".',
      );
    }

    return AwsCloudStackSettings(
      bucketName: requiredValue('bucket'),
      region: requiredValue('region'),
      artifactsPrefix: requiredValue('artifactsPrefix'),
      metadataPrefix: requiredValue('metadataPrefix'),
      stackName: stackName,
      stageName: stageName,
      samS3Bucket: samS3Bucket,
      functionTimeoutSeconds: optionalInt('functionTimeoutSeconds', 15),
      functionMemorySize: optionalInt('functionMemorySize', 256),
      logLevel: logLevel,
      cloudFrontBaseUrl: environment.values['cloudFrontBaseUrl']?.toString(),
      apiBaseUrl: environment.values['apiBaseUrl']?.toString(),
      awsProfile:
          environment.values['awsProfile']?.toString().trim().isEmpty == true
          ? null
          : environment.values['awsProfile']?.toString().trim(),
    );
  }
}

class _HealthProbeResult {
  const _HealthProbeResult({this.healthy, this.statusCode, this.error});

  final bool? healthy;
  final int? statusCode;
  final String? error;
}

String _defaultStackName(String environmentName) {
  final normalized = environmentName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = normalized.isEmpty ? 'default' : normalized;
  return 'mini-program-cloud-$suffix';
}

String _objectJoin(
  String first,
  String second, [
  String? third,
  String? fourth,
  String? fifth,
]) => <String?>[first, second, third, fourth, fifth]
    .where((value) => value != null)
    .cast<String>()
    .map((value) => value.replaceAll('\\', '/').trim())
    .where((value) => value.isNotEmpty)
    .map((value) => value.replaceAll(RegExp(r'^/+|/+$'), ''))
    .where((value) => value.isNotEmpty)
    .join('/');

const String _bundledAwsTemplateYaml = r'''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  Serverless mini-program delivery API for AWS.
  It exposes backend-style /api routes through API Gateway and Lambda while
  reading published mini-program artifacts from S3.

Parameters:
  ArtifactBucketName:
    Type: String
    Description: S3 bucket that stores artifacts/ and metadata/ from cloud publish.
  ArtifactsPrefix:
    Type: String
    Default: artifacts
    Description: S3 object prefix for immutable mini-program artifacts.
  MetadataPrefix:
    Type: String
    Default: metadata
    Description: S3 object prefix for catalog and release metadata files.
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.
  FunctionTimeoutSeconds:
    Type: Number
    Default: 15
    MinValue: 3
    MaxValue: 30
    Description: Lambda timeout in seconds.
  FunctionMemorySize:
    Type: Number
    Default: 256
    AllowedValues:
      - 128
      - 256
      - 512
      - 1024
    Description: Lambda memory size in MB.
  LogLevel:
    Type: String
    Default: INFO
    AllowedValues:
      - DEBUG
      - INFO
      - WARN
      - ERROR
    Description: Log verbosity for the delivery Lambda.

Resources:
  MiniProgramDeliveryHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName

  MiniProgramDeliveryFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Runtime: nodejs20.x
      MemorySize: !Ref FunctionMemorySize
      Timeout: !Ref FunctionTimeoutSeconds
      Architectures:
        - arm64
      Environment:
        Variables:
          ARTIFACT_BUCKET_NAME: !Ref ArtifactBucketName
          ARTIFACTS_PREFIX: !Ref ArtifactsPrefix
          METADATA_PREFIX: !Ref MetadataPrefix
          LOG_LEVEL: !Ref LogLevel
      Policies:
        - Statement:
            - Sid: ReadPublishedMiniProgramBucket
              Effect: Allow
              Action:
                - s3:GetObject
              Resource: !Sub arn:${AWS::Partition}:s3:::${ArtifactBucketName}/*
            - Sid: ListPublishedMiniProgramBucket
              Effect: Allow
              Action:
                - s3:ListBucket
              Resource: !Sub arn:${AWS::Partition}:s3:::${ArtifactBucketName}
      Events:
        ApiProxy:
          Type: HttpApi
          Properties:
            ApiId: !Ref MiniProgramDeliveryHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  HttpApiId:
    Description: API Gateway HTTP API id.
    Value: !Ref MiniProgramDeliveryHttpApi

  HttpApiStageUrl:
    Description: Root invoke URL for the deployed API stage.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/

  BackendApiBaseUrl:
    Description: Base URL to use as MINI_PROGRAM_BACKEND_BASE_URL in Flutter hosts.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/api/

  HealthUrl:
    Description: Health endpoint for the deployed API.
    Value: !Sub https://${MiniProgramDeliveryHttpApi}.execute-api.${AWS::Region}.${AWS::URLSuffix}/${StageName}/health

  ArtifactBucketName:
    Description: S3 bucket used by the API.
    Value: !Ref ArtifactBucketName
''';

const String _bundledAwsPackageJson = '''
{
  "name": "mini-program-cloud-api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda mini-program delivery API backed by S3-published artifacts.",
  "dependencies": {
    "@aws-sdk/client-s3": "^3.922.0"
  }
}
''';

const String _bundledAwsHandlerSource = r'''
import { GetObjectCommand, HeadObjectCommand, ListObjectsV2Command, S3Client } from '@aws-sdk/client-s3';

const backendJsonContentType = 'application/json; charset=utf-8';
const logLevel = (process.env.LOG_LEVEL || 'INFO').trim().toUpperCase();
const artifactBucketName = requiredEnv('ARTIFACT_BUCKET_NAME');
const artifactsPrefix = normalizePrefix(process.env.ARTIFACTS_PREFIX || 'artifacts');
const metadataPrefix = normalizePrefix(process.env.METADATA_PREFIX || 'metadata');

const s3 = new S3Client({});

export const handler = async (event) => {
  const method = resolveMethod(event);
  const path = resolvePath(event);
  const pathSegments = splitPath(path);
  const query = event?.queryStringParameters ?? {};
  const traceId = resolveTraceId(event);

  logInfo('Received delivery API request.', { traceId, method, path, query });

  try {
    if (method === 'OPTIONS') {
      return jsonResponse({ statusCode: 204, body: '', traceId });
    }

    if (method === 'GET' && matches(pathSegments, ['health'])) {
      return jsonResponse({
        statusCode: 200,
        bodyObject: withTraceId({
          responseType: 'health',
          statusCode: 200,
          status: 'ok',
          service: 'mini_program_cloud_api',
        }, traceId),
        traceId,
      });
    }

    if (method === 'GET' && pathSegments.length === 3 && pathSegments[0] === 'api' && pathSegments[1] === 'discovery' && isCatalogSegment(pathSegments[2])) {
      return handleDiscovery({ traceId, query });
    }

    if (method === 'GET' && pathSegments.length === 4 && pathSegments[0] === 'api' && pathSegments[1] === 'manifests' && isLatestSegment(pathSegments[3])) {
      return handleLatestManifest({ traceId, miniProgramId: pathSegments[2], query });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'debug' && pathSegments[2] === 'manifests' && isDecisionSegment(pathSegments[4])) {
      return handleDebugDecision({ traceId, miniProgramId: pathSegments[3], query });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'manifests' && pathSegments[3] === 'versions') {
      const version = stripJsonSuffix(pathSegments[4]);
      if (version == null) {
        return badRequest('Manifest version path is invalid.', traceId);
      }
      return handleVersionedManifest({ traceId, miniProgramId: pathSegments[2], version });
    }

    if (method === 'GET' && pathSegments.length === 5 && pathSegments[0] === 'api' && pathSegments[1] === 'screens') {
      const screenId = stripJsonSuffix(pathSegments[4]);
      if (screenId == null) {
        return badRequest('Screen path is invalid.', traceId);
      }
      return handleScreen({ traceId, miniProgramId: pathSegments[2], version: pathSegments[3], screenId });
    }

    if (method === 'POST' && pathSegments.length >= 3 && pathSegments[0] === 'api' && pathSegments[1] === 'secure') {
      return notImplemented('Secure API routes are not implemented in the AWS cloud backend yet.', traceId);
    }

    if (method !== 'GET') {
      return errorResponse({
        statusCode: 405,
        responseType: 'backend_route_error',
        errorCode: 'method_not_allowed',
        message: 'Only GET requests and documented secure POST routes are supported.',
        traceId,
      });
    }

    return errorResponse({
      statusCode: 404,
      responseType: 'backend_route_error',
      errorCode: 'not_found',
      message: `No backend route matches "${path}".`,
      traceId,
    });
  } catch (error) {
    if (error instanceof DeliveryApiError) {
      return errorResponse({
        statusCode: error.statusCode,
        responseType: error.responseType,
        errorCode: error.errorCode,
        message: error.message,
        details: error.details,
        traceId,
      });
    }

    console.error('[mini_program_cloud_api][ERROR] Unhandled request failure.', {
      traceId,
      method,
      path,
      error: `${error}`,
      stack: error?.stack,
    });
    return errorResponse({
      statusCode: 500,
      responseType: 'backend_route_error',
      errorCode: 'internal_error',
      message: 'The cloud mini-program backend failed unexpectedly.',
      details: { reason: `${error}` },
      traceId,
    });
  }
};

async function handleDiscovery({ traceId, query }) {
  validateDeliveryContext(query, traceId);
  const catalogKeys = await listCatalogKeys();
  const entries = [];

  for (const catalogKey of catalogKeys) {
    const miniProgramId = catalogKeyToMiniProgramId(catalogKey);
    if (!miniProgramId) {
      continue;
    }
    try {
      const decision = await resolveManifestDecision({ miniProgramId, query });
      const manifest = await readJsonObject(decision.manifestKey);
      entries.push(buildCatalogEntry({ manifest, decision }));
    } catch (error) {
      if (shouldSkipCatalogEntry(error)) {
        console.warn('[mini_program_cloud_api][WARN] Skipped catalog entry.', {
          traceId,
          catalogKey,
          miniProgramId,
          error: `${error}`,
        });
        continue;
      }
      console.warn('[mini_program_cloud_api][WARN] Skipped catalog entry.', {
        traceId,
        catalogKey,
        miniProgramId,
        error: `${error}`,
      });
      throw error;
    }
  }

  entries.sort((left, right) => left.title.localeCompare(right.title));

  return jsonResponse({
    statusCode: 200,
    bodyObject: withTraceId({
      responseType: 'mini_program_catalog',
      statusCode: 200,
      entryCount: entries.length,
      entries,
    }, traceId),
    traceId,
    extraHeaders: {
      'x-mini-program-catalog-count': String(entries.length),
    },
  });
}

async function handleLatestManifest({ traceId, miniProgramId, query }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateDeliveryContext(query, traceId);

  const decision = await resolveManifestDecision({ miniProgramId, query });
  const manifest = await readJsonObject(decision.manifestKey);
  const responseBody = {
    ...manifest,
    deliveryMetadata: {
      responseType: 'manifest_delivery_metadata',
      statusCode: 200,
      selectionMode: decision.selectionMode,
      decisionReason: decision.decisionReason,
      resolvedVersion: decision.version,
      ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
      traceId,
    },
  };

  const extraHeaders = {
    'x-mini-program-id': miniProgramId,
    'x-mini-program-version': decision.version,
    'x-mini-program-selection-mode': decision.selectionMode,
    'x-mini-program-decision-reason': decision.decisionReason,
    ...(decision.matchedRuleId ? { 'x-mini-program-matched-rule-id': decision.matchedRuleId } : {}),
  };

  return jsonResponse({
    statusCode: 200,
    bodyObject: responseBody,
    traceId,
    extraHeaders,
  });
}

async function handleDebugDecision({ traceId, miniProgramId, query }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateDeliveryContext(query, traceId);

  const decision = await resolveManifestDecision({ miniProgramId, query });
  const body = withTraceId({
    responseType: 'manifest_decision_inspection',
    statusCode: 200,
    miniProgramId,
    outcome: 'resolved',
    simulatedStatusCode: 200,
    deliveryContext: sanitizeDeliveryContext(query),
    rollout: {
      type: 'catalog_metadata',
      latestVersion: decision.version,
    },
    decision: {
      selectionMode: decision.selectionMode,
      decisionReason: decision.decisionReason,
      resolvedVersion: decision.version,
      ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
    },
    manifestSummary: {
      manifestKey: decision.manifestKey,
      releaseKey: decision.releaseKey,
    },
  }, traceId);

  return jsonResponse({
    statusCode: 200,
    bodyObject: body,
    traceId,
    extraHeaders: {
      'x-debug-route': 'manifest_decision_inspect',
      'x-debug-outcome': 'resolved',
    },
  });
}

async function handleVersionedManifest({ traceId, miniProgramId, version }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateSafeSegment(version, 'version', traceId);
  const key = objectJoin(artifactsPrefix, miniProgramId, version, 'manifest.json');
  return jsonFromS3Object({
    traceId,
    key,
    notFoundMessage: `Manifest version "${version}" for mini-program "${miniProgramId}" was not found.`,
    extraHeaders: { 'x-mini-program-id': miniProgramId },
  });
}

async function handleScreen({ traceId, miniProgramId, version, screenId }) {
  validateSafeSegment(miniProgramId, 'miniProgramId', traceId);
  validateSafeSegment(version, 'version', traceId);
  validateSafeSegment(screenId, 'screenId', traceId);
  const key = objectJoin(artifactsPrefix, miniProgramId, version, 'screens', `${screenId}.json`);
  return jsonFromS3Object({
    traceId,
    key,
    notFoundMessage: `Screen "${screenId}" for mini-program "${miniProgramId}" version "${version}" was not found.`,
    extraHeaders: { 'x-mini-program-id': miniProgramId },
  });
}

async function jsonFromS3Object({ traceId, key, notFoundMessage, extraHeaders = {} }) {
  let rawJson;
  try {
    rawJson = await readRawJsonObject(key);
  } catch (error) {
    if (error instanceof DeliveryApiError && error.errorCode === 'artifact_not_found') {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage,
      });
    }
    throw error;
  }

  return jsonResponse({
    statusCode: 200,
    bodyObject: parseJsonValue(rawJson, key),
    traceId,
    extraHeaders,
  });
}

async function listCatalogKeys() {
  const keys = [];
  let continuationToken;
  do {
    const response = await s3.send(new ListObjectsV2Command({
      Bucket: artifactBucketName,
      Prefix: objectJoin(metadataPrefix, 'catalog') + '/',
      ContinuationToken: continuationToken,
    }));

    for (const object of response.Contents ?? []) {
      const key = object.Key;
      if (!key || !key.endsWith('.json')) {
        continue;
      }
      keys.push(key);
    }
    continuationToken = response.IsTruncated ? response.NextContinuationToken : undefined;
  } while (continuationToken);

  keys.sort();
  return keys;
}

async function resolveReleaseMetadataFromCatalog(catalog) {
  const releaseKey = normalizeKey(catalog.releaseKey);
  if (!releaseKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Catalog metadata is missing releaseKey.',
    });
  }
  const release = await readJsonObject(releaseKey);
  if (!release?.artifacts?.manifestKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Release metadata is missing artifacts.manifestKey.',
    });
  }
  return release;
}

async function resolveManifestDecision({ miniProgramId, query }) {
  const pinnedVersion = nullIfBlank(query.pinnedVersion);
  if (pinnedVersion) {
    validateSafeSegment(pinnedVersion, 'pinnedVersion');
    const manifestKey = objectJoin(artifactsPrefix, miniProgramId, pinnedVersion, 'manifest.json');
    await assertObjectExists(manifestKey, `Pinned version "${pinnedVersion}" for mini-program "${miniProgramId}" was not found.`);
    return {
      selectionMode: 'pinned_version',
      decisionReason: 'requested_pinned_version',
      version: pinnedVersion,
      releaseKey: objectJoin(metadataPrefix, 'releases', miniProgramId, `${pinnedVersion}.json`),
      manifestKey,
      matchedRuleId: null,
    };
  }

  const catalogKey = objectJoin(metadataPrefix, 'catalog', `${miniProgramId}.json`);
  const catalog = await readJsonObject(catalogKey, {
    notFoundMessage: `Catalog metadata for mini-program "${miniProgramId}" was not found.`,
  });
  const release = await resolveReleaseMetadataFromCatalog(catalog);
  const manifestKey = normalizeKey(release?.artifacts?.manifestKey);
  if (!manifestKey) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Release metadata is missing artifacts.manifestKey.',
    });
  }
  const resolvedVersion = nullIfBlank(catalog.latestVersion) || nullIfBlank(release.version);
  if (!resolvedVersion) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Catalog or release metadata is missing a usable version.',
      details: {
        catalogKey,
        releaseKey: String(catalog.releaseKey),
      },
    });
  }

  return {
    selectionMode: 'catalog_latest',
    decisionReason: 'catalog_metadata_latest',
    version: resolvedVersion,
    releaseKey: String(catalog.releaseKey),
    manifestKey,
    matchedRuleId: null,
  };
}

function buildCatalogEntry({ manifest, decision }) {
  const miniProgramId = String(manifest.id || '');
  const requiredCapabilities = Array.isArray(manifest.requiredCapabilities)
    ? manifest.requiredCapabilities.map((value) => String(value))
    : [];
  const title = humanizeMiniProgramId(miniProgramId);

  return {
    id: miniProgramId,
    title,
    description: `${title} is a backend-discovered portable mini-program delivered through the shared SDK.`,
    entry: String(manifest.entry || ''),
    resolvedVersion: decision.version,
    requiredCapabilities,
    selectionMode: decision.selectionMode,
    decisionReason: decision.decisionReason,
    ...(decision.matchedRuleId ? { matchedRuleId: decision.matchedRuleId } : {}),
  };
}

async function readJsonObject(key, { notFoundMessage } = {}) {
  const rawJson = await readRawJsonObject(key, { notFoundMessage });
  try {
    const decoded = JSON.parse(rawJson);
    if (decoded == null || typeof decoded !== 'object' || Array.isArray(decoded)) {
      throw new Error('JSON object required.');
    }
    return decoded;
  } catch (error) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Stored backend JSON is malformed.',
      details: { key, reason: `${error}` },
    });
  }
}

async function readRawJsonObject(key, { notFoundMessage } = {}) {
  try {
    const response = await s3.send(new GetObjectCommand({
      Bucket: artifactBucketName,
      Key: key,
    }));
    return await streamToString(response.Body);
  } catch (error) {
    if (isMissingObjectError(error)) {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage || `Artifact "${key}" was not found.`,
      });
    }
    throw error;
  }
}

async function assertObjectExists(key, notFoundMessage) {
  try {
    await s3.send(new HeadObjectCommand({
      Bucket: artifactBucketName,
      Key: key,
    }));
  } catch (error) {
    if (isMissingObjectError(error)) {
      throw new DeliveryApiError({
        statusCode: 404,
        responseType: 'artifact_error',
        errorCode: 'artifact_not_found',
        message: notFoundMessage,
      });
    }
    throw error;
  }
}

function resolveMethod(event) {
  return String(event?.requestContext?.http?.method || event?.httpMethod || 'GET').toUpperCase();
}

function resolvePath(event) {
  const rawPath = String(event?.rawPath || event?.requestContext?.http?.path || event?.path || '/');
  const stage = nullIfBlank(event?.requestContext?.stage);
  if (stage && stage !== '$default' && rawPath.startsWith(`/${stage}/`)) {
    return rawPath.slice(stage.length + 1);
  }
  return rawPath;
}

function splitPath(path) {
  return path.split('/').map((segment) => segment.trim()).filter((segment) => segment.length > 0).map((segment) => decodeURIComponent(segment));
}

function matches(actual, expected) {
  if (actual.length !== expected.length) {
    return false;
  }
  return actual.every((value, index) => value === expected[index]);
}

function isLatestSegment(value) {
  return value === 'latest' || value === 'latest.json';
}

function isCatalogSegment(value) {
  return value === 'mini-programs' || value === 'mini-programs.json';
}

function isDecisionSegment(value) {
  return value === 'decision' || value === 'decision.json';
}

function stripJsonSuffix(value) {
  const normalized = value.trim();
  if (!normalized) {
    return null;
  }
  if (!normalized.endsWith('.json')) {
    return normalized;
  }
  const stripped = normalized.slice(0, -5);
  return stripped || null;
}

function validateSafeSegment(value, label = 'segment', traceId) {
  if (!/^[A-Za-z0-9._-]+$/.test(value || '') || value === '.' || value === '..') {
    throw new DeliveryApiError({
      statusCode: 400,
      responseType: 'request_error',
      errorCode: 'invalid_request',
      message: `Path segment "${label}" is invalid.`,
      details: traceId ? { traceId } : undefined,
    });
  }
}

function resolveTraceId(event) {
  const requestedTraceId = nullIfBlank(event?.headers?.['x-request-id'] || event?.headers?.['X-Request-Id']);
  if (requestedTraceId && /^[A-Za-z0-9._-]{1,80}$/.test(requestedTraceId)) {
    return requestedTraceId;
  }
  return `aws_lb_${Date.now().toString(16)}`;
}

function withTraceId(body, traceId) {
  const responseBody = { ...body, traceId };
  const details = responseBody.details;
  if (details && typeof details === 'object' && !Array.isArray(details)) {
    responseBody.details = { ...details, traceId };
  }
  return responseBody;
}

function jsonResponse({ statusCode, bodyObject, body, traceId, extraHeaders = {} }) {
  const headers = {
    'content-type': backendJsonContentType,
    'x-backend-trace-id': traceId,
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'Content-Type, Authorization, X-Host-App, X-Host-Version, X-Host-User-Id, X-Host-Tenant-Id, X-Request-Id',
    'access-control-expose-headers': 'x-backend-trace-id, x-mini-program-id, x-mini-program-version, x-mini-program-selection-mode, x-mini-program-decision-reason, x-mini-program-matched-rule-id, x-mini-program-catalog-count, x-debug-route, x-debug-outcome',
    'access-control-max-age': '600',
    ...extraHeaders,
  };
  return {
    statusCode,
    headers,
    body: body ?? JSON.stringify(bodyObject),
  };
}

function errorResponse({ statusCode, responseType, errorCode, message, details, traceId }) {
  return jsonResponse({
    statusCode,
    traceId,
    bodyObject: withTraceId({
      responseType,
      statusCode,
      errorCode,
      message,
      ...(details ? { details } : {}),
      error: {
        code: errorCode,
        message,
        ...(details ? { details } : {}),
      },
    }, traceId),
  });
}

function badRequest(message, traceId) {
  return errorResponse({
    statusCode: 400,
    responseType: 'request_error',
    errorCode: 'invalid_request',
    message,
    traceId,
  });
}

function notImplemented(message, traceId) {
  return errorResponse({
    statusCode: 501,
    responseType: 'backend_route_error',
    errorCode: 'not_implemented',
    message,
    traceId,
  });
}

function objectJoin(...parts) {
  return parts.filter((value) => value != null && String(value).trim().length > 0).map((value) => String(value).replaceAll('\\', '/').replace(/^\/+|\/+$/g, '')).filter((value) => value.length > 0).join('/');
}

function catalogKeyToMiniProgramId(catalogKey) {
  const expectedPrefix = `${objectJoin(metadataPrefix, 'catalog')}/`;
  if (!catalogKey.startsWith(expectedPrefix) || !catalogKey.endsWith('.json')) {
    return null;
  }
  const relativePath = catalogKey.slice(expectedPrefix.length, -5);
  return relativePath && !relativePath.includes('/') ? relativePath : null;
}

function normalizePrefix(value) {
  const trimmed = String(value || '').trim().replaceAll('\\', '/').replace(/^\/+|\/+$/g, '');
  if (!trimmed) {
    throw new Error('S3 prefixes must not be blank.');
  }
  return trimmed;
}

function normalizeKey(value) {
  const trimmed = nullIfBlank(value);
  return trimmed ? objectJoin(trimmed) : null;
}

function nullIfBlank(value) {
  if (value == null) {
    return null;
  }
  const trimmed = String(value).trim();
  return trimmed.length === 0 ? null : trimmed;
}

function requiredEnv(name) {
  const value = nullIfBlank(process.env[name]);
  if (!value) {
    throw new Error(`Missing required environment variable ${name}.`);
  }
  return value;
}

function humanizeMiniProgramId(miniProgramId) {
  return miniProgramId.split(/[_-]+/).filter((segment) => segment.length > 0).map((segment) => segment[0].toUpperCase() + segment.slice(1).toLowerCase()).join(' ');
}

function sanitizeDeliveryContext(query) {
  const rawCapabilities = nullIfBlank(query.capabilities);
  return {
    hostApp: nullIfBlank(query.hostApp),
    sdkVersion: nullIfBlank(query.sdkVersion),
    hostVersion: nullIfBlank(query.hostVersion),
    platform: nullIfBlank(query.platform),
    locale: nullIfBlank(query.locale),
    tenantId: nullIfBlank(query.tenantId),
    pinnedVersion: nullIfBlank(query.pinnedVersion),
    capabilities: rawCapabilities ? rawCapabilities.split(',').map((value) => value.trim()).filter((value) => value.length > 0).sort() : [],
  };
}

function validateDeliveryContext(query, traceId) {
  const context = sanitizeDeliveryContext(query);
  const scalarSegments = [
    ['hostApp', context.hostApp],
    ['sdkVersion', context.sdkVersion],
    ['hostVersion', context.hostVersion],
    ['platform', context.platform],
    ['locale', context.locale],
    ['tenantId', context.tenantId],
    ['pinnedVersion', context.pinnedVersion],
  ];

  for (const [label, value] of scalarSegments) {
    if (value) {
      validateSafeSegment(value, label, traceId);
    }
  }
  for (const capability of context.capabilities) {
    validateSafeSegment(capability, 'capabilities', traceId);
  }
}

function shouldSkipCatalogEntry(error) {
  return error instanceof DeliveryApiError && error.statusCode === 404;
}

function isMissingObjectError(error) {
  return error?.name === 'NoSuchKey' || error?.name === 'NotFound' || error?.$metadata?.httpStatusCode === 404;
}

function parseJsonValue(rawJson, key) {
  try {
    return JSON.parse(rawJson);
  } catch (error) {
    throw new DeliveryApiError({
      statusCode: 500,
      responseType: 'artifact_error',
      errorCode: 'invalid_backend_json',
      message: 'Stored backend JSON is malformed.',
      details: { key, reason: `${error}` },
    });
  }
}

async function streamToString(stream) {
  if (stream == null) {
    return '';
  }
  if (typeof stream.transformToString === 'function') {
    return stream.transformToString();
  }
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

function logInfo(message, context) {
  const levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
  if (levels.indexOf(logLevel) <= levels.indexOf('INFO')) {
    console.log('[mini_program_cloud_api][INFO]', message, context);
  }
}

class DeliveryApiError extends Error {
  constructor({ statusCode, responseType, errorCode, message, details }) {
    super(message);
    this.statusCode = statusCode;
    this.responseType = responseType;
    this.errorCode = errorCode;
    this.details = details;
  }
}
''';
