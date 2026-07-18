import 'publisher_backend_contract_commands.dart';
import 'support.dart';

extension CliPublisherBackendCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  PublisherBackendStarter get _publisherBackendStarter =>
      dependencies.publisherBackendStarter;

  Future<int> runPublisherBackendCommand(
    List<String> arguments, {
    String commandName = 'publisher-backend',
  }) => _runPublisherBackend(arguments, commandName: commandName);

  Future<int> _runPublisherBackend(
    List<String> arguments, {
    String commandName = 'publisher-backend',
  }) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(publisherBackendUsage(commandName: commandName));
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(publisherBackendUsage(commandName: commandName));
      return 64;
    }

    switch (arguments.first) {
      case 'scaffold':
        return _runPublisherBackendScaffold(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'run':
        return _runPublisherBackendRun(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'status':
        return _runPublisherBackendStatus(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'stop':
        return _runPublisherBackendStop(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'urls':
        return _runPublisherBackendUrls(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'contract':
        return runPublisherBackendContractCommand(
          arguments.sublist(1),
          commandName: commandName,
        );
      default:
        _stderr.writeln('Unknown $commandName command: ${arguments.first}');
        _stderr.writeln(publisherBackendUsage(commandName: commandName));
        return 64;
    }
  }

  Future<int> _runPublisherBackendScaffold(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName scaffold';
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
        help: 'Publisher API starter template. Only local mock is supported.',
      )
      ..addOption(
        'storage',
        defaultsTo: 'bundled',
        help:
            'Publisher API storage mode. Real storage belongs on your external API server.',
        hide: true,
      )
      ..addOption(
        'mini-program-root',
        help: 'Exact mini-program root. Defaults to the current directory.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite scaffold-managed mock Publisher API files.',
      )
      ..addFlag(
        'with-starter-ui',
        negatable: false,
        help:
            'Removed. Author UI against provider-neutral API endpoints instead.',
        hide: true,
      );
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
    final miniProgramRootPath = await resolveCurrentMiniProgramRootPath(
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
    _stdout.writeln(formatPublisherBackendScaffoldResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendRun(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName run';
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
        help: 'Port to bind for the mock Publisher API.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('$qualifiedCommand --port must be 1-65535.');
    }
    final miniProgramRootPath = await resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.run(
      miniProgramRootPath: miniProgramRootPath,
      port: port,
    );
    _stdout.writeln(formatPublisherBackendRunResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendStatus(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName status';
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
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramRootPath = await resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.status(
      miniProgramRootPath: miniProgramRootPath,
    );
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(publisherBackendStatusJson(result)));
    } else {
      _stdout.writeln(formatPublisherBackendStatusResult(result));
    }
    return result.healthy ? 0 : 1;
  }

  Future<int> _runPublisherBackendStop(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName stop';
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
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramRootPath = await resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _publisherBackendStarter.stop(
      miniProgramRootPath: miniProgramRootPath,
    );
    _stdout.writeln(formatPublisherBackendStopResult(result));
    return 0;
  }

  Future<int> _runPublisherBackendUrls(
    List<String> arguments, {
    required String commandName,
  }) async {
    final qualifiedCommand = '$commandName urls';
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
      _stdout.writeln('Usage: miniprogram $qualifiedCommand [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('$qualifiedCommand --port must be 1-65535.');
    }
    _stdout.writeln(
      formatPublisherBackendUrlsResult(
        _publisherBackendStarter.urls(port: port),
      ),
    );
    return 0;
  }
}
