import 'support.dart';

extension CliBackendCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  LocalBackendController get _backendController =>
      dependencies.backendController;
  LocalBackendInitializer get _backendInitializer =>
      dependencies.backendInitializer;

  Future<int> runBackendCommand(
    List<String> arguments, {
    required String commandName,
  }) => _runBackend(arguments, commandName: commandName);

  Future<int> _runBackend(
    List<String> arguments, {
    required String commandName,
  }) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(backendUsage(commandName: commandName));
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(backendUsage(commandName: commandName));
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runBackendInit(arguments.sublist(1), commandName: commandName);
      case 'start':
        return _runBackendStart(arguments.sublist(1), commandName: commandName);
      case 'stop':
        return _runBackendStop(arguments.sublist(1), commandName: commandName);
      case 'status':
        return _runBackendStatus(
          arguments.sublist(1),
          commandName: commandName,
        );
      case 'reset-local':
        return _runBackendResetLocal(
          arguments.sublist(1),
          commandName: commandName,
        );
      default:
        _stderr.writeln('Unknown $commandName command: ${arguments.first}');
        _stderr.writeln(backendUsage(commandName: commandName));
        return 64;
    }
  }

  Future<int> _runBackendInit(
    List<String> arguments, {
    required String commandName,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'root',
        help:
            'Directory that should own backend/api, the local artifact service, and .mini_program/backend_workspace.json. Defaults to the per-user global artifact workspace.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Overwrite scaffold-managed local artifact host files if they already exist.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $commandName init [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw FormatException(
        '$commandName init does not accept positional arguments.',
      );
    }

    final result = await _backendInitializer.initialize(
      LocalBackendInitRequest(
        backendRootPath: results.option('root'),
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(formatBackendInitResult(result));
    return 0;
  }

  Future<int> _runBackendStart(
    List<String> arguments, {
    required String commandName,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.')
      ..addOption(
        'port',
        defaultsTo: '8080',
        help: 'Port to bind for the local artifact host.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $commandName start [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('$commandName start --port must be 1-65535.');
    }

    final backendRootPath = await resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.start(
      repoRootPath: backendRootPath!,
      port: port,
    );
    _stdout.writeln(formatBackendStartResult(result));
    return 0;
  }

  Future<int> _runBackendStop(
    List<String> arguments, {
    required String commandName,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $commandName stop [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final backendRootPath = await resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.stop(
      repoRootPath: backendRootPath!,
    );
    _stdout.writeln(formatBackendStopResult(result));
    return 0;
  }

  Future<int> _runBackendStatus(
    List<String> arguments, {
    required String commandName,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram $commandName status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final backendRootPath = await resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.status(
      repoRootPath: backendRootPath!,
    );
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(miniProgramWorkflowStatusBackendJson(result)));
    } else {
      _stdout.writeln(formatBackendStatusResult(result));
    }
    return result.healthy ? 0 : 1;
  }

  Future<int> _runBackendResetLocal(
    List<String> arguments, {
    required String commandName,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.')
      ..addFlag(
        'yes',
        negatable: false,
        help: 'Confirm destructive local publish cleanup.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram $commandName reset-local --yes [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (!results.flag('yes')) {
      throw FormatException(
        '$commandName reset-local is destructive and requires --yes.',
      );
    }

    final backendRootPath = await resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.resetLocal(
      repoRootPath: backendRootPath!,
    );
    _stdout.writeln(formatBackendResetResult(result));
    return 0;
  }
}
