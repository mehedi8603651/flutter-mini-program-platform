part of '../miniprogram_cli.dart';

extension _MiniprogramCliArtifactCommands on MiniprogramCli {
  Future<int> _runArtifact(List<String> arguments) async {
    if (arguments.isEmpty ||
        arguments.first == 'help' ||
        arguments.first == '--help' ||
        arguments.first == '-h') {
      _stdout.writeln(_artifactUsage());
      return 0;
    }
    return switch (arguments.first) {
      'build' => _runArtifactBuild(arguments.sublist(1)),
      'verify' => _runArtifactVerify(arguments.sublist(1)),
      _ => throw FormatException(
        'Unknown artifact command: ${arguments.first}\n${_artifactUsage()}',
      ),
    };
  }

  Future<int> _runArtifactBuild(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used for mini-program discovery.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'artifacts-root',
        help:
            'Optional generated artifacts root. Defaults to <mini-program-root>/artifacts.',
      )
      ..addOption(
        'mp-build-script',
        help: 'Optional explicit path to tool/build_mp.dart.',
      )
      ..addFlag(
        'skip-pub-get',
        negatable: false,
        help: 'Skip dart pub get inside the mini-program package.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram artifact build [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolveArtifactMiniProgram(
      commandName: 'artifact build',
      positionalArguments: results.rest,
      explicitRepoRootPath: results.option('repo-root'),
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _artifactBuilder.build(
      MiniProgramArtifactBuildRequest(
        repoRootPath: resolved.repoRootPath,
        miniProgramId: resolved.miniProgramId,
        miniProgramRootPath: resolved.miniProgramRootPath,
        artifactsRootPath: results.option('artifacts-root'),
        mpBuildScriptPath: results.option('mp-build-script'),
        skipPubGet: results.flag('skip-pub-get'),
      ),
    );
    _stdout.writeln(
      results.flag('json')
          ? _prettyJson(result.toJson())
          : _formatArtifactBuildResult(result),
    );
    return 0;
  }

  Future<int> _runArtifactVerify(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used for mini-program discovery.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'artifacts-root',
        help:
            'Optional generated artifacts root. Defaults to <mini-program-root>/artifacts.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram artifact verify [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolveArtifactMiniProgram(
      commandName: 'artifact verify',
      positionalArguments: results.rest,
      explicitRepoRootPath: results.option('repo-root'),
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final result = await _artifactVerifier.verify(
      MiniProgramArtifactVerifyRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        miniProgramId: resolved.miniProgramId,
        artifactsRootPath: results.option('artifacts-root'),
      ),
    );
    _stdout.writeln(
      results.flag('json')
          ? _prettyJson(result.toJson())
          : _formatArtifactVerifyResult(result),
    );
    return 0;
  }

  Future<_ResolvedArtifactMiniProgram> _resolveArtifactMiniProgram({
    required String commandName,
    required List<String> positionalArguments,
    required String? explicitRepoRootPath,
    required String? explicitMiniProgramRootPath,
  }) async {
    final miniProgramId = await _resolveMiniProgramId(
      commandName: commandName,
      positionalArguments: positionalArguments,
      explicitMiniProgramRootPath: explicitMiniProgramRootPath,
    );
    final repoRootHint = await _resolveRepoRootPath(
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: <String>[
        if (explicitMiniProgramRootPath case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
      required: false,
    );
    final resolved = await _pathResolver.resolve(
      miniProgramId: miniProgramId,
      repoRootPath: repoRootHint,
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    return _ResolvedArtifactMiniProgram(
      miniProgramId: miniProgramId,
      repoRootPath: resolved.repoRootPath,
      miniProgramRootPath: resolved.miniProgramRootPath,
    );
  }
}

class _ResolvedArtifactMiniProgram {
  const _ResolvedArtifactMiniProgram({
    required this.miniProgramId,
    required this.repoRootPath,
    required this.miniProgramRootPath,
  });

  final String miniProgramId;
  final String? repoRootPath;
  final String miniProgramRootPath;
}
