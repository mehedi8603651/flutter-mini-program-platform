part of '../miniprogram_cli.dart';

extension _MiniprogramCliCoreCommands on MiniprogramCli {
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
        backendTemplate: results.option('with-backend'),
        screenFormat: results.option('screen-format') ?? 'mp',
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
      _stdout.writeln(_prettyJson(_doctorResultJson(result)));
    } else {
      _stdout.writeln(_formatDoctorResult(result));
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

    final capabilities = _capabilitiesJson();
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(capabilities));
    } else {
      _stdout.writeln(_formatCapabilities(capabilities));
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
        mpBuildScriptPath: results.option('mp-build-script'),
        skipPubGet: results.flag('skip-pub-get'),
      ),
    );

    _stdout.writeln(_formatBuildResult(result));
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
      )
      ..addOption(
        'backend-base-url',
        help:
            'Optional Publisher API base URL for backend widgets in preview. Defaults to publisher_backend.json when present.',
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

    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'preview',
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
    final backendBaseUri = await _resolvePreviewBackendBaseUri(
      miniProgramRootPath: resolved.miniProgramRootPath,
      explicitBackendBaseUrl: results.option('backend-base-url'),
    );

    return _previewController.preview(
      MiniProgramPreviewRequest(
        miniProgramId: miniProgramId,
        miniProgramRootPath: resolved.miniProgramRootPath,
        repoRootPath: resolved.repoRootPath,
        deviceId: deviceId,
        mpBuildScriptPath: results.option('mp-build-script'),
        backendBaseUri: backendBaseUri,
      ),
      stdoutSink: _stdout,
      stderrSink: _stderr,
    );
  }

  Future<Uri?> _resolvePreviewBackendBaseUri({
    required String miniProgramRootPath,
    required String? explicitBackendBaseUrl,
  }) async {
    final explicit = explicitBackendBaseUrl?.trim() ?? '';
    if (explicit.isNotEmpty) {
      final uri = Uri.tryParse(explicit);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw FormatException(
          'preview --backend-base-url expected an absolute URL, got: $explicit',
        );
      }
      return uri;
    }

    final contractPath = _publisherBackendContractController
        .defaultContractPath(miniProgramRootPath);
    if (!File(contractPath).existsSync()) {
      return null;
    }

    final contract = await _publisherBackendContractController.readContract(
      contractPath: contractPath,
      allowLocalHttp: true,
    );
    return contract.backendBaseUri;
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
        allowed: _supportedPublishTargets,
        help: 'Publish target. Defaults to the active env or local.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output folder for --target static or firebase-hosting. Firebase Hosting defaults to backend/firebase_hosting/public.',
      )
      ..addFlag(
        'clean',
        negatable: false,
        help:
            'For static or firebase-hosting, remove generated delivery output before writing the new version.',
      )
      ..addOption(
        'env',
        help:
            'Named cloud environment override used by cloud or firebase-hosting targets.',
      )
      ..addOption(
        'site',
        help:
            'Optional Firebase Hosting site id when --target firebase-hosting is selected.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help:
            'For --target firebase-hosting, build static output and firebase.json without deploying.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print machine-readable JSON for --target firebase-hosting.',
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
    final target = _resolvePublishTarget(
      explicitTarget: results.option('target'),
      resolvedEnvironmentState: activeEnvironment,
    );

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
    if (target == 'cloud') {
      final cloudEnvironment = _resolveConfiguredCloudEnvironment(
        state: activeEnvironment?.state,
        explicitEnvironmentName: results.option('env'),
      );
      final result = await _cloudPublisher.publish(
        MiniProgramCloudPublishRequest(
          repoRootPath: resolved.repoRootPath ?? resolved.miniProgramRootPath,
          environment: cloudEnvironment,
          miniProgramId: miniProgramId,
          miniProgramRootPath: resolved.isRepoManaged
              ? null
              : resolved.miniProgramRootPath,
          mpBuildScriptPath: results.option('mp-build-script'),
          skipBuildPubGet: results.flag('skip-build-pub-get'),
        ),
      );
      _stdout.writeln(_formatCloudPublishResult(result));
      return 0;
    }

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
      _stdout.writeln(_formatStaticPublishResult(result));
      return 0;
    }

    if (target == 'firebase-hosting') {
      final environment = _resolveConfiguredCloudEnvironment(
        state: activeEnvironment?.state,
        explicitEnvironmentName: results.option('env'),
      );
      final result = await _firebaseHostingPublisher.publish(
        MiniProgramFirebaseHostingPublishRequest(
          repoRootPath: resolved.repoRootPath ?? resolved.miniProgramRootPath,
          environment: environment,
          miniProgramId: miniProgramId,
          miniProgramRootPath: resolved.miniProgramRootPath,
          outputPath: results.option('output'),
          siteId: results.option('site'),
          mpBuildScriptPath: results.option('mp-build-script'),
          skipBuildPubGet: results.flag('skip-build-pub-get'),
          clean: results.flag('clean'),
          dryRun: results.flag('dry-run'),
        ),
      );
      if (results.flag('json')) {
        _stdout.writeln(_prettyJson(result.toJson()));
      } else {
        _stdout.writeln(_formatFirebaseHostingPublishResult(result));
      }
      return 0;
    }

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

    _stdout.writeln(_formatPublishResult(result));
    _stdout.writeln(
      'Tracked local publish state: '
      '${_stateStore.publishedArtifactsPath(backendRootPath)}',
    );
    return 0;
  }

  Future<int> _runEmbed(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_embedUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_embedUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEmbedInit(arguments.sublist(1));
      case 'cloud':
        return _runEmbedCloud(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown embed command: ${arguments.first}');
        _stderr.writeln(_embedUsage());
        return 64;
    }
  }

  Future<int> _runEmbedCloud(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_embedCloudUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_embedCloudUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'configure':
        return _runEmbedCloudConfigure(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown embed cloud command: ${arguments.first}');
        _stderr.writeln(_embedCloudUsage());
        return 64;
    }
  }

  Future<int> _runEmbedCloudConfigure(List<String> arguments) async {
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
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption(
        'root',
        help:
            'Directory that owns .mini_program/env.json. Defaults to discovery with global fallback.',
      )
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram embed cloud configure [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);

    final resolvedEnvironmentState = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[projectRootPath],
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolvedEnvironmentState.state,
      explicitEnvironmentName: results.option('env'),
    );
    final outputs = await _cloudController.outputs(
      MiniProgramCloudOutputsRequest(
        resolvedEnvironmentState: resolvedEnvironmentState,
        environment: environment,
      ),
    );
    final backendApiBaseUrl = _requireBackendApiBaseUrlFromOutputs(outputs);
    await _persistCloudEnvironmentValueUpdates(
      resolved: resolvedEnvironmentState,
      environmentName: environment.name,
      updatedValues: <String, dynamic>{'apiBaseUrl': backendApiBaseUrl},
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final existingConfiguration = await _stateStore.readHostCloudConfiguration(
      projectRootPath,
    );
    final configuration = EmbeddedHostCloudConfiguration(
      environmentName: environment.name,
      provider: environment.provider,
      backendApiBaseUrl: backendApiBaseUrl,
      configuredAtUtc: existingConfiguration?.configuredAtUtc ?? now,
      updatedAtUtc: now,
    );
    await _stateStore.writeHostCloudConfiguration(
      projectRootPath,
      configuration,
    );

    _stdout.writeln(
      _formatEmbeddedHostCloudConfigurationResult(
        projectRootPath: p.normalize(p.absolute(projectRootPath)),
        configurationPath: _stateStore.hostCloudConfigurationPath(
          projectRootPath,
        ),
        configuration: configuration,
      ),
    );
    return 0;
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
}
