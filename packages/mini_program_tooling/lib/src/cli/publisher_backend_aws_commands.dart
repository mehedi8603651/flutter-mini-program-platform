part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendAwsCommands on MiniprogramCli {
  Future<int> _runPublisherBackendAws(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendAwsUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendAwsUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'deploy':
        return _runPublisherBackendAwsDeploy(arguments.sublist(1));
      case 'status':
        return _runPublisherBackendAwsStatus(arguments.sublist(1));
      case 'outputs':
        return _runPublisherBackendAwsOutputs(arguments.sublist(1));
      case 'smoke':
        return _runPublisherBackendAwsSmoke(arguments.sublist(1));
      case 'seed':
        return _runPublisherBackendAwsSeed(arguments.sublist(1));
      case 'data':
        return _runPublisherBackendAwsData(arguments.sublist(1));
      case 'logs':
        return _runPublisherBackendAwsLogs(arguments.sublist(1));
      case 'destroy':
        return _runPublisherBackendAwsDestroy(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend aws command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendAwsUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendAwsDeploy(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws deploy [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDeploy(
      PublisherBackendAwsDeployRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
      ),
    );
    _stdout.writeln(_formatPublisherBackendAwsDeployResult(result));
    return result.healthy == false ? 1 : 0;
  }

  Future<int> _runPublisherBackendAwsStatus(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws status [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsStatus(
      PublisherBackendAwsStatusRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsStatusJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsStatusResult(result));
    }
    return !result.stackExists || result.healthy == false ? 1 : 0;
  }

  Future<int> _runPublisherBackendAwsOutputs(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws outputs [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsOutputs(
      PublisherBackendAwsOutputsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsOutputsJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsOutputsResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendAwsSmoke(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'include-write',
        negatable: false,
        help: 'Also verify POST /coupon/redeem. This mutates backend data.',
      )
      ..addOption(
        'write-coupon-id',
        defaultsTo: 'coupon-10',
        help: 'Coupon ID used with --include-write.',
      )
      ..addOption(
        'write-user-id',
        defaultsTo: 'smoke-user',
        help: 'User ID used with --include-write.',
      )
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws smoke [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final includeWrite = results.flag('include-write');
    if (!includeWrite &&
        (results.wasParsed('write-coupon-id') ||
            results.wasParsed('write-user-id'))) {
      _stderr.writeln(
        '--write-coupon-id and --write-user-id require --include-write.',
      );
      return 64;
    }
    final writeCouponId = results.option('write-coupon-id')?.trim() ?? '';
    final writeUserId = results.option('write-user-id')?.trim() ?? '';
    if (includeWrite && (writeCouponId.isEmpty || writeUserId.isEmpty)) {
      _stderr.writeln(
        '--write-coupon-id and --write-user-id must not be empty.',
      );
      return 64;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsSmoke(
      PublisherBackendAwsSmokeRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        includeWrite: includeWrite,
        writeCouponId: writeCouponId,
        writeUserId: writeUserId,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsSmokeJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsSmokeResult(result));
    }
    return result.passed ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsSeed(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws seed [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsSeed(
      PublisherBackendAwsSeedRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsSeedJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsSeedResult(result));
    }
    return result.seeded ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsData(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendAwsDataUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendAwsDataUsage());
      return 64;
    }
    switch (arguments.first) {
      case 'status':
        return _runPublisherBackendAwsDataStatus(arguments.sublist(1));
      case 'export':
        return _runPublisherBackendAwsDataExport(arguments.sublist(1));
      case 'import':
        return _runPublisherBackendAwsDataImport(arguments.sublist(1));
      case 'redemptions':
        return _runPublisherBackendAwsDataRedemptions(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend aws data command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendAwsDataUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendAwsDataStatus(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws data status [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDataStatus(
      PublisherBackendAwsDataStatusRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsDataStatusJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsDataStatusResult(result));
    }
    return result.available ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsDataExport(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'include-redemptions',
        negatable: false,
        help: 'Include redemption records in the export file.',
      )
      ..addOption('output', help: 'Optional export JSON file path.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws data export [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDataExport(
      PublisherBackendAwsDataExportRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        outputPath: results.option('output'),
        includeRedemptions: results.flag('include-redemptions'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsDataExportJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsDataExportResult(result));
    }
    return result.exported ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsDataImport(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'include-redemptions',
        negatable: false,
        help: 'Import redemption records from the export file.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Validate and summarize the import without writing data.',
      )
      ..addOption('input', help: 'Required export JSON file path.')
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws data import --input <file> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final inputPath = results.option('input')?.trim();
    if (inputPath == null || inputPath.isEmpty) {
      throw const FormatException(
        'publisher-backend aws data import requires --input <file>.',
      );
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDataImport(
      PublisherBackendAwsDataImportRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        inputPath: inputPath,
        includeRedemptions: results.flag('include-redemptions'),
        dryRun: results.flag('dry-run'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendAwsDataImportJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendAwsDataImportResult(result));
    }
    return result.succeeded ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsDataRedemptions(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('coupon-id', help: 'Optional coupon ID filter.')
      ..addOption('user-id', help: 'Optional user ID filter.')
      ..addOption(
        'limit',
        defaultsTo: '50',
        help: 'Maximum records to print. Default: 50. Max: 500.',
      )
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws data redemptions [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final limit = int.tryParse(results.option('limit') ?? '');
    if (limit == null || limit < 1 || limit > 500) {
      throw const FormatException(
        'publisher-backend aws data redemptions --limit must be between 1 and 500.',
      );
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDataRedemptions(
      PublisherBackendAwsDataRedemptionsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        couponId: results.option('coupon-id'),
        userId: results.option('user-id'),
        limit: limit,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendAwsDataRedemptionsJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendAwsDataRedemptionsResult(result));
    }
    return result.available ? 0 : 1;
  }

  Future<int> _runPublisherBackendAwsLogs(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      )
      ..addOption('since', defaultsTo: '1h', help: 'CloudWatch tail window.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws logs [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsLogs(
      PublisherBackendAwsLogsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        since: results.option('since') ?? '1h',
      ),
    );
    _stdout.writeln(_formatPublisherBackendAwsLogsResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendAwsDestroy(List<String> arguments) async {
    final parser = _publisherBackendAwsCommandParser()
      ..addOption('stack-name', help: 'Optional CloudFormation stack name.')
      ..addOption('stage-name', help: 'Optional API Gateway stage name.')
      ..addOption(
        'sam-s3-bucket',
        help: 'Optional S3 bucket for AWS SAM deployment artifacts.',
      )
      ..addFlag(
        'yes',
        negatable: false,
        help: 'Required confirmation for stack deletion.',
      )
      ..addFlag(
        'confirm-data-loss',
        negatable: false,
        help: 'Allow deleting a stack-owned DynamoDB table that contains data.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend aws destroy [options] --yes',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (!results.flag('yes')) {
      throw const FormatException(
        'publisher-backend aws destroy is destructive and requires --yes.',
      );
    }
    final resolved = await _resolvePublisherBackendAwsInputs(results);
    final result = await _publisherBackendStarter.awsDestroy(
      PublisherBackendAwsDestroyRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        stackName: results.option('stack-name'),
        stageName: results.option('stage-name'),
        samS3Bucket: results.option('sam-s3-bucket'),
        confirmDataLoss: results.flag('confirm-data-loss'),
      ),
    );
    _stdout.writeln(_formatPublisherBackendAwsDestroyResult(result));
    return result.deleted ? 0 : 1;
  }

  ArgParser _publisherBackendAwsCommandParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named AWS cloud environment override.')
    ..addOption(
      'mini-program-root',
      help: 'Exact mini-program root. Defaults to the current directory.',
    );

  Future<_PublisherBackendAwsInputs> _resolvePublisherBackendAwsInputs(
    ArgResults results,
  ) async {
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend aws commands do not accept positional arguments.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final resolvedEnvironment = await _requireEnvironmentState(
      additionalSearchRoots: <String>[miniProgramRootPath],
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolvedEnvironment.state,
      explicitEnvironmentName: results.option('env'),
    );
    if (environment.provider != 'aws') {
      throw FormatException(
        'publisher-backend aws requires an aws environment. '
        'Environment "${environment.name}" uses provider "${environment.provider}".',
      );
    }
    return _PublisherBackendAwsInputs(
      miniProgramRootPath: miniProgramRootPath,
      environment: environment,
    );
  }
}
