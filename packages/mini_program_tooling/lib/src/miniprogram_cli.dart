import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'delivery_validation.dart';
import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_backend_initializer.dart';
import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'miniprogram_doctor.dart';
import 'mini_program_embedding_initializer.dart';
import 'mini_program_path_resolver.dart';
import 'mini_program_publisher.dart';
import 'mini_program_scaffolder.dart';

class MiniprogramCli {
  MiniprogramCli({
    MiniProgramScaffolder scaffolder = const MiniProgramScaffolder(),
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
    MiniProgramPublisher publisher = const MiniProgramPublisher(),
    MiniProgramEmbeddingInitializer embeddingInitializer =
        const MiniProgramEmbeddingInitializer(),
    LocalBackendController backendController = const LocalBackendController(),
    LocalBackendInitializer backendInitializer =
        const LocalBackendInitializer(),
    MiniprogramDoctor doctor = const MiniprogramDoctor(),
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    MiniProgramPathResolver pathResolver = const MiniProgramPathResolver(),
    StringSink? stdoutSink,
    StringSink? stderrSink,
    String? workingDirectory,
  }) : _scaffolder = scaffolder,
       _builder = builder,
       _validator = validator,
       _publisher = publisher,
       _embeddingInitializer = embeddingInitializer,
       _backendController = backendController,
       _backendInitializer = backendInitializer,
       _doctor = doctor,
       _stateStore = stateStore,
       _pathResolver = pathResolver,
       _stdout = stdoutSink ?? stdout,
       _stderr = stderrSink ?? stderr,
       _workingDirectory = workingDirectory;

  final MiniProgramScaffolder _scaffolder;
  final MiniProgramBuilder _builder;
  final DeliveryRepositoryValidator _validator;
  final MiniProgramPublisher _publisher;
  final MiniProgramEmbeddingInitializer _embeddingInitializer;
  final LocalBackendController _backendController;
  final LocalBackendInitializer _backendInitializer;
  final MiniprogramDoctor _doctor;
  final LocalCliStateStore _stateStore;
  final MiniProgramPathResolver _pathResolver;
  final StringSink _stdout;
  final StringSink _stderr;
  final String? _workingDirectory;

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty ||
        arguments.first == 'help' ||
        arguments.first == '--help' ||
        arguments.first == '-h') {
      _stdout.writeln(_rootUsage());
      return 0;
    }

    try {
      switch (arguments.first) {
        case 'create':
          return await _runCreate(arguments.sublist(1));
        case 'doctor':
          return await _runDoctor(arguments.sublist(1));
        case 'env':
          return await _runEnv(arguments.sublist(1));
        case 'build':
          return await _runBuild(arguments.sublist(1));
        case 'validate':
          return await _runValidate(arguments.sublist(1));
        case 'publish':
          return await _runPublish(arguments.sublist(1));
        case 'embed':
          return await _runEmbed(arguments.sublist(1));
        case 'backend':
          return await _runBackend(arguments.sublist(1));
        default:
          _stderr.writeln('Unknown command: ${arguments.first}');
          _stderr.writeln(_rootUsage());
          return 64;
      }
    } on FormatException catch (error) {
      _stderr.writeln(error.message);
      return 64;
    } on MiniProgramScaffoldException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramBuildException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPublishException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramEmbeddingInitException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPathResolutionException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on LocalCliStateException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on LocalBackendControlException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    }
  }

  Future<int> _runCreate(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Repository root for repo-managed creation under mini_programs/.',
      )
      ..addOption(
        'output-root',
        help:
            'Optional exact output directory. Defaults to ./<mini-program-id>.',
      )
      ..addOption('title', help: 'Optional human-readable title.')
      ..addOption(
        'description',
        help: 'Optional description written into the generated README.',
      )
      ..addOption(
        'capabilities',
        defaultsTo: 'analytics,native_navigation',
        help: 'Comma-separated capability wire values.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite scaffold-managed files if the target already exists.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram create <mini-program-id> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'create expects exactly one <mini-program-id> positional argument.',
      );
    }

    final miniProgramId = results.rest.single;
    final repoRootPath = results.option('repo-root');
    final outputRootPath =
        results.option('output-root') ??
        (repoRootPath == null
            ? p.join(_currentWorkingDirectory(), miniProgramId)
            : null);

    final result = await _scaffolder.scaffold(
      MiniProgramScaffoldRequest(
        repoRootPath: repoRootPath,
        outputRootPath: outputRootPath,
        miniProgramId: miniProgramId,
        title: results.option('title'),
        description: results.option('description'),
        capabilities: _parseCapabilities(results.option('capabilities')!),
        force: results.flag('force'),
      ),
    );

    _stdout.writeln(_formatCreateResult(result));
    return 0;
  }

  Future<int> _runDoctor(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional explicit platform repo root to verify.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram doctor [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'doctor does not accept positional arguments.',
      );
    }

    final result = await _doctor.diagnose(
      explicitRepoRootPath: results.option('repo-root'),
    );
    _stdout.writeln(_formatDoctorResult(result));
    return result.hasErrors ? 1 : 0;
  }

  Future<int> _runBuild(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used for vendored Stac CLI resolution.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'stac-cli-script',
        help: 'Optional explicit path to bin/stac_cli.dart.',
      )
      ..addFlag(
        'skip-pub-get',
        negatable: false,
        help: 'Skip dart pub get inside the mini-program package.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram build [mini-program-id] [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'build',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final cwd = _currentWorkingDirectory();
    final repoRootHint = await _resolveRepoRootPath(
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
    );
    final resolved = await _pathResolver.resolve(
      miniProgramId: miniProgramId,
      repoRootPath: repoRootHint,
      miniProgramRootPath: results.option('mini-program-root'),
      currentWorkingDirectory: cwd,
    );

    final result = await _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: resolved.repoRootPath,
        miniProgramId: miniProgramId,
        miniProgramRootPath: resolved.miniProgramRootPath,
        stacCliScriptPath: results.option('stac-cli-script'),
        skipPubGet: results.flag('skip-pub-get'),
      ),
    );

    _stdout.writeln(_formatBuildResult(result));
    return 0;
  }

  Future<int> _runValidate(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Platform repo root containing backend/api/.',
      )
      ..addOption(
        'root',
        help:
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram validate [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'validate',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final repoRootHint = await _resolveRepoRootPath(
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
      required: false,
    );
    final resolved = await _pathResolver.resolve(
      miniProgramId: miniProgramId,
      repoRootPath: repoRootHint,
      miniProgramRootPath: results.option('mini-program-root'),
      currentWorkingDirectory: _currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[resolved.miniProgramRootPath],
      required: true,
    );
    final report = await _validator.validate(
      repoRootPath: backendRootPath!,
      authoredRepoRootPath:
          resolved.repoRootPath ?? resolved.miniProgramRootPath,
      backendRootPath: backendRootPath,
      miniProgramId: miniProgramId,
      externalMiniProgramRootPath: resolved.isRepoManaged
          ? null
          : resolved.miniProgramRootPath,
    );
    _stdout.writeln(formatDeliveryValidationReport(report));
    return report.hasErrors ? 1 : 0;
  }

  Future<int> _runPublish(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'repo-root',
        help: 'Platform repo root containing backend/api/.',
      )
      ..addOption(
        'root',
        help:
            'Backend workspace root. Defaults to a discovered backend init workspace or platform repo root.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'stac-cli-script',
        help: 'Optional explicit path to bin/stac_cli.dart.',
      )
      ..addFlag(
        'skip-build-pub-get',
        negatable: false,
        help: 'Skip dart pub get inside the mini-program package during build.',
      )
      ..addOption(
        'target',
        allowed: LocalCliEnvironmentState.supportedEnvironments,
        help: 'Publish target. Defaults to the active env or local.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publish [mini-program-id] [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final activeEnvironment = await _discoverEnvironmentState(
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
    );
    final target =
        results.option('target') ??
        activeEnvironment?.state.activeEnvironment ??
        'local';
    if (target == 'cloud') {
      throw const MiniProgramPublishException(
        'Cloud publish is reserved for a later CLI phase. Use --target local '
        'or omit the flag.',
      );
    }

    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'publish',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final repoRootHint = await _resolveRepoRootPath(
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
      required: false,
    );
    final resolved = await _pathResolver.resolve(
      miniProgramId: miniProgramId,
      repoRootPath: repoRootHint,
      miniProgramRootPath: results.option('mini-program-root'),
      currentWorkingDirectory: _currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    final backendRootPath = await _resolveBackendRootPath(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[resolved.miniProgramRootPath],
      required: true,
    );

    final result = await _publisher.publish(
      MiniProgramPublishRequest(
        repoRootPath: resolved.repoRootPath ?? resolved.miniProgramRootPath,
        backendRootPath: backendRootPath!,
        miniProgramId: miniProgramId,
        miniProgramRootPath: resolved.isRepoManaged
            ? null
            : resolved.miniProgramRootPath,
        stacCliScriptPath: results.option('stac-cli-script'),
        skipBuildPubGet: results.flag('skip-build-pub-get'),
      ),
    );

    await _stateStore.recordPublishedArtifact(
      backendRootPath,
      PublishedLocalArtifactRecord(
        miniProgramId: result.miniProgramId,
        version: result.version,
        latestManifestPath: result.latestManifestPath,
        versionedManifestPath: result.versionedManifestPath,
        screensDirectoryPath: result.screensDirectoryPath,
        publishedAtUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    _stdout.writeln(_formatPublishResult(result));
    _stdout.writeln(
      'Tracked local publish state: '
      '${_stateStore.publishedArtifactsPath(backendRootPath)}',
    );
    return 0;
  }

  Future<int> _runEmbed(List<String> arguments) async {
    if (arguments.isEmpty) {
      _stderr.writeln(_embedUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEmbedInit(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown embed command: ${arguments.first}');
        _stderr.writeln(_embedUsage());
        return 64;
    }
  }

  Future<int> _runEmbedInit(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'project-root',
        help:
            'Existing Flutter app root containing pubspec.yaml and lib/. Defaults to the current directory.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional platform repo root for generated README snippets.',
      )
      ..addOption(
        'host-app-id',
        help: 'Optional host app identifier. Defaults to the pubspec name.',
      )
      ..addOption(
        'host-version',
        help:
            'Optional host version. Defaults to pubspec version without +build.',
      )
      ..addOption(
        'native-route-path',
        defaultsTo: '/native/profile-editor',
        help: 'Sample native route path used by the generated bridge alias.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite scaffold-managed files if the target already exists.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram embed init [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    final result = await _embeddingInitializer.initialize(
      MiniProgramEmbeddingInitRequest(
        projectRootPath: projectRootPath,
        repoRootPath: await _resolveRepoRootPath(
          explicitRepoRootPath: results.option('repo-root'),
          additionalSearchRoots: <String>[projectRootPath],
        ),
        hostAppId: results.option('host-app-id'),
        hostVersion: results.option('host-version'),
        nativeRoutePath: results.option('native-route-path')!,
        force: results.flag('force'),
      ),
    );

    _stdout.writeln(_formatEmbeddingInitResult(result));
    return 0;
  }

  Future<int> _runEnv(List<String> arguments) async {
    if (arguments.isEmpty) {
      _stderr.writeln(_envUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEnvInit(arguments.sublist(1));
      case 'use':
        return _runEnvUse(arguments.sublist(1));
      case 'status':
        return _runEnvStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown env command: ${arguments.first}');
        _stderr.writeln(_envUsage());
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
        allowed: LocalCliEnvironmentState.supportedEnvironments,
        help: 'Active environment to save. Defaults to local.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram env init [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final cwd = _currentWorkingDirectory();
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
    final state = LocalCliEnvironmentState(
      schemaVersion: 1,
      repoRootPath: repoRootPath,
      activeEnvironment:
          results.option('use') ?? existingState?.activeEnvironment ?? 'local',
      initializedAtUtc: existingState?.initializedAtUtc ?? now,
      updatedAtUtc: now,
    );
    await _stateStore.writeEnvironmentState(configRootPath, state);
    await _stateStore.writeGlobalEnvironmentState(state);
    _stdout.writeln(
      _formatEnvStatusResult(
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
      _stdout.writeln('Usage: miniprogram env use <local|cloud> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1 ||
        !LocalCliEnvironmentState.supportedEnvironments.contains(
          results.rest.single,
        )) {
      throw const FormatException(
        'env use expects exactly one environment: local or cloud.',
      );
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final updatedState = LocalCliEnvironmentState(
      schemaVersion: resolved.state.schemaVersion,
      repoRootPath: resolved.state.repoRootPath,
      activeEnvironment: results.rest.single,
      initializedAtUtc: resolved.state.initializedAtUtc,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }
    _stdout.writeln(
      _formatEnvStatusResult(
        ResolvedLocalCliEnvironmentState(
          rootPath: resolved.rootPath,
          filePath: resolved.filePath,
          state: updatedState,
          scope: resolved.scope,
        ),
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

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    _stdout.writeln(_formatEnvStatusResult(resolved));
    return resolved == null ? 1 : 0;
  }

  Future<int> _runBackend(List<String> arguments) async {
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
    _stdout.writeln(_formatBackendStatusResult(result));
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

  Set<String> _parseCapabilities(String rawCapabilities) => rawCapabilities
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  String _currentWorkingDirectory() =>
      p.normalize(p.absolute(_workingDirectory ?? Directory.current.path));

  String _rootUsage() => '''
Usage: miniprogram <command> [arguments]

Commands:
  create <mini-program-id>
  doctor
  env init
  env use <local|cloud>
  env status
  build [mini-program-id]
  validate [mini-program-id]
  publish [mini-program-id]
  embed init
  backend init
  backend start --port 8080
  backend stop
  backend status
  backend reset-local --yes
''';

  String _embedUsage() => '''
Usage: miniprogram embed <command> [arguments]

Commands:
  init
''';

  String _envUsage() => '''
Usage: miniprogram env <command> [arguments]

Commands:
  init
  use <local|cloud>
  status
''';

  String _backendUsage() => '''
Usage: miniprogram backend <command> [arguments]

Commands:
  init
  start --port 8080
  stop
  status
  reset-local --yes
''';

  String _formatCreateResult(MiniProgramScaffoldResult result) {
    final lines = <String>[
      'Created mini-program scaffold: ${result.miniProgramId}',
      'Root: ${result.miniProgramRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'Capabilities: ${result.capabilities.join(', ')}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatDoctorResult(MiniprogramDoctorResult result) {
    final lines = <String>['Miniprogram doctor report:'];
    var okCount = 0;
    var warningCount = 0;
    var errorCount = 0;
    var skippedCount = 0;

    for (final check in result.checks) {
      switch (check.status) {
        case MiniprogramDoctorCheckStatus.ok:
          okCount++;
        case MiniprogramDoctorCheckStatus.warning:
          warningCount++;
        case MiniprogramDoctorCheckStatus.error:
          errorCount++;
        case MiniprogramDoctorCheckStatus.skipped:
          skippedCount++;
      }
      lines.add('[${check.status.name}] ${check.label}: ${check.summary}');
      if (check.detail case final detail? when detail.trim().isNotEmpty) {
        lines.add('  $detail');
      }
    }

    lines.add(
      'Summary: $okCount ok, $warningCount warning, '
      '$errorCount error, $skippedCount skipped',
    );
    return lines.join('\n');
  }

  String _formatBuildResult(MiniProgramBuildResult result) {
    final lines = <String>[
      'Built mini-program: ${result.miniProgramId}',
      'Root: ${result.miniProgramRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'CLI source: ${result.cliSource}',
      'Command: ${result.invocation.join(' ')}',
      'Output directory: ${result.outputDirectoryPath}',
      'Entry screen JSON: ${result.entryScreenJsonPath}',
      'Ran pub get: ${result.pubGetRan}',
    ];
    return lines.join('\n');
  }

  String _formatPublishResult(MiniProgramPublishResult result) {
    final lines = <String>[
      'Published mini-program: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Backend root: ${result.backendRootPath}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Pre-publish validation: ${result.prePublishValidation.errorCount} error(s), ${result.prePublishValidation.warningCount} warning(s)',
      'Post-publish validation: ${result.postPublishValidation.errorCount} error(s), ${result.postPublishValidation.warningCount} warning(s)',
      'Latest manifest: ${result.latestManifestPath}',
      'Versioned manifest: ${result.versionedManifestPath}',
      'Published screens: ${result.screensDirectoryPath} (${result.copiedScreenCount} file(s))',
    ];
    return lines.join('\n');
  }

  String _formatEmbeddingInitResult(MiniProgramEmbeddingInitResult result) {
    final lines = <String>[
      'Initialized embedded mini-program adapter for: ${result.packageName}',
      'Project root: ${result.projectRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'Host app id: ${result.hostAppId}',
      'Host version: ${result.hostVersion}',
      'Native route path: ${result.nativeRoutePath}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatEnvStatusResult(
    ResolvedLocalCliEnvironmentState? resolved, {
    bool initialized = false,
    bool switched = false,
  }) {
    if (resolved == null) {
      return 'No miniprogram env configuration was found. Run '
          '"miniprogram env init" from your mini-program workspace or repo '
          'root first.';
    }

    final lines = <String>[
      if (initialized)
        'Initialized miniprogram env.'
      else if (switched)
        'Updated active miniprogram environment.'
      else
        'Miniprogram env configuration found.',
      'Config scope: ${resolved.scope}',
      'Config root: ${resolved.rootPath}',
      'Config file: ${resolved.filePath}',
      'Repo root: ${resolved.state.repoRootPath ?? 'not configured'}',
      'Active environment: ${resolved.state.activeEnvironment}',
      'Initialized at UTC: ${resolved.state.initializedAtUtc}',
      'Updated at UTC: ${resolved.state.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatBackendStartResult(LocalBackendStartResult result) {
    final state = result.state;
    final lines = <String>[
      result.alreadyRunning
          ? 'Local backend was already running.'
          : 'Started local backend.',
      'PID: ${state.pid}',
      'Port: ${state.port}',
      'Health URL: ${state.healthCheckUrl}',
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    return lines.join('\n');
  }

  String _formatBackendInitResult(LocalBackendInitResult result) {
    final lines = <String>[
      'Initialized local backend workspace.',
      'Backend root: ${result.backendRootPath}',
      'API root: ${result.apiRootPath}',
      'Service root: ${result.serviceDirectoryPath}',
      'State file: ${result.stateFilePath}',
      'Global fallback: ${result.globalStateFilePath}',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatBackendStatusResult(LocalBackendStatusResult result) {
    if (!result.hasState) {
      return 'Local backend is not running. No backend.local.json state was found.';
    }

    final state = result.state!;
    final lines = <String>[
      'Local backend state found.',
      'PID: ${state.pid}',
      'Port: ${state.port}',
      'Process alive: ${result.processAlive}',
      'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    return lines.join('\n');
  }

  String _formatBackendStopResult(LocalBackendStopResult result) {
    if (!result.hadState) {
      return 'No local backend state was found.';
    }
    if (result.clearedStaleState) {
      return 'Cleared stale local backend state. The recorded process was already gone.';
    }
    if (result.stopped) {
      return 'Stopped the local backend and cleared backend.local.json.';
    }
    return 'Local backend was not running.';
  }

  String _formatBackendResetResult(LocalBackendResetResult result) {
    final lines = <String>[
      'Removed ${result.removedPaths.length} tracked local backend artifact path(s).',
    ];
    if (result.removedPaths.isNotEmpty) {
      lines.addAll(result.removedPaths.map((path) => '- $path'));
    }
    return lines.join('\n');
  }

  Future<ResolvedLocalCliEnvironmentState?> _discoverEnvironmentState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverEnvironmentState(
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalBackendWorkspaceState?> _discoverBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) {
    return _stateStore.discoverBackendWorkspaceState(
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchRoots: additionalSearchRoots,
    );
  }

  Future<ResolvedLocalCliEnvironmentState?> _resolveEnvironmentState({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    if (explicitRootPath != null && explicitRootPath.trim().isNotEmpty) {
      final rootPath = p.normalize(p.absolute(explicitRootPath));
      final state = await _stateStore.readEnvironmentState(rootPath);
      if (state == null) {
        final globalState = await _stateStore.readGlobalEnvironmentState();
        if (globalState == null) {
          return null;
        }
        return ResolvedLocalCliEnvironmentState(
          rootPath: Directory(
            _stateStore.globalStateDirectoryPath(),
          ).parent.path,
          filePath: _stateStore.globalEnvironmentStatePath(),
          state: globalState,
          scope: 'global',
        );
      }
      return ResolvedLocalCliEnvironmentState(
        rootPath: rootPath,
        filePath: _stateStore.environmentStatePath(rootPath),
        state: state,
        scope: 'local',
      );
    }

    return _discoverEnvironmentState(
      additionalSearchRoots: <String>[
        ...additionalSearchRoots,
        if (explicitRepoRootPath != null &&
            explicitRepoRootPath.trim().isNotEmpty)
          explicitRepoRootPath,
      ],
    );
  }

  Future<ResolvedLocalCliEnvironmentState> _requireEnvironmentState({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final resolved = await _resolveEnvironmentState(
      explicitRootPath: explicitRootPath,
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: additionalSearchRoots,
    );
    if (resolved == null) {
      throw const FormatException(
        'No miniprogram env configuration was found. Run '
        '"miniprogram env init" first.',
      );
    }
    return resolved;
  }

  Future<String?> _resolveRepoRootPath({
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    final envState = await _discoverEnvironmentState(
      additionalSearchRoots: <String>[
        ...additionalSearchRoots,
        if (explicitRepoRootPath != null &&
            explicitRepoRootPath.trim().isNotEmpty)
          explicitRepoRootPath,
      ],
    );
    return _pathResolver.resolveRepoRoot(
      explicitRepoRootPath:
          explicitRepoRootPath ?? envState?.state.repoRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
      additionalSearchPath: envState?.state.repoRootPath,
      required: required,
    );
  }

  Future<String?> _resolveBackendRootPath({
    String? explicitRootPath,
    String? explicitRepoRootPath,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool required = false,
  }) async {
    if (explicitRootPath != null && explicitRootPath.trim().isNotEmpty) {
      final normalizedRootPath = p.normalize(p.absolute(explicitRootPath));
      if (await _looksLikeBackendWorkspaceRoot(normalizedRootPath)) {
        return normalizedRootPath;
      }
      throw MiniProgramPathResolutionException(
        'Backend root does not contain backend/local_backend_service and '
        'backend/api: $normalizedRootPath',
      );
    }

    final backendWorkspaceState = await _resolveUsableBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (backendWorkspaceState != null) {
      return backendWorkspaceState.state.backendRootPath;
    }

    final repoRootPath = await _resolveRepoRootPath(
      explicitRepoRootPath: explicitRepoRootPath,
      additionalSearchRoots: additionalSearchRoots,
      required: false,
    );
    if (repoRootPath != null &&
        await _looksLikeBackendWorkspaceRoot(repoRootPath)) {
      return repoRootPath;
    }

    if (required) {
      throw const MiniProgramPathResolutionException(
        'Could not find a backend workspace. Run `miniprogram backend init` '
        'or provide --root / --repo-root.',
      );
    }
    return null;
  }

  Future<ResolvedLocalBackendWorkspaceState?>
  _resolveUsableBackendWorkspaceState({
    Iterable<String> additionalSearchRoots = const <String>[],
  }) async {
    final discovered = await _discoverBackendWorkspaceState(
      additionalSearchRoots: additionalSearchRoots,
    );
    if (discovered != null &&
        await _looksLikeBackendWorkspaceRoot(
          discovered.state.backendRootPath,
        )) {
      return discovered;
    }

    final globalState = await _stateStore.readGlobalBackendWorkspaceState();
    if (globalState != null &&
        await _looksLikeBackendWorkspaceRoot(globalState.backendRootPath)) {
      return ResolvedLocalBackendWorkspaceState(
        rootPath: Directory(_stateStore.globalStateDirectoryPath()).parent.path,
        filePath: _stateStore.globalBackendWorkspaceStatePath(),
        state: globalState,
        scope: 'global',
      );
    }

    return null;
  }

  Future<String> _resolveMiniProgramId({
    required String commandName,
    required List<String> positionalArguments,
    String? explicitMiniProgramRootPath,
  }) async {
    if (positionalArguments.length > 1) {
      throw FormatException(
        '$commandName expects zero or one <mini-program-id> positional argument.',
      );
    }

    if (positionalArguments.length == 1) {
      return positionalArguments.single;
    }

    final inferredMiniProgramId = await _pathResolver.inferMiniProgramId(
      miniProgramRootPath: explicitMiniProgramRootPath,
      currentWorkingDirectory: _currentWorkingDirectory(),
    );
    if (inferredMiniProgramId != null) {
      return inferredMiniProgramId;
    }

    throw FormatException(
      'No <mini-program-id> was provided, and the current directory does not '
      'look like a mini-program root. Run `miniprogram $commandName '
      '<mini-program-id>` or change into the mini-program folder first.',
    );
  }

  Future<bool> _looksLikeBackendWorkspaceRoot(String rootPath) async {
    final normalizedRootPath = p.normalize(p.absolute(rootPath));
    final apiRoot = Directory(p.join(normalizedRootPath, 'backend', 'api'));
    final serverEntrypoint = File(
      p.join(
        normalizedRootPath,
        'backend',
        'local_backend_service',
        'bin',
        'server.dart',
      ),
    );
    return await apiRoot.exists() && await serverEntrypoint.exists();
  }
}
