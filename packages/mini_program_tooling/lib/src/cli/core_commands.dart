import 'package:path/path.dart' as p;

import 'support.dart';

extension CliCoreCommands on CliContext {
  StringSink get _stdout => stdoutSink;
  StringSink get _stderr => stderrSink;
  MiniProgramScaffolder get _scaffolder => dependencies.scaffolder;
  MiniProgramBuilder get _builder => dependencies.builder;
  DeliveryRepositoryValidator get _validator => dependencies.validator;
  MiniProgramPublisher get _publisher => dependencies.publisher;
  MiniProgramEmbeddingInitializer get _embeddingInitializer =>
      dependencies.embeddingInitializer;
  MiniProgramPreviewController get _previewController =>
      dependencies.previewController;
  MiniProgramStaticPublisher get _staticPublisher =>
      dependencies.staticPublisher;
  MiniprogramDoctor get _doctor => dependencies.doctor;
  LocalCliStateStore get _stateStore => dependencies.stateStore;
  MiniProgramPathResolver get _pathResolver => dependencies.pathResolver;

  Future<int> runCreateCommand(List<String> arguments) => _runCreate(arguments);
  Future<int> runDoctorCommand(List<String> arguments) => _runDoctor(arguments);
  int runCapabilitiesCommand(List<String> arguments) =>
      _runCapabilities(arguments);
  Future<int> runBuildCommand(List<String> arguments) => _runBuild(arguments);
  Future<int> runPreviewCommand(List<String> arguments) =>
      _runPreview(arguments);
  Future<int> runValidateCommand(List<String> arguments) =>
      _runValidate(arguments);
  Future<int> runPublishCommand(List<String> arguments) =>
      _runPublish(arguments);
  Future<int> runEmbedCommand(List<String> arguments) => _runEmbed(arguments);

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
        defaultsTo: 'analytics',
        help: 'Comma-separated capability wire values.',
      )
      ..addOption(
        'with-backend',
        allowed: const <String>['mock'],
        help:
            'Scaffold an opt-in Publisher API mock starter. Currently supports: mock.',
      )
      ..addOption(
        'screen-format',
        allowed: const <String>['mp'],
        defaultsTo: 'mp',
        help:
            'Screen authoring format for the scaffold. Mp is the only supported format.',
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
            ? p.join(currentWorkingDirectory(), miniProgramId)
            : null);

    final result = await _scaffolder.scaffold(
      MiniProgramScaffoldRequest(
        repoRootPath: repoRootPath,
        outputRootPath: outputRootPath,
        miniProgramId: miniProgramId,
        title: results.option('title'),
        description: results.option('description'),
        capabilities: parseCapabilities(results.option('capabilities')!),
        backendTemplate: results.option('with-backend'),
        screenFormat: results.option('screen-format') ?? 'mp',
        force: results.flag('force'),
      ),
    );

    _stdout.writeln(formatCreateResult(result));
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
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');

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
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(doctorResultJson(result)));
    } else {
      _stdout.writeln(formatDoctorResult(result));
    }
    return result.hasErrors ? 1 : 0;
  }

  int _runCapabilities(List<String> arguments) {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram capabilities [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'capabilities does not accept positional arguments.',
      );
    }

    final capabilities = capabilitiesJson();
    if (results.flag('json')) {
      _stdout.writeln(prettyJson(capabilities));
    } else {
      _stdout.writeln(formatCapabilities(capabilities));
    }
    return 0;
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
        help: 'Optional repo root used for mini-program discovery.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'mp-build-script',
        help: 'Optional explicit path to tool/build_mp.dart for Mp projects.',
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
    final miniProgramId = await resolveMiniProgramId(
      commandName: 'build',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final cwd = currentWorkingDirectory();
    final repoRootHint = await resolveRepoRootPath(
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
        mpBuildScriptPath: results.option('mp-build-script'),
        skipPubGet: results.flag('skip-pub-get'),
      ),
    );

    _stdout.writeln(formatBuildResult(result));
    return 0;
  }

  Future<int> _runPreview(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'device',
        abbr: 'd',
        help:
            'Preview device id. Supports chrome, edge, ios, linux, macos, windows, Android emulator ids like emulator-5554, Android USB device ids like R58M123ABC, and Android Wi-Fi device ids like 192.168.1.25:5555.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used for local preview host dependencies.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'mp-build-script',
        help: 'Optional explicit path to tool/build_mp.dart for Mp projects.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }

    final deviceId = results.option('device')?.trim() ?? '';
    if (deviceId.isEmpty) {
      throw const FormatException(
        'preview requires -d <device>. Supported targets include chrome, edge, ios, linux, macos, windows, Android emulator ids like emulator-5554, Android USB device ids like R58M123ABC, and Android Wi-Fi device ids like 192.168.1.25:5555.',
      );
    }

    final miniProgramId = await resolveMiniProgramId(
      commandName: 'preview',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final repoRootHint = await resolveRepoRootPath(
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
      currentWorkingDirectory: currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    return _previewController.preview(
      MiniProgramPreviewRequest(
        miniProgramId: miniProgramId,
        miniProgramRootPath: resolved.miniProgramRootPath,
        repoRootPath: resolved.repoRootPath,
        deviceId: deviceId,
        mpBuildScriptPath: results.option('mp-build-script'),
      ),
      stdoutSink: _stdout,
      stderrSink: _stderr,
    );
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
        help:
            'Platform repo root containing static artifacts under backend/api/.',
      )
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
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
    final miniProgramId = await resolveMiniProgramId(
      commandName: 'validate',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final repoRootHint = await resolveRepoRootPath(
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
      currentWorkingDirectory: currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    final backendRootPath = await resolveBackendRootPath(
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
        help:
            'Platform repo root containing static artifacts under backend/api/.',
      )
      ..addOption(
        'root',
        help:
            'Local artifact host workspace root. Defaults to a discovered artifact-host init workspace or platform repo root.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      )
      ..addOption(
        'mp-build-script',
        help: 'Optional explicit path to tool/build_mp.dart for Mp projects.',
      )
      ..addFlag(
        'skip-build-pub-get',
        negatable: false,
        help: 'Skip dart pub get inside the mini-program package during build.',
      )
      ..addOption(
        'target',
        allowed: cliSupportedPublishTargets,
        help: 'Publish target. Defaults to the active env or local.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output folder for --target static.',
      )
      ..addFlag(
        'clean',
        negatable: false,
        help: 'For static, remove generated delivery output first.',
      );

    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram publish [mini-program-id] [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    final activeEnvironment = await discoverEnvironmentState(
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
    );
    final target = resolvePublishTarget(
      explicitTarget: results.option('target'),
      resolvedEnvironmentState: activeEnvironment,
    );

    final miniProgramId = await resolveMiniProgramId(
      commandName: 'publish',
      positionalArguments: results.rest,
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final repoRootHint = await resolveRepoRootPath(
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
      currentWorkingDirectory: currentWorkingDirectory(),
      requireRepoRoot: false,
    );
    if (target == 'static') {
      final outputPath = results.option('output')?.trim() ?? '';
      if (outputPath.isEmpty) {
        throw const FormatException(
          'publish --target static requires --output <folder>.',
        );
      }
      final result = await _staticPublisher.publish(
        MiniProgramStaticPublishRequest(
          repoRootPath: resolved.repoRootPath ?? resolved.miniProgramRootPath,
          outputPath: outputPath,
          miniProgramId: miniProgramId,
          miniProgramRootPath: resolved.isRepoManaged
              ? null
              : resolved.miniProgramRootPath,
          mpBuildScriptPath: results.option('mp-build-script'),
          skipBuildPubGet: results.flag('skip-build-pub-get'),
          clean: results.flag('clean'),
        ),
      );
      _stdout.writeln(formatStaticPublishResult(result));
      return 0;
    }

    final backendRootPath = await resolveBackendRootPath(
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
        mpBuildScriptPath: results.option('mp-build-script'),
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

    _stdout.writeln(formatPublishResult(result));
    _stdout.writeln(
      'Tracked local publish state: '
      '${_stateStore.publishedArtifactsPath(backendRootPath)}',
    );
    return 0;
  }

  Future<int> _runEmbed(List<String> arguments) async {
    if (isGroupHelpRequest(arguments)) {
      _stdout.writeln(embedUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(embedUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEmbedInit(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown embed command: ${arguments.first}');
        _stderr.writeln(embedUsage());
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
        hide: true,
        help:
            'Deprecated compatibility option. Generated lean adapters no longer create route aliases.',
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
        results.option('project-root') ?? currentWorkingDirectory();
    final result = await _embeddingInitializer.initialize(
      MiniProgramEmbeddingInitRequest(
        projectRootPath: projectRootPath,
        repoRootPath: await resolveRepoRootPath(
          explicitRepoRootPath: results.option('repo-root'),
          additionalSearchRoots: <String>[projectRootPath],
        ),
        hostAppId: results.option('host-app-id'),
        hostVersion: results.option('host-version'),
        nativeRoutePath: results.option('native-route-path')!,
        force: results.flag('force'),
      ),
    );

    _stdout.writeln(formatEmbeddingInitResult(result));
    return 0;
  }
}
