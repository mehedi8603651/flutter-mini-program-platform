part of '../miniprogram_cli.dart';

extension _MiniprogramCliCloudAccessCommands on MiniprogramCli {
  Future<int> _runAccessKey(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_accessKeyUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_accessKeyUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'create':
        return _runAccessKeyCreate(arguments.sublist(1));
      case 'list':
        return _runAccessKeyList(arguments.sublist(1));
      case 'revoke':
        return _runAccessKeyRevoke(arguments.sublist(1));
      case 'rotate':
        return _runAccessKeyRotate(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown access-key command: ${arguments.first}');
        _stderr.writeln(_accessKeyUsage());
        return 64;
    }
  }

  Future<int> _runCloud(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_cloudUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_cloudUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'deploy':
        return _runCloudDeploy(arguments.sublist(1));
      case 'status':
        return _runCloudStatus(arguments.sublist(1));
      case 'outputs':
        return _runCloudOutputs(arguments.sublist(1));
      case 'logs':
        return _runCloudLogs(arguments.sublist(1));
      case 'destroy':
        return _runCloudDestroy(arguments.sublist(1));
      case 'doctor':
        return _runCloudDoctor(arguments.sublist(1));
      case 'rollback':
        return _runCloudRollback(arguments.sublist(1));
      case 'app':
        return _runCloudApp(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown cloud command: ${arguments.first}');
        _stderr.writeln(_cloudUsage());
        return 64;
    }
  }

  Future<int> _runCloudApp(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_cloudAppUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_cloudAppUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'list':
        return _runCloudAppList(arguments.sublist(1));
      case 'info':
        return _runCloudAppInfo(arguments.sublist(1));
      case 'disable':
        return _runCloudAppDisable(arguments.sublist(1));
      case 'delete':
        return _runCloudAppDelete(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown cloud app command: ${arguments.first}');
        _stderr.writeln(_cloudAppUsage());
        return 64;
    }
  }

  Future<int> _runCloudDeploy(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud deploy [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.deploy(
      MiniProgramCloudDeployRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    await _persistCloudEnvironmentValueUpdates(
      resolved: resolved,
      environmentName: environment.name,
      updatedValues: <String, dynamic>{
        'stackName': result.stackName,
        'stageName': result.stageName,
        if (result.apiBaseUrl != null) 'apiBaseUrl': result.apiBaseUrl,
      },
    );
    _stdout.writeln(_formatCloudDeployResult(result));
    return result.healthy == false ? 1 : 0;
  }

  Future<int> _runCloudStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.status(
      MiniProgramCloudStatusRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(miniProgramWorkflowStatusCloudJson(result)));
    } else {
      _stdout.writeln(_formatCloudStatusResult(result));
    }
    return !result.stackExists || result.healthy == false ? 1 : 0;
  }

  Future<int> _runCloudOutputs(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption(
        'format',
        allowed: const <String>['text', 'dart-define'],
        defaultsTo: 'text',
        help:
            'Output format. Use dart-define for a direct flutter run snippet.',
      )
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud outputs [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.outputs(
      MiniProgramCloudOutputsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(
      _formatCloudOutputsResult(
        result,
        format: results.option('format') ?? 'text',
      ),
    );
    return 0;
  }

  Future<int> _runCloudLogs(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      )
      ..addOption(
        'since',
        defaultsTo: '1h',
        help: 'AWS logs tail window such as 10m, 1h, or 1d.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud logs [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.logs(
      MiniProgramCloudLogsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        since: results.option('since') ?? '1h',
      ),
    );
    _stdout.writeln(_formatCloudLogsResult(result));
    return 0;
  }

  Future<int> _runCloudDestroy(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud destroy [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.destroy(
      MiniProgramCloudDestroyRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudDestroyResult(result));
    return 0;
  }

  Future<int> _runCloudDoctor(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud doctor [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.doctor(
      MiniProgramCloudDoctorRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudDoctorResult(result));
    return result.hasErrors ? 1 : 0;
  }

  Future<int> _runCloudRollback(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud rollback <version> [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isEmpty || results.rest.length > 2) {
      throw const FormatException(
        'cloud rollback expects <version> and an optional [mini-program-id].',
      );
    }

    final version = results.rest.first;
    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'cloud rollback',
      positionalArguments: results.rest.length == 2
          ? <String>[results.rest[1]]
          : const <String>[],
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.rollback(
      MiniProgramCloudRollbackRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: miniProgramId,
        version: version,
      ),
    );
    _stdout.writeln(_formatCloudRollbackResult(result));
    return 0;
  }

  Future<int> _runAccessKeyCreate(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Stable label for this partner key.')
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key create <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key create expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key create requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.createAccessKey(
      MiniProgramAccessKeyCreateRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
        accessKey: results.option('key'),
      ),
    );
    _stdout.writeln(_formatAccessKeyCreateResult(result));
    return 0;
  }

  Future<int> _runAccessKeyList(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key list <mini-program-id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key list expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.listAccessKeys(
      MiniProgramAccessKeyListRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(miniProgramWorkflowStatusAccessKeyListJson(result)),
      );
    } else {
      _stdout.writeln(_formatAccessKeyListResult(result));
    }
    return 0;
  }

  Future<int> _runAccessKeyRevoke(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Access key id to revoke.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key revoke <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key revoke expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key revoke requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.revokeAccessKey(
      MiniProgramAccessKeyRevokeRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
      ),
    );
    _stdout.writeln(_formatAccessKeyRevokeResult(result));
    return 0;
  }

  Future<int> _runAccessKeyRotate(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Access key id to revoke.')
      ..addOption('new-key-id', help: 'Optional id for the new key.')
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key rotate <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key rotate expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key rotate requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.rotateAccessKey(
      MiniProgramAccessKeyRotateRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
        newKeyId: results.option('new-key-id'),
        accessKey: results.option('key'),
      ),
    );
    _stdout.writeln(_formatAccessKeyRotateResult(result));
    return 0;
  }

  Future<int> _runCloudAppList(List<String> arguments) async {
    final parser = _cloudAppParser();
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud app list [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException('cloud app list does not accept arguments.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.listApps(
      MiniProgramCloudAppListRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudAppListResult(result));
    return 0;
  }

  Future<int> _runCloudAppInfo(List<String> arguments) async {
    final parser = _cloudAppParser();
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app info <mini-program-id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app info expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.appInfo(
      MiniProgramCloudAppInfoRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
      ),
    );
    _stdout.writeln(_formatCloudAppInfoResult(result));
    return 0;
  }

  Future<int> _runCloudAppDisable(List<String> arguments) async {
    final parser = _cloudAppParser()
      ..addFlag(
        'yes',
        negatable: false,
        help:
            'Actually disable the app. Without this, the command is a dry run.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app disable <mini-program-id> [--yes] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app disable expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.disableApp(
      MiniProgramCloudAppDisableRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        confirmed: results.flag('yes'),
      ),
    );
    _stdout.writeln(_formatCloudAppDisableResult(result));
    return 0;
  }

  Future<int> _runCloudAppDelete(List<String> arguments) async {
    final parser = _cloudAppParser()
      ..addFlag(
        'yes',
        negatable: false,
        help:
            'Actually delete objects. Without this, the command is a dry run.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app delete <mini-program-id> [--yes] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app delete expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.deleteApp(
      MiniProgramCloudAppDeleteRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        confirmed: results.flag('yes'),
      ),
    );
    _stdout.writeln(_formatCloudAppDeleteResult(result));
    return 0;
  }

  ArgParser _accessKeyParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named cloud environment override.')
    ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
    ..addOption(
      'repo-root',
      help: 'Optional repo root used to locate an existing env.json.',
    );

  ArgParser _cloudAppParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named cloud environment override.')
    ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
    ..addOption(
      'repo-root',
      help: 'Optional repo root used to locate an existing env.json.',
    );
}
