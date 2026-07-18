import 'package:path/path.dart' as p;

import 'support.dart';

extension CliEnvCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  LocalCliStateStore get _stateStore => dependencies.stateStore;
  MiniProgramPathResolver get _pathResolver => dependencies.pathResolver;

  Future<int> runEnvCommand(List<String> arguments) => _runEnv(arguments);

  Future<int> _runEnv(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(envUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(envUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEnvInit(arguments.sublist(1));
      case 'configure':
        throw const FormatException(
          'env configure provider delivery was removed. Mini-program '
          'artifacts are static files; build with '
          '`miniprogram artifact build`, verify with '
          '`miniprogram artifact verify`, and host the generated artifacts '
          'directory anywhere.',
        );
      case 'list':
        return _runEnvList(arguments.sublist(1));
      case 'use':
        return _runEnvUse(arguments.sublist(1));
      case 'status':
        return _runEnvStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown env command: ${arguments.first}');
        _stderr.writeln(envUsage());
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

    final cwd = currentWorkingDirectory();
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
    final requestedActiveEnvironment =
        results.option('use')?.trim() ??
        existingState?.activeEnvironment ??
        'local';
    final activeEnvironment = _validateSelectedEnvironmentName(
      requestedActiveEnvironment,
    );
    final state = LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: repoRootPath,
      activeEnvironment: activeEnvironment,
      initializedAtUtc: existingState?.initializedAtUtc ?? now,
      updatedAtUtc: now,
    );
    await _stateStore.writeEnvironmentState(configRootPath, state);
    await _stateStore.writeGlobalEnvironmentState(state);
    _stdout.writeln(
      formatEnvStatusResult(
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

    final resolved = await resolveEnvironmentState(
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

    _stdout.writeln(formatEnvListResult(resolved));
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
      _stdout.writeln('Usage: miniprogram env use local [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'env use expects exactly one environment: local.',
      );
    }

    final resolved = await requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final selectedEnvironment = _validateSelectedEnvironmentName(
      results.rest.single,
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
      formatEnvStatusResult(
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

    final resolved = await resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(envStatusJson(resolved)));
    } else {
      _stdout.writeln(formatEnvStatusResult(resolved));
    }
    return resolved == null ? 1 : 0;
  }

  String _validateSelectedEnvironmentName(String rawName) {
    final trimmedName = rawName.trim();
    if (trimmedName == 'local') {
      return 'local';
    }
    throw FormatException(
      'Environment "$rawName" is not supported in the MVP flow. '
      'Mini-program artifacts are public static files; build with '
      '`miniprogram artifact build`, verify the result, and use '
      'an optional middle-server API from runtime actions.',
    );
  }
}
