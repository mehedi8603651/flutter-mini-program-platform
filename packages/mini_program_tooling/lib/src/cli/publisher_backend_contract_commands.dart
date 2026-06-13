part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendContractCommands on MiniprogramCli {
  Future<int> _runPublisherBackendContract(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendContractUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendContractUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runPublisherBackendContractInit(arguments.sublist(1));
      case 'validate':
        return _runPublisherBackendContractValidate(arguments.sublist(1));
      case 'smoke':
        return _runPublisherBackendContractSmoke(arguments.sublist(1));
      case 'handoff':
        return _runPublisherBackendContractHandoff(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend contract command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendContractUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendContractInit(List<String> arguments) async {
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
      ..addFlag(
        'public',
        negatable: false,
        help: 'Mark this Publisher API as public.',
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
        'Usage: miniprogram publisher-backend contract init --backend-base-url <url> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract init does not accept positional arguments.',
      );
    }
    final rawBackendBaseUrl = results.option('backend-base-url')?.trim() ?? '';
    if (rawBackendBaseUrl.isEmpty) {
      throw const FormatException(
        'publisher-backend contract init requires --backend-base-url <url>.',
      );
    }
    final backendBaseUri = Uri.tryParse(rawBackendBaseUrl);
    if (backendBaseUri == null) {
      throw FormatException(
        'publisher-backend contract init expected a valid --backend-base-url, got: $rawBackendBaseUrl',
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
        accessMode: results.flag('public')
            ? MiniProgramPublisherBackendContract.accessModePublic
            : MiniProgramPublisherBackendContract.accessModeProtected,
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
    List<String> arguments,
  ) async {
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
      _stdout.writeln(
        'Usage: miniprogram publisher-backend contract validate [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract validate does not accept positional arguments.',
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

  Future<int> _runPublisherBackendContractSmoke(List<String> arguments) async {
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
        'access-key',
        help: 'MiniProgram access key to send during smoke checks.',
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
      _stdout.writeln(
        'Usage: miniprogram publisher-backend contract smoke [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract smoke does not accept positional arguments.',
      );
    }
    final timeoutSeconds = int.tryParse(results.option('timeout-seconds')!);
    if (timeoutSeconds == null || timeoutSeconds <= 0) {
      throw const FormatException(
        'publisher-backend contract smoke --timeout-seconds must be positive.',
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
        accessKey: results.option('access-key'),
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
    List<String> arguments,
  ) async {
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
        'delivery-url',
        help: 'Mini-program static artifact base URL.',
      )
      ..addOption(
        'title',
        help: 'Human-readable title. Defaults to manifest title or app id.',
      )
      ..addOption(
        'access-key',
        help: 'MiniProgram access key for protected handoff packages.',
      )
      ..addFlag(
        'public',
        negatable: false,
        help: 'Create a public handoff package.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output partner package path. Defaults to <mini-program-root>/<appId>.partner.json.',
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
        'Usage: miniprogram publisher-backend contract handoff --delivery-url <url> [--access-key <key>|--public] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract handoff does not accept positional arguments.',
      );
    }
    final rawDeliveryUrl = results.option('delivery-url')?.trim() ?? '';
    if (rawDeliveryUrl.isEmpty) {
      throw const FormatException(
        'publisher-backend contract handoff requires --delivery-url <url>.',
      );
    }
    final deliveryUri = Uri.tryParse(rawDeliveryUrl);
    if (deliveryUri == null ||
        !deliveryUri.hasScheme ||
        deliveryUri.host.isEmpty) {
      throw FormatException(
        'publisher-backend contract handoff expected an absolute --delivery-url, got: $rawDeliveryUrl',
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
    final manifestInfo = await _readMiniProgramManifestInfo(
      miniProgramRootPath,
    );
    if (manifestInfo.appId != contract.appId) {
      throw FormatException(
        'Publisher API contract appId "${contract.appId}" does not match manifest appId "${manifestInfo.appId}".',
      );
    }
    final accessKey = results.option('access-key')?.trim() ?? '';
    final explicitPublic = results.flag('public');
    if (explicitPublic && accessKey.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract handoff cannot use both --public and --access-key.',
      );
    }
    if (contract.isProtected) {
      if (explicitPublic) {
        throw const FormatException(
          'publisher-backend contract handoff cannot create a public package for a protected contract.',
        );
      }
      if (accessKey.isEmpty) {
        throw const FormatException(
          'publisher-backend contract handoff requires --access-key <key> for protected contracts.',
        );
      }
    } else if (accessKey.isNotEmpty) {
      throw const FormatException(
        'publisher-backend contract handoff received --access-key for a public contract.',
      );
    }

    final outputPath = results.option('output')?.trim().isNotEmpty == true
        ? results.option('output')!.trim()
        : p.join(miniProgramRootPath, '${contract.appId}.partner.json');
    final packageResult = await _partnerHandoffController.createPackage(
      MiniProgramPartnerPackageRequest(
        appId: contract.appId,
        title: results.option('title')?.trim().isNotEmpty == true
            ? results.option('title')!.trim()
            : manifestInfo.title ?? _defaultTitleForAppId(contract.appId),
        apiBaseUri: deliveryUri,
        backendBaseUri: contract.backendBaseUri,
        accessKey: contract.isProtected ? accessKey : null,
        outputPath: outputPath,
      ),
    );
    final result = _PublisherBackendContractHandoffResult(
      contractPath: contractPath,
      packageResult: packageResult,
      hostImportCommandText:
          'miniprogram host endpoint import ${packageResult.filePath}',
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendContractHandoffJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendContractHandoffResult(result));
    }
    return 0;
  }

  Map<String, Object?> _publisherBackendContractInitJson(
    PublisherBackendContractInitResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend contract init',
      'contractPath': result.contractPath,
      ..._publisherBackendContractJson(result.contract),
    };
  }

  Map<String, Object?> _publisherBackendContractValidateJson(
    PublisherBackendContractValidateResult result,
  ) {
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend contract validate',
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
      'command': 'publisher-backend contract smoke',
      'contractPath': result.contractPath,
      ..._publisherBackendContractJson(result.contract),
      'accessKeyProvided': result.accessKeyProvided,
      'authTokenProvided': result.authTokenProvided,
      'passed': result.passed,
      'routes': result.routes.map(_publisherBackendContractRouteJson).toList(),
    };
  }

  Map<String, Object?> _publisherBackendContractHandoffJson(
    _PublisherBackendContractHandoffResult result,
  ) {
    final handoff = result.packageResult.handoff;
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'publisher-backend contract handoff',
      'contractPath': result.contractPath,
      'miniProgramId': handoff.appId,
      'title': handoff.title,
      'deliveryApiBaseUrl': handoff.apiBaseUri.toString(),
      'backendBaseUrl': handoff.backendBaseUri?.toString(),
      'accessMode': handoff.accessMode,
      'accessKeyIncluded': handoff.accessKey != null,
      'packagePath': result.packageResult.filePath,
      'generatedAtUtc': handoff.generatedAtUtc,
      'hostImportCommandText': result.hostImportCommandText,
    };
  }

  Map<String, Object?> _publisherBackendContractJson(
    MiniProgramPublisherBackendContract contract,
  ) {
    return <String, Object?>{
      'contractVersion': contract.contractVersion,
      'miniProgramId': contract.appId,
      'backendBaseUrl': contract.backendBaseUri.toString(),
      'accessMode': contract.accessMode,
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
      'Access mode: ${result.contract.accessMode}',
      'Smoke tests: ${result.contract.smokeTests.length}',
      'Next validation step:',
      'miniprogram publisher-backend contract validate --contract ${result.contractPath}',
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
      'Access mode: ${result.contract.accessMode}',
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
      'Access mode: ${result.contract.accessMode}',
      'Access key provided: ${result.accessKeyProvided}',
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

  String _formatPublisherBackendContractHandoffResult(
    _PublisherBackendContractHandoffResult result,
  ) {
    final handoff = result.packageResult.handoff;
    return <String>[
      'Provider-neutral Publisher API handoff package created.',
      'Contract file: ${result.contractPath}',
      'Package file: ${result.packageResult.filePath}',
      'Mini-program: ${handoff.appId}',
      'Title: ${handoff.title}',
      'Delivery API base URL: ${handoff.apiBaseUri}',
      if (handoff.backendBaseUri != null)
        'Backend base URL: ${handoff.backendBaseUri}',
      'Access mode: ${handoff.accessMode}',
      'Access key included: ${handoff.accessKey != null}',
      'Host developer next step:',
      result.hostImportCommandText,
    ].join('\n');
  }
}

class _PublisherBackendContractHandoffResult {
  const _PublisherBackendContractHandoffResult({
    required this.contractPath,
    required this.packageResult,
    required this.hostImportCommandText,
  });

  final String contractPath;
  final MiniProgramPartnerPackageResult packageResult;
  final String hostImportCommandText;
}
