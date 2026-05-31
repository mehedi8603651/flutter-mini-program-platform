part of '../miniprogram_cli.dart';

extension _MiniprogramCliEnvCommands on MiniprogramCli {
  Future<int> _runEnv(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_envUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_envUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEnvInit(arguments.sublist(1));
      case 'configure':
        return _runEnvConfigure(arguments.sublist(1));
      case 'list':
        return _runEnvList(arguments.sublist(1));
      case 'use':
        return _runEnvUse(arguments.sublist(1));
      case 'status':
        return _runEnvStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown env command: ${arguments.first}');
        _stderr.writeln(_envUsage());
        return 64;
    }
  }

  Future<int> _runEnvInit(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Platform repo root to remember in env.json.',
      )
      ..addOption(
        'root',
        help: 'Directory that should own .mini_program/env.json.',
      )
      ..addOption(
        'use',
        help: 'Active environment to save. Defaults to local.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram env init [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final cwd = _currentWorkingDirectory();
    final inferredRootFromCwd = await _pathResolver.resolveRepoRoot(
      currentWorkingDirectory: cwd,
    );
    final configRootPath = p.normalize(
      p.absolute(results.option('root') ?? inferredRootFromCwd ?? cwd),
    );
    final existingState = await _stateStore.readEnvironmentState(
      configRootPath,
    );
    final repoRootPath = await _pathResolver.resolveRepoRoot(
      explicitRepoRootPath:
          results.option('repo-root') ?? existingState?.repoRootPath,
      currentWorkingDirectory: configRootPath,
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final configuredCloudEnvironments =
        existingState?.cloudEnvironments ??
        const <CloudEnvironmentConfiguration>[];
    final requestedActiveEnvironment =
        results.option('use')?.trim() ??
        existingState?.activeEnvironment ??
        'local';
    final activeEnvironment = _validateSelectedEnvironmentName(
      requestedActiveEnvironment,
      configuredCloudEnvironments,
      allowLegacyCloudAlias: true,
    );
    final state = LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: repoRootPath,
      activeEnvironment: activeEnvironment,
      cloudEnvironments: configuredCloudEnvironments,
      initializedAtUtc: existingState?.initializedAtUtc ?? now,
      updatedAtUtc: now,
    );
    await _stateStore.writeEnvironmentState(configRootPath, state);
    await _stateStore.writeGlobalEnvironmentState(state);
    _stdout.writeln(
      _formatEnvStatusResult(
        ResolvedLocalCliEnvironmentState(
          rootPath: configRootPath,
          filePath: _stateStore.environmentStatePath(configRootPath),
          state: state,
          scope: 'local',
        ),
        initialized: true,
      ),
    );
    return 0;
  }

  Future<int> _runEnvConfigure(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      )
      ..addOption(
        'provider',
        allowed: CloudEnvironmentConfiguration.supportedProviders,
        help: 'Cloud provider for this named environment.',
      )
      ..addOption('bucket', help: 'AWS S3 bucket name for cloud artifacts.')
      ..addOption(
        'region',
        help:
            'AWS region for S3/SAM or Firebase Functions region. Firebase defaults to us-central1.',
      )
      ..addOption(
        'project-id',
        help: 'Firebase project id for Firebase publisher backend commands.',
      )
      ..addOption(
        'function-name',
        help:
            'Firebase HTTPS function export name. Defaults to publisherBackend.',
      )
      ..addOption(
        'function-url',
        help:
            'Optional Firebase HTTPS function URL override for status/outputs/smoke.',
      )
      ..addOption(
        'auth-web-api-key',
        help:
            'Optional Firebase Web API key used by publisher-owned email auth routes.',
      )
      ..addOption(
        'artifacts-prefix',
        defaultsTo: 'artifacts',
        help: 'Object prefix for immutable release artifacts.',
      )
      ..addOption(
        'metadata-prefix',
        defaultsTo: 'metadata',
        help: 'Object prefix for mutable and release metadata records.',
      )
      ..addOption(
        'cloudfront-base-url',
        help:
            'Optional CloudFront base URL used to derive public artifact URLs.',
      )
      ..addOption(
        'api-base-url',
        help: 'Optional API Gateway base URL for discovery and secure routes.',
      )
      ..addOption(
        'aws-profile',
        help: 'Optional AWS CLI profile used for cloud publish commands.',
      )
      ..addOption(
        'stack-name',
        help: 'Optional CloudFormation stack name for AWS cloud deploy.',
      )
      ..addOption(
        'stage-name',
        help: 'Optional API Gateway stage name. Defaults to prod.',
      )
      ..addOption(
        'sam-s3-bucket',
        help:
            'Optional S3 bucket used by sam deploy for packaging. Defaults to the artifact bucket.',
      )
      ..addOption(
        'function-timeout-seconds',
        help: 'Optional Lambda timeout in seconds. Defaults to 15.',
      )
      ..addOption(
        'function-memory-size',
        help: 'Optional Lambda memory size in MB. Defaults to 256.',
      )
      ..addOption(
        'log-level',
        help: 'Optional Lambda log level. Defaults to INFO.',
      )
      ..addFlag(
        'require-access-keys',
        negatable: true,
        defaultsTo: false,
        help:
            'Require AWS delivery routes to validate MiniProgram access keys.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram env configure <env-name> --provider <provider> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'env configure expects exactly one <env-name> positional argument.',
      );
    }

    final environmentName = _validateEnvironmentName(results.rest.single);
    final provider = results.option('provider')?.trim() ?? '';
    if (provider.isEmpty) {
      throw const FormatException(
        'env configure requires --provider <provider>.',
      );
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (environmentName == 'local') {
      throw const FormatException('The environment name "local" is reserved.');
    }

    final values = switch (provider) {
      'aws' => _buildAwsEnvironmentValues(results),
      'firebase' => _buildFirebaseEnvironmentValues(results),
      _ => throw MiniProgramPublishException(
        'Provider "$provider" is not implemented yet. This phase currently '
        'supports aws and firebase.',
      ),
    };
    final now = DateTime.now().toUtc().toIso8601String();
    final existingEnvironment = resolved.state.cloudEnvironmentNamed(
      environmentName,
    );
    final updatedEnvironment = CloudEnvironmentConfiguration(
      name: environmentName,
      provider: provider,
      values: values,
      configuredAtUtc: existingEnvironment?.configuredAtUtc ?? now,
      updatedAtUtc: now,
    );
    final updatedCloudEnvironments =
        resolved.state.cloudEnvironments
            .where((environment) => environment.name != environmentName)
            .toList()
          ..add(updatedEnvironment);
    updatedCloudEnvironments.sort((a, b) => a.name.compareTo(b.name));

    final updatedState = resolved.state.copyWith(
      schemaVersion: 2,
      cloudEnvironments: updatedCloudEnvironments,
      updatedAtUtc: now,
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }

    _stdout.writeln(
      _formatEnvConfigureResult(
        updatedEnvironment,
        resolved.copyWithState(updatedState),
      ),
    );
    return 0;
  }

  Future<int> _runEnvList(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram env list [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (resolved == null) {
      _stdout.writeln(
        'No miniprogram env configuration was found. Run '
        '"miniprogram env init" first.',
      );
      return 1;
    }

    _stdout.writeln(_formatEnvListResult(resolved));
    return 0;
  }

  Future<int> _runEnvUse(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram env use <local|env-name> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'env use expects exactly one environment: local or a configured env name.',
      );
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final selectedEnvironment = _validateSelectedEnvironmentName(
      results.rest.single,
      resolved.state.cloudEnvironments,
    );
    final updatedState = resolved.state.copyWith(
      schemaVersion: 2,
      activeEnvironment: selectedEnvironment,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }
    _stdout.writeln(
      _formatEnvStatusResult(
        resolved.copyWithState(updatedState),
        switched: true,
      ),
    );
    return 0;
  }

  Future<int> _runEnvStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram env status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_envStatusJson(resolved)));
    } else {
      _stdout.writeln(_formatEnvStatusResult(resolved));
    }
    return resolved == null ? 1 : 0;
  }

  Map<String, dynamic> _buildAwsEnvironmentValues(ArgResults results) {
    String requiredOption(String name) {
      final value = results.option(name)?.trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('env configure --provider aws requires --$name.');
      }
      return value;
    }

    final values = <String, dynamic>{
      'bucket': requiredOption('bucket'),
      'region': requiredOption('region'),
      'artifactsPrefix': _normalizeEnvironmentPathPrefix(
        results.option('artifacts-prefix') ?? 'artifacts',
      ),
      'metadataPrefix': _normalizeEnvironmentPathPrefix(
        results.option('metadata-prefix') ?? 'metadata',
      ),
    };

    if (results.option('cloudfront-base-url') case final value?
        when value.trim().isNotEmpty) {
      values['cloudFrontBaseUrl'] = _normalizeAbsoluteUrl(value);
    }
    if (results.option('api-base-url') case final value?
        when value.trim().isNotEmpty) {
      values['apiBaseUrl'] = _normalizeAbsoluteUrl(value);
    }
    if (results.option('aws-profile') case final value?
        when value.trim().isNotEmpty) {
      values['awsProfile'] = value.trim();
    }
    if (results.option('stack-name') case final value?
        when value.trim().isNotEmpty) {
      values['stackName'] = _validateEnvironmentName(value);
    }
    if (results.option('stage-name') case final value?
        when value.trim().isNotEmpty) {
      values['stageName'] = _validateEnvironmentName(value);
    }
    if (results.option('sam-s3-bucket') case final value?
        when value.trim().isNotEmpty) {
      values['samS3Bucket'] = value.trim();
    }
    if (results.option('function-timeout-seconds') case final value?
        when value.trim().isNotEmpty) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 3 || parsed > 30) {
        throw const FormatException(
          '--function-timeout-seconds must be an integer from 3 to 30.',
        );
      }
      values['functionTimeoutSeconds'] = parsed;
    }
    if (results.option('function-memory-size') case final value?
        when value.trim().isNotEmpty) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null ||
          !const <int>[128, 256, 512, 1024].contains(parsed)) {
        throw const FormatException(
          '--function-memory-size must be one of 128, 256, 512, or 1024.',
        );
      }
      values['functionMemorySize'] = parsed;
    }
    if (results.option('log-level') case final value?
        when value.trim().isNotEmpty) {
      final normalized = value.trim().toUpperCase();
      if (!const <String>[
        'DEBUG',
        'INFO',
        'WARN',
        'ERROR',
      ].contains(normalized)) {
        throw const FormatException(
          '--log-level must be one of DEBUG, INFO, WARN, or ERROR.',
        );
      }
      values['logLevel'] = normalized;
    }
    if (results.flag('require-access-keys')) {
      values['requireAccessKeys'] = true;
    }
    return values;
  }

  Map<String, dynamic> _buildFirebaseEnvironmentValues(ArgResults results) {
    final projectId = results.option('project-id')?.trim() ?? '';
    if (projectId.isEmpty) {
      throw const FormatException(
        'env configure --provider firebase requires --project-id.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{2,62}$').hasMatch(projectId)) {
      throw FormatException(
        '--project-id must look like a Firebase project id: $projectId',
      );
    }

    final region = results.option('region')?.trim().isNotEmpty == true
        ? results.option('region')!.trim()
        : 'us-central1';
    if (!RegExp(r'^[a-z]+-[a-z0-9-]+[0-9]$').hasMatch(region)) {
      throw FormatException(
        '--region must look like a Firebase Functions region: $region',
      );
    }

    final functionName =
        results.option('function-name')?.trim().isNotEmpty == true
        ? results.option('function-name')!.trim()
        : 'publisherBackend';
    if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(functionName)) {
      throw FormatException(
        '--function-name must be a valid JavaScript export name: $functionName',
      );
    }

    final values = <String, dynamic>{
      'projectId': projectId,
      'region': region,
      'functionName': functionName,
    };
    if (results.option('function-url') case final value?
        when value.trim().isNotEmpty) {
      final normalized = _normalizeAbsoluteUrl(value);
      final uri = Uri.parse(normalized);
      if (uri.scheme != 'https') {
        throw const FormatException('--function-url must use https.');
      }
      values['functionUrl'] = normalized;
    }
    if (results.option('auth-web-api-key') case final value?
        when value.trim().isNotEmpty) {
      final normalized = value.trim();
      if (!RegExp(r'^[A-Za-z0-9_-]{8,}$').hasMatch(normalized)) {
        throw const FormatException(
          '--auth-web-api-key must be a non-empty Firebase Web API key.',
        );
      }
      values['authWebApiKey'] = normalized;
    }
    return values;
  }

  String _validateEnvironmentName(String rawName) {
    final trimmedName = rawName.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Environment names must not be blank.');
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmedName)) {
      throw FormatException(
        'Environment name "$trimmedName" contains unsupported characters.',
      );
    }
    return trimmedName;
  }

  String _validateSelectedEnvironmentName(
    String rawName,
    List<CloudEnvironmentConfiguration> configuredCloudEnvironments, {
    bool allowLegacyCloudAlias = false,
  }) {
    final trimmedName = rawName.trim();
    if (trimmedName == 'local') {
      return 'local';
    }
    if (trimmedName == 'cloud' && allowLegacyCloudAlias) {
      return 'cloud';
    }
    if (trimmedName == 'cloud') {
      throw const FormatException(
        'env use cloud is no longer the primary workflow. Use a configured '
        'environment name such as my-aws-prod instead.',
      );
    }
    final normalizedName = _validateEnvironmentName(trimmedName);
    if (!configuredCloudEnvironments.any(
      (environment) => environment.name == normalizedName,
    )) {
      throw FormatException(
        'No configured cloud environment named "$normalizedName" was found. '
        'Run `miniprogram env configure $normalizedName --provider aws|firebase ...` first.',
      );
    }
    return normalizedName;
  }

  List<String> _formatCloudEnvironmentValues(
    CloudEnvironmentConfiguration environment,
  ) {
    final lines = <String>[];
    final sortedKeys = environment.values.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = key == 'authWebApiKey'
          ? '<configured>'
          : environment.values[key];
      lines.add('$key: $value');
    }
    return lines;
  }

  Future<void> _persistCloudEnvironmentValueUpdates({
    required ResolvedLocalCliEnvironmentState resolved,
    required String environmentName,
    required Map<String, dynamic> updatedValues,
  }) async {
    if (updatedValues.isEmpty) {
      return;
    }

    final existingEnvironment = resolved.state.cloudEnvironmentNamed(
      environmentName,
    );
    if (existingEnvironment == null) {
      return;
    }

    final mergedValues = Map<String, dynamic>.from(existingEnvironment.values);
    for (final entry in updatedValues.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      mergedValues[entry.key] = value;
    }

    final updatedCloudEnvironments =
        resolved.state.cloudEnvironments
            .where((environment) => environment.name != environmentName)
            .toList()
          ..add(
            existingEnvironment.copyWith(
              values: mergedValues,
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    updatedCloudEnvironments.sort((a, b) => a.name.compareTo(b.name));

    final updatedState = resolved.state.copyWith(
      cloudEnvironments: updatedCloudEnvironments,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }
  }

  Future<String> _resolvePartnerPackageApiBaseUrl({
    required String? explicitApiBaseUrl,
    required String? explicitEnvironmentName,
    required String? explicitRootPath,
    required String? explicitRepoRootPath,
  }) async {
    if (explicitApiBaseUrl case final rawValue?
        when rawValue.trim().isNotEmpty) {
      return _normalizeAbsoluteUrl(rawValue);
    }

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: explicitRootPath,
      explicitRepoRootPath: explicitRepoRootPath,
    );
    if (resolved == null) {
      throw const FormatException(
        'partner package requires --api-base-url <url> or a configured cloud '
        'environment. Run `miniprogram env init` and '
        '`miniprogram env configure ...` first.',
      );
    }
    final requestedEnvironmentName =
        explicitEnvironmentName?.trim().isNotEmpty == true
        ? explicitEnvironmentName!.trim()
        : resolved.state.activeEnvironment;
    if (requestedEnvironmentName.isEmpty ||
        requestedEnvironmentName == 'local' ||
        requestedEnvironmentName == 'cloud') {
      throw const FormatException(
        'partner package needs a named cloud environment when '
        '--api-base-url is omitted. Run `miniprogram env use <env-name>` or '
        'pass `--env <env-name>`.',
      );
    }
    final environment = resolved.state.cloudEnvironmentNamed(
      requestedEnvironmentName,
    );
    if (environment == null) {
      throw FormatException(
        'No configured cloud environment named "$requestedEnvironmentName" '
        'was found.',
      );
    }
    final savedApiBaseUrl = environment.values['apiBaseUrl']?.toString().trim();
    if (savedApiBaseUrl != null && savedApiBaseUrl.isNotEmpty) {
      return _normalizeAbsoluteUrl(savedApiBaseUrl);
    }

    final outputs = await _cloudController.outputs(
      MiniProgramCloudOutputsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    final backendApiBaseUrl = _requireBackendApiBaseUrlFromOutputs(outputs);
    await _persistCloudEnvironmentValueUpdates(
      resolved: resolved,
      environmentName: environment.name,
      updatedValues: <String, dynamic>{'apiBaseUrl': backendApiBaseUrl},
    );
    return backendApiBaseUrl;
  }
}
