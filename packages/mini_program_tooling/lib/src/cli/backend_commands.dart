part of '../miniprogram_cli.dart';

extension _MiniprogramCliBackendCommands on MiniprogramCli {
  Future<int> _runBackend(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_backendUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_backendUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runBackendInit(arguments.sublist(1));
      case 'start':
        return _runBackendStart(arguments.sublist(1));
      case 'stop':
        return _runBackendStop(arguments.sublist(1));
      case 'status':
        return _runBackendStatus(arguments.sublist(1));
      case 'reset-local':
        return _runBackendResetLocal(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown backend command: ${arguments.first}');
        _stderr.writeln(_backendUsage());
        return 64;
    }
  }

  Future<int> _runBackendInit(List<String> arguments) async {
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
            'Directory that should own backend/ and .mini_program/backend_workspace.json. Defaults to the per-user global backend workspace.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite scaffold-managed backend files if they already exist.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram backend init [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'backend init does not accept positional arguments.',
      );
    }

    final result = await _backendInitializer.initialize(
      LocalBackendInitRequest(
        backendRootPath: results.option('root'),
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(_formatBackendInitResult(result));
    return 0;
  }

  Future<int> _runBackendStart(List<String> arguments) async {
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
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.')
      ..addOption(
        'port',
        defaultsTo: '8080',
        help: 'Port to bind for the local backend.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram backend start [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final port = int.tryParse(results.option('port')!);
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException('backend start --port must be 1-65535.');
    }

    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.start(
      repoRootPath: backendRootPath!,
      port: port,
    );
    _stdout.writeln(_formatBackendStartResult(result));
    return 0;
  }

  Future<int> _runBackendStop(List<String> arguments) async {
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
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram backend stop [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.stop(
      repoRootPath: backendRootPath!,
    );
    _stdout.writeln(_formatBackendStopResult(result));
    return 0;
  }

  Future<int> _runBackendStatus(List<String> arguments) async {
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
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram backend status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.status(
      repoRootPath: backendRootPath!,
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(miniProgramWorkflowStatusBackendJson(result)),
      );
    } else {
      _stdout.writeln(_formatBackendStatusResult(result));
    }
    return result.healthy ? 0 : 1;
  }

  Future<int> _runBackendResetLocal(List<String> arguments) async {
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
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption('repo-root', help: 'Legacy platform repo root override.')
      ..addFlag(
        'yes',
        negatable: false,
        help: 'Confirm destructive local publish cleanup.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram backend reset-local --yes [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (!results.flag('yes')) {
      throw const FormatException(
        'backend reset-local is destructive and requires --yes.',
      );
    }

    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      required: true,
    );
    final result = await _backendController.resetLocal(
      repoRootPath: backendRootPath!,
    );
    _stdout.writeln(_formatBackendResetResult(result));
    return 0;
  }
}
