part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendContractCommands on MiniprogramCli {
  Future<int> _runPublisherBackendContract(
    List<String> arguments, {
    String commandName = 'publisher-backend',
  }) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendContractUsage(commandName: commandName));
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendContractUsage(commandName: commandName));
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runPublisherBackendContractInit(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'validate':
        return _runPublisherBackendContractValidate(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'smoke':
        return _runPublisherBackendContractSmoke(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'handoff':
        return _runPublisherBackendContractHandoff(
          arguments.sublist(1),
          commandName: commandName,
        );
      default:
        _stderr.writeln(
          'Unknown $commandName contract command: ${arguments.first}',
        );
        _stderr.writeln(
          _publisherBackendContractUsage(commandName: commandName),
        );
        return 64;
    }
  }

  Future<int> _runPublisherBackendContractInit(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName contract init';
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      )
      ..addOption(
        'app-id',
        help: 'Mini-program app id. Defaults to manifest.json id.',
      )
      ..addOption(
        'backend-base-url',
        help: 'Publisher-owned backend API base URL. Use HTTPS for production.',
      )
      ..addOption(
        'health-endpoint',
        defaultsTo: MiniProgramPublisherBackendContract.defaultHealthEndpoint,
        help: 'Relative health endpoint.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output contract path. Defaults to <mini-program-root>/publisher_backend.json.',
      )
      ..addFlag(
        'allow-local-http',
        negatable: false,
        help:
            'Allow local LAN HTTP backend URLs for device testing. Loopback HTTP is always allowed.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram $qualifiedCommand --backend-base-url <url> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw FormatException(
        '$qualifiedCommand does not accept positional arguments.',
      );
    }
    final rawBackendBaseUrl = results.option('backend-base-url')?.trim() ?? '';
    if (rawBackendBaseUrl.isEmpty) {
      throw FormatException(
        '$qualifiedCommand requires --backend-base-url <url>.',
      );
    }
    final backendBaseUri = Uri.tryParse(rawBackendBaseUrl);
    if (backendBaseUri == null) {
      throw FormatException(
        '$qualifiedCommand expected a valid --backend-base-url, got: $rawBackendBaseUrl',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final manifestInfo = await _readMiniProgramManifestInfo(
      miniProgramRootPath,
    );
    final appId = results.option('app-id')?.trim().isNotEmpty == true
        ? results.option('app-id')!.trim()
        : manifestInfo.appId;
    final result = await _publisherBackendContractController.init(
      PublisherBackendContractInitRequest(
        miniProgramRootPath: miniProgramRootPath,
        appId: appId,
        backendBaseUri: backendBaseUri,
        healthEndpoint: results.option('health-endpoint')!,
        outputPath: results.option('output'),
        allowLocalHttp: results.flag('allow-local-http'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendContractInitJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendContractInitResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendContractValidate(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName contract validate';
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      )
      ..addOption(
        'contract',
        help:
            'Contract path. Defaults to <mini-program-root>/publisher_backend.json.',
      )
      ..addFlag(
        'allow-local-http',
        negatable: false,
        help:
            'Allow local LAN HTTP backend URLs for device testing. Loopback HTTP is always allowed.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw FormatException(
        '$qualifiedCommand does not accept positional arguments.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendContractController.validate(
      miniProgramRootPath: miniProgramRootPath,
      explicitContractPath: results.option('contract'),
      allowLocalHttp: results.flag('allow-local-http'),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendContractValidateJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendContractValidateResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendContractSmoke(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName contract smoke';
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      )
      ..addOption(
        'contract',
        help:
            'Contract path. Defaults to <mini-program-root>/publisher_backend.json.',
      )
      ..addOption(
        'auth-token',
        help:
            'Publisher auth token to send as Authorization: Bearer <token> during smoke checks.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '8',
        help: 'Per-route smoke timeout in seconds.',
      )
      ..addFlag(
        'allow-local-http',
        negatable: false,
        help:
            'Allow local LAN HTTP backend URLs for device testing. Loopback HTTP is always allowed.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw FormatException(
        '$qualifiedCommand does not accept positional arguments.',
      );
    }
    final timeoutSeconds = int.tryParse(results.option('timeout-seconds')!);
    if (timeoutSeconds == null || timeoutSeconds <= 0) {
      throw FormatException(
        '$qualifiedCommand --timeout-seconds must be positive.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final contractPath = _publisherBackendContractController
        .defaultContractPath(
          miniProgramRootPath,
          explicitPath: results.option('contract'),
        );
    final contract = await _publisherBackendContractController.readContract(
      contractPath: contractPath,
      allowLocalHttp: results.flag('allow-local-http'),
    );
    final result = await _publisherBackendContractController.smoke(
      PublisherBackendContractSmokeRequest(
        contractPath: contractPath,
        contract: contract,
        authToken: results.option('auth-token'),
        timeout: Duration(seconds: timeoutSeconds),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendContractSmokeJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendContractSmokeResult(result));
    }
    return result.passed ? 0 : 1;
  }

  Future<int> _runPublisherBackendContractHandoff(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName contract handoff';
    if (arguments.contains('--help') ||
        arguments.contains('-h') ||
        arguments.contains('help')) {
      _stdout.writeln(
        'Usage: miniprogram $qualifiedCommand\n\n'
        'Removed: Publisher API contract handoff packages are no longer part '
        'of the MVP flow. Create a static partner package with '
        '`miniprogram partner package <appId> --artifact-base-url <url>`.',
      );
      return 0;
    }
    throw FormatException(
      '$qualifiedCommand was removed. Host opening uses appId + '
      'artifactBaseUrl only. Use `miniprogram partner package <appId> '
      '--artifact-base-url <url>` for static artifact handoff.',
    );
  }

  Map<String, Object?> _publisherBackendContractInitJson(
    PublisherBackendContractInitResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-api contract init',
      'contractPath': result.contractPath,
      ..._publisherBackendContractJson(result.contract),
    };
  }

  Map<String, Object?> _publisherBackendContractValidateJson(
    PublisherBackendContractValidateResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-api contract validate',
      'contractPath': result.contractPath,
      'valid': true,
      ..._publisherBackendContractJson(result.contract),
    };
  }

  Map<String, Object?> _publisherBackendContractSmokeJson(
    PublisherBackendContractSmokeResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-api contract smoke',
      'contractPath': result.contractPath,
      ..._publisherBackendContractJson(result.contract),
      'authTokenProvided': result.authTokenProvided,
      'passed': result.passed,
      'routes': result.routes.map(_publisherBackendContractRouteJson).toList(),
    };
  }

  Map<String, Object?> _publisherBackendContractJson(
    MiniProgramPublisherBackendContract contract,
  ) {
    return <String, Object?>{
      'contractVersion': contract.contractVersion,
      'miniProgramId': contract.appId,
      'backendBaseUrl': contract.backendBaseUri.toString(),
      'healthEndpoint': contract.healthEndpoint,
      'smokeTestCount': contract.smokeTests.length,
    };
  }

  Map<String, Object?> _publisherBackendContractRouteJson(
    PublisherBackendContractSmokeRouteResult route,
  ) {
    return <String, Object?>{
      'id': route.id,
      'method': route.method,
      'endpoint': route.endpoint,
      'uri': route.uri.toString(),
      'expectedStatus': route.expectedStatus,
      'expectJsonObject': route.expectJsonObject,
      'statusCode': route.statusCode,
      'passed': route.passed,
      'errorCode': route.errorCode,
      'message': route.message,
    };
  }

  String _formatPublisherBackendContractInitResult(
    PublisherBackendContractInitResult result,
  ) {
    return <String>[
      'Created provider-neutral Publisher API contract.',
      'Contract file: ${result.contractPath}',
      'Mini-program: ${result.contract.appId}',
      'Backend base URL: ${result.contract.backendBaseUri}',
      'Smoke tests: ${result.contract.smokeTests.length}',
      'Next validation step:',
      'miniprogram publisher-api contract validate --contract ${result.contractPath}',
    ].join('\n');
  }

  String _formatPublisherBackendContractValidateResult(
    PublisherBackendContractValidateResult result,
  ) {
    return <String>[
      'Provider-neutral Publisher API contract is valid.',
      'Contract file: ${result.contractPath}',
      'Mini-program: ${result.contract.appId}',
      'Backend base URL: ${result.contract.backendBaseUri}',
      'Smoke tests: ${result.contract.smokeTests.length}',
    ].join('\n');
  }

  String _formatPublisherBackendContractSmokeResult(
    PublisherBackendContractSmokeResult result,
  ) {
    final lines = <String>[
      'Provider-neutral Publisher API smoke test.',
      'Contract file: ${result.contractPath}',
      'Mini-program: ${result.contract.appId}',
      'Backend base URL: ${result.contract.backendBaseUri}',
      'Auth token provided: ${result.authTokenProvided}',
      'Passed: ${result.passed}',
      '',
    ];
    for (final route in result.routes) {
      lines.add(
        '${route.method} /${route.endpoint}: ${route.statusCode ?? 'failed'} '
        '${route.passed ? 'OK' : 'FAILED'}',
      );
      if (route.message != null) {
        lines.add('  ${route.message}');
      }
    }
    return lines.join('\n');
  }
}
