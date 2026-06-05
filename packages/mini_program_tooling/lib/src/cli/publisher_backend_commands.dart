part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendCommands on MiniprogramCli {
  Future<int> _runPublisherBackend(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'scaffold':
        return _runPublisherBackendScaffold(arguments.sublist(1));
      case 'run':
        return _runPublisherBackendRun(arguments.sublist(1));
      case 'status':
        return _runPublisherBackendStatus(arguments.sublist(1));
      case 'stop':
        return _runPublisherBackendStop(arguments.sublist(1));
      case 'urls':
        return _runPublisherBackendUrls(arguments.sublist(1));
      case 'contract':
        return _runPublisherBackendContract(arguments.sublist(1));
      case 'aws':
        return _runPublisherBackendAws(arguments.sublist(1));
      case 'firebase':
        return _runPublisherBackendFirebase(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendScaffold(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'template',
        defaultsTo: 'mock',
        allowed: const <String>['mock', 'aws-lambda', 'firebase-functions'],
        help: 'Publisher backend starter template.',
      )
      ..addOption(
        'storage',
        defaultsTo: 'bundled',
        allowed: const <String>['bundled', 'dynamodb', 'firestore'],
        help:
            'Publisher backend storage mode. Use bundled|dynamodb for AWS Lambda or firestore for Firebase Functions.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite scaffold-managed publisher backend files.',
      )
      ..addFlag(
        'with-starter-ui',
        negatable: false,
        help:
            'For Firebase Functions + Firestore, also generate the matching auth/data starter UI and seed data.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend scaffold [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend scaffold does not accept positional arguments.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRootPath,
        template: results.option('template')!,
        storageMode: results.option('storage')!,
        force: results.flag('force'),
        withStarterUi: results.flag('with-starter-ui'),
      ),
    );
    _stdout.writeln(_formatPublisherBackendScaffoldResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendRun(List<String> arguments) async {
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
        'port',
        defaultsTo: '9090',
        help: 'Port to bind for the mock publisher backend.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publisher-backend run [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException(
        'publisher-backend run --port must be 1-65535.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.run(
      miniProgramRootPath: miniProgramRootPath,
      port: port,
    );
    _stdout.writeln(_formatPublisherBackendRunResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publisher-backend status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.status(
      miniProgramRootPath: miniProgramRootPath,
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendStatusJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendStatusResult(result));
    }
    return result.healthy ? 0 : 1;
  }

  Future<int> _runPublisherBackendStop(List<String> arguments) async {
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
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publisher-backend stop [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.stop(
      miniProgramRootPath: miniProgramRootPath,
    );
    _stdout.writeln(_formatPublisherBackendStopResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendUrls(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'port',
        defaultsTo: '9090',
        help: 'Port to use in generated local URLs.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publisher-backend urls [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException(
        'publisher-backend urls --port must be 1-65535.',
      );
    }
    _stdout.writeln(
      _formatPublisherBackendUrlsResult(
        _publisherBackendStarter.urls(port: port),
      ),
    );
    return 0;
  }
}
