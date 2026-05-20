import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'mini_program_cloud_publisher.dart';
import 'mini_program_cloud_controller.dart';
import 'delivery_validation.dart';
import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_backend_initializer.dart';
import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_host_controller.dart';
import 'miniprogram_doctor.dart';
import 'mini_program_embedding_initializer.dart';
import 'mini_program_path_resolver.dart';
import 'mini_program_partner_handoff.dart';
import 'mini_program_preview_controller.dart';
import 'mini_program_preview_server.dart';
import 'mini_program_publisher.dart';
import 'mini_program_scaffolder.dart';
import 'mini_program_static_publisher.dart';
import 'mini_program_workflow_status.dart';

const List<String> _supportedPublishTargets = <String>[
  'local',
  'cloud',
  'static',
];

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
    MiniProgramPreviewController previewController =
        const MiniProgramPreviewController(),
    MiniProgramCloudPublisher cloudPublisher =
        const MiniProgramCloudPublisher(),
    MiniProgramStaticPublisher staticPublisher =
        const MiniProgramStaticPublisher(),
    MiniProgramCloudController? cloudController,
    MiniProgramHostController? hostController,
    MiniProgramPartnerHandoffController partnerHandoffController =
        const MiniProgramPartnerHandoffController(),
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
       _previewController = previewController,
       _cloudPublisher = cloudPublisher,
       _staticPublisher = staticPublisher,
       _cloudController = cloudController ?? MiniProgramCloudController(),
       _hostController = hostController ?? MiniProgramHostController(),
       _partnerHandoffController = partnerHandoffController,
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
  final MiniProgramPreviewController _previewController;
  final MiniProgramCloudPublisher _cloudPublisher;
  final MiniProgramStaticPublisher _staticPublisher;
  final MiniProgramCloudController _cloudController;
  final MiniProgramHostController _hostController;
  final MiniProgramPartnerHandoffController _partnerHandoffController;
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
        case 'preview':
          return await _runPreview(arguments.sublist(1));
        case 'validate':
          return await _runValidate(arguments.sublist(1));
        case 'publish':
          return await _runPublish(arguments.sublist(1));
        case 'access-key':
          return await _runAccessKey(arguments.sublist(1));
        case 'cloud':
          return await _runCloud(arguments.sublist(1));
        case 'workflow':
          return await _runWorkflow(arguments.sublist(1));
        case 'partner':
          return await _runPartner(arguments.sublist(1));
        case 'host':
          return await _runHost(arguments.sublist(1));
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
    } on MiniProgramPreviewException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPublishException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramCloudException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramHostException catch (error) {
      _stderr.writeln(error.message);
      return 1;
    } on MiniProgramPartnerHandoffException catch (error) {
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
        defaultsTo: 'analytics',
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
        'stac-cli-script',
        help: 'Optional explicit path to bin/stac_cli.dart.',
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

    return _previewController.preview(
      MiniProgramPreviewRequest(
        miniProgramId: miniProgramId,
        miniProgramRootPath: resolved.miniProgramRootPath,
        repoRootPath: resolved.repoRootPath,
        deviceId: deviceId,
        stacCliScriptPath: results.option('stac-cli-script'),
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
        allowed: _supportedPublishTargets,
        help: 'Publish target. Defaults to the active env or local.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output folder when --target static is selected, for example public_mini_program.',
      )
      ..addFlag(
        'clean',
        negatable: false,
        help:
            'When --target static is selected, remove generated static delivery output before writing the new version.',
      )
      ..addOption(
        'env',
        help:
            'Named cloud environment override used when --target cloud is selected.',
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
          stacCliScriptPath: results.option('stac-cli-script'),
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
          stacCliScriptPath: results.option('stac-cli-script'),
          skipBuildPubGet: results.flag('skip-build-pub-get'),
          clean: results.flag('clean'),
        ),
      );
      _stdout.writeln(_formatStaticPublishResult(result));
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

  Future<int> _runAccessKey(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_accessKeyUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_accessKeyUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'create':
        return _runAccessKeyCreate(arguments.sublist(1));
      case 'list':
        return _runAccessKeyList(arguments.sublist(1));
      case 'revoke':
        return _runAccessKeyRevoke(arguments.sublist(1));
      case 'rotate':
        return _runAccessKeyRotate(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown access-key command: ${arguments.first}');
        _stderr.writeln(_accessKeyUsage());
        return 64;
    }
  }

  Future<int> _runCloud(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_cloudUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_cloudUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'deploy':
        return _runCloudDeploy(arguments.sublist(1));
      case 'status':
        return _runCloudStatus(arguments.sublist(1));
      case 'outputs':
        return _runCloudOutputs(arguments.sublist(1));
      case 'logs':
        return _runCloudLogs(arguments.sublist(1));
      case 'destroy':
        return _runCloudDestroy(arguments.sublist(1));
      case 'doctor':
        return _runCloudDoctor(arguments.sublist(1));
      case 'rollback':
        return _runCloudRollback(arguments.sublist(1));
      case 'app':
        return _runCloudApp(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown cloud command: ${arguments.first}');
        _stderr.writeln(_cloudUsage());
        return 64;
    }
  }

  Future<int> _runCloudApp(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_cloudAppUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_cloudAppUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'list':
        return _runCloudAppList(arguments.sublist(1));
      case 'info':
        return _runCloudAppInfo(arguments.sublist(1));
      case 'disable':
        return _runCloudAppDisable(arguments.sublist(1));
      case 'delete':
        return _runCloudAppDelete(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown cloud app command: ${arguments.first}');
        _stderr.writeln(_cloudAppUsage());
        return 64;
    }
  }

  Future<int> _runWorkflow(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_workflowUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_workflowUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'status':
        return _runWorkflowStatus(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown workflow command: ${arguments.first}');
        _stderr.writeln(_workflowUsage());
        return 64;
    }
  }

  Future<int> _runPartner(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_partnerUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_partnerUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'package':
        return _runPartnerPackage(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown partner command: ${arguments.first}');
        _stderr.writeln(_partnerUsage());
        return 64;
    }
  }

  Future<int> _runHost(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_hostUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_hostUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'run':
        return _runHostRun(arguments.sublist(1));
      case 'endpoint':
        return _runHostEndpoint(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host command: ${arguments.first}');
        _stderr.writeln(_hostUsage());
        return 64;
    }
  }

  Future<int> _runHostEndpoint(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_hostEndpointUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_hostEndpointUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'add':
        return _runHostEndpointAdd(arguments.sublist(1));
      case 'import':
        return _runHostEndpointImport(arguments.sublist(1));
      default:
        _stderr.writeln('Unknown host endpoint command: ${arguments.first}');
        _stderr.writeln(_hostEndpointUsage());
        return 64;
    }
  }

  Future<int> _runCloudDeploy(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud deploy [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.deploy(
      MiniProgramCloudDeployRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    await _persistCloudEnvironmentValueUpdates(
      resolved: resolved,
      environmentName: environment.name,
      updatedValues: <String, dynamic>{
        'stackName': result.stackName,
        'stageName': result.stageName,
        if (result.apiBaseUrl != null) 'apiBaseUrl': result.apiBaseUrl,
      },
    );
    _stdout.writeln(_formatCloudDeployResult(result));
    return result.healthy == false ? 1 : 0;
  }

  Future<int> _runCloudStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.status(
      MiniProgramCloudStatusRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(miniProgramWorkflowStatusCloudJson(result)));
    } else {
      _stdout.writeln(_formatCloudStatusResult(result));
    }
    return !result.stackExists || result.healthy == false ? 1 : 0;
  }

  Future<int> _runCloudOutputs(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption(
        'format',
        allowed: const <String>['text', 'dart-define'],
        defaultsTo: 'text',
        help:
            'Output format. Use dart-define for a direct flutter run snippet.',
      )
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud outputs [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.outputs(
      MiniProgramCloudOutputsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(
      _formatCloudOutputsResult(
        result,
        format: results.option('format') ?? 'text',
      ),
    );
    return 0;
  }

  Future<int> _runCloudLogs(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      )
      ..addOption(
        'since',
        defaultsTo: '1h',
        help: 'AWS logs tail window such as 10m, 1h, or 1d.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud logs [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.logs(
      MiniProgramCloudLogsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        since: results.option('since') ?? '1h',
      ),
    );
    _stdout.writeln(_formatCloudLogsResult(result));
    return 0;
  }

  Future<int> _runCloudDestroy(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud destroy [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.destroy(
      MiniProgramCloudDestroyRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudDestroyResult(result));
    return 0;
  }

  Future<int> _runCloudDoctor(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud doctor [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.doctor(
      MiniProgramCloudDoctorRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudDoctorResult(result));
    return result.hasErrors ? 1 : 0;
  }

  Future<int> _runCloudRollback(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('env', help: 'Named cloud environment override.')
      ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
      ..addOption(
        'repo-root',
        help: 'Optional repo root used to locate an existing env.json.',
      )
      ..addOption(
        'mini-program-root',
        help: 'Optional exact mini-program root path.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud rollback <version> [mini-program-id] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isEmpty || results.rest.length > 2) {
      throw const FormatException(
        'cloud rollback expects <version> and an optional [mini-program-id].',
      );
    }

    final version = results.rest.first;
    final miniProgramId = await _resolveMiniProgramId(
      commandName: 'cloud rollback',
      positionalArguments: results.rest.length == 2
          ? <String>[results.rest[1]]
          : const <String>[],
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[
        if (results.option('mini-program-root') case final miniProgramRoot?
            when miniProgramRoot.trim().isNotEmpty)
          miniProgramRoot,
      ],
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.rollback(
      MiniProgramCloudRollbackRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: miniProgramId,
        version: version,
      ),
    );
    _stdout.writeln(_formatCloudRollbackResult(result));
    return 0;
  }

  Future<int> _runAccessKeyCreate(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Stable label for this partner key.')
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key create <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key create expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key create requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.createAccessKey(
      MiniProgramAccessKeyCreateRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
        accessKey: results.option('key'),
      ),
    );
    _stdout.writeln(_formatAccessKeyCreateResult(result));
    return 0;
  }

  Future<int> _runAccessKeyList(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key list <mini-program-id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key list expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.listAccessKeys(
      MiniProgramAccessKeyListRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(miniProgramWorkflowStatusAccessKeyListJson(result)),
      );
    } else {
      _stdout.writeln(_formatAccessKeyListResult(result));
    }
    return 0;
  }

  Future<int> _runAccessKeyRevoke(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Access key id to revoke.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key revoke <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key revoke expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key revoke requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.revokeAccessKey(
      MiniProgramAccessKeyRevokeRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
      ),
    );
    _stdout.writeln(_formatAccessKeyRevokeResult(result));
    return 0;
  }

  Future<int> _runAccessKeyRotate(List<String> arguments) async {
    final parser = _accessKeyParser()
      ..addOption('key-id', help: 'Access key id to revoke.')
      ..addOption('new-key-id', help: 'Optional id for the new key.')
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram access-key rotate <mini-program-id> --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'access-key rotate expects exactly one <mini-program-id>.',
      );
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException('access-key rotate requires --key-id <id>.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.rotateAccessKey(
      MiniProgramAccessKeyRotateRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        keyId: keyId,
        newKeyId: results.option('new-key-id'),
        accessKey: results.option('key'),
      ),
    );
    _stdout.writeln(_formatAccessKeyRotateResult(result));
    return 0;
  }

  Future<int> _runCloudAppList(List<String> arguments) async {
    final parser = _cloudAppParser();
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram cloud app list [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException('cloud app list does not accept arguments.');
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.listApps(
      MiniProgramCloudAppListRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    _stdout.writeln(_formatCloudAppListResult(result));
    return 0;
  }

  Future<int> _runCloudAppInfo(List<String> arguments) async {
    final parser = _cloudAppParser();
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app info <mini-program-id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app info expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.appInfo(
      MiniProgramCloudAppInfoRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
      ),
    );
    _stdout.writeln(_formatCloudAppInfoResult(result));
    return 0;
  }

  Future<int> _runCloudAppDisable(List<String> arguments) async {
    final parser = _cloudAppParser()
      ..addFlag(
        'yes',
        negatable: false,
        help:
            'Actually disable the app. Without this, the command is a dry run.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app disable <mini-program-id> [--yes] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app disable expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.disableApp(
      MiniProgramCloudAppDisableRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        confirmed: results.flag('yes'),
      ),
    );
    _stdout.writeln(_formatCloudAppDisableResult(result));
    return 0;
  }

  Future<int> _runCloudAppDelete(List<String> arguments) async {
    final parser = _cloudAppParser()
      ..addFlag(
        'yes',
        negatable: false,
        help:
            'Actually delete objects. Without this, the command is a dry run.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram cloud app delete <mini-program-id> [--yes] [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'cloud app delete expects exactly one <mini-program-id>.',
      );
    }
    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolved.state,
      explicitEnvironmentName: results.option('env'),
    );
    final result = await _cloudController.deleteApp(
      MiniProgramCloudAppDeleteRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
        miniProgramId: results.rest.single,
        confirmed: results.flag('yes'),
      ),
    );
    _stdout.writeln(_formatCloudAppDeleteResult(result));
    return 0;
  }

  Future<int> _runPartnerPackage(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addOption(
        'title',
        help:
            'Human-readable mini-program title. Defaults to a title derived from the appId.',
      )
      ..addOption(
        'api-base-url',
        help:
            'Mini-program delivery API base URL. If omitted, the active cloud environment output is used.',
      )
      ..addOption(
        'access-key',
        help: 'MiniProgram access key issued for the host company or partner.',
      )
      ..addFlag(
        'public',
        negatable: false,
        help:
            'Create a public/static partner package without a MiniProgram access key.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output JSON package path. Defaults to ./<mini-program-id>.partner.json.',
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
      _stdout.writeln(
        'Usage: miniprogram partner package <mini-program-id> (--access-key <key>|--public) [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'partner package expects exactly one <mini-program-id>.',
      );
    }

    final appId = results.rest.single.trim();
    final accessKey = results.option('access-key')?.trim() ?? '';
    final isPublic = results.flag('public');
    if (accessKey.isEmpty && !isPublic) {
      throw const FormatException(
        'partner package requires --access-key <key> or --public.',
      );
    }
    if (accessKey.isNotEmpty && isPublic) {
      throw const FormatException(
        'partner package cannot use both --access-key and --public.',
      );
    }
    final apiBaseUrl = await _resolvePartnerPackageApiBaseUrl(
      explicitApiBaseUrl: results.option('api-base-url'),
      explicitEnvironmentName: results.option('env'),
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final result = await _partnerHandoffController.createPackage(
      MiniProgramPartnerPackageRequest(
        appId: appId,
        title: results.option('title')?.trim().isNotEmpty == true
            ? results.option('title')!.trim()
            : _defaultTitleForAppId(appId),
        apiBaseUri: Uri.parse(apiBaseUrl),
        accessKey: isPublic ? null : accessKey,
        outputPath: results.option('output'),
      ),
    );
    _stdout.writeln(_formatPartnerPackageResult(result));
    return 0;
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
      )
      ..addFlag(
        'with-demo',
        negatable: false,
        help:
            'Add a public GitHub/jsDelivr demo endpoint, registry entry, and README button snippet.',
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
        withDemo: results.flag('with-demo'),
      ),
    );

    _stdout.writeln(_formatEmbeddingInitResult(result));
    return 0;
  }

  Future<int> _runHostRun(List<String> arguments) async {
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
        help: 'Flutter device id such as chrome, windows, or emulator-5554.',
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
      _stdout.writeln('Usage: miniprogram host run -d <device> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }

    final deviceId = results.option('device')?.trim() ?? '';
    if (deviceId.isEmpty) {
      throw const FormatException('host run requires -d <device>.');
    }

    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    final hostConfiguration = await _stateStore.readHostCloudConfiguration(
      projectRootPath,
    );
    final resolvedEnvironmentState = await _resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
      additionalSearchRoots: <String>[projectRootPath],
    );
    final environment = _resolveCloudEnvironmentForHostRun(
      resolvedEnvironmentState: resolvedEnvironmentState,
      explicitEnvironmentName: results.option('env'),
      hostConfiguration: hostConfiguration,
    );
    final backendApiBaseUrl = await _resolveHostBackendApiBaseUrl(
      projectRootPath: projectRootPath,
      resolvedEnvironmentState: resolvedEnvironmentState,
      environment: environment,
      hostConfiguration: hostConfiguration,
    );

    _stdout.writeln(
      _formatHostRunStart(
        projectRootPath: p.normalize(p.absolute(projectRootPath)),
        deviceId: deviceId,
        environmentName: environment?.name,
        backendApiBaseUrl: backendApiBaseUrl,
      ),
    );
    final result = await _hostController.run(
      MiniProgramHostRunRequest(
        projectRootPath: projectRootPath,
        deviceId: deviceId,
        backendApiBaseUrl: backendApiBaseUrl,
      ),
    );
    return result.exitCode;
  }

  Future<int> _runHostEndpointAdd(List<String> arguments) async {
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
        'api-base-url',
        help:
            'Mini-program delivery API base URL, for example https://api.example.com/prod/api/.',
      )
      ..addOption(
        'title',
        help:
            'Display title to write into mini_program_registry.dart. Defaults to a title-cased appId.',
      )
      ..addOption(
        'access-key',
        help: 'MiniProgram access key issued for this host app or partner.',
      )
      ..addFlag(
        'public',
        negatable: false,
        help:
            'Register a public/static endpoint that does not use a MiniProgram access key.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an unrecognized generated endpoint file.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram host endpoint add <mini-program-id> --title <title> --api-base-url <url> (--access-key <key>|--public) [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'host endpoint add expects exactly one <mini-program-id>.',
      );
    }
    final rawApiBaseUrl = results.option('api-base-url')?.trim() ?? '';
    if (rawApiBaseUrl.isEmpty) {
      throw const FormatException(
        'host endpoint add requires --api-base-url <url>.',
      );
    }
    final apiBaseUri = Uri.tryParse(rawApiBaseUrl);
    if (apiBaseUri == null ||
        !apiBaseUri.hasScheme ||
        apiBaseUri.host.isEmpty) {
      throw FormatException(
        'host endpoint add expected an absolute --api-base-url, got: '
        '$rawApiBaseUrl',
      );
    }
    final accessKey = results.option('access-key')?.trim() ?? '';
    final isPublic = results.flag('public');
    if (accessKey.isEmpty && !isPublic) {
      throw const FormatException(
        'host endpoint add requires --access-key <key> or --public.',
      );
    }
    if (accessKey.isNotEmpty && isPublic) {
      throw const FormatException(
        'host endpoint add cannot use both --access-key and --public.',
      );
    }

    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: results.rest.single,
        title: results.option('title'),
        apiBaseUri: apiBaseUri,
        accessKey: isPublic ? null : accessKey,
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(_formatHostEndpointAddResult(result));
    return 0;
  }

  Future<int> _runHostEndpointImport(List<String> arguments) async {
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
      ..addFlag(
        'force',
        negatable: false,
        help: 'Replace an unrecognized generated endpoint file.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram host endpoint import <partner-package.json> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'host endpoint import expects exactly one <partner-package.json>.',
      );
    }

    final packagePath = results.rest.single;
    final handoff = await _partnerHandoffController.readPackage(packagePath);
    final projectRootPath =
        results.option('project-root') ?? _currentWorkingDirectory();
    await _requireEmbeddedHostProject(projectRootPath);
    final result = await _hostController.addEndpoint(
      MiniProgramHostEndpointAddRequest(
        projectRootPath: projectRootPath,
        appId: handoff.appId,
        title: handoff.title,
        apiBaseUri: handoff.apiBaseUri,
        accessKey: handoff.accessKey,
        force: results.flag('force'),
      ),
    );
    _stdout.writeln(
      _formatHostEndpointImportResult(
        packagePath: p.normalize(p.absolute(packagePath)),
        handoff: handoff,
        endpointResult: result,
      ),
    );
    return 0;
  }

  Future<int> _runWorkflowStatus(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'remote',
        negatable: false,
        help: 'Check remote cloud/app/access-key status when configured.',
      )
      ..addOption(
        'workspace',
        help:
            'Mini-program or Flutter host app workspace. Defaults to the current directory.',
      )
      ..addOption('env', help: 'Named cloud environment override.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln('Usage: miniprogram workflow status [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'workflow status does not accept positional arguments.',
      );
    }

    final controller = MiniProgramWorkflowStatusController(
      stateStore: _stateStore,
      validator: _validator,
      backendController: _backendController,
      cloudController: _cloudController,
    );
    final result = await controller.inspect(
      MiniProgramWorkflowStatusRequest(
        workspacePath:
            results.option('workspace') ?? _currentWorkingDirectory(),
        environmentName: results.option('env'),
        remote: results.flag('remote'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(result.json));
    } else {
      _stdout.writeln(_formatWorkflowStatusResult(result));
    }
    return 0;
  }

  Future<int> _runEnv(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_envUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_envUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'init':
        return _runEnvInit(arguments.sublist(1));
      case 'configure':
        return _runEnvConfigure(arguments.sublist(1));
      case 'list':
        return _runEnvList(arguments.sublist(1));
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
    final configuredCloudEnvironments =
        existingState?.cloudEnvironments ??
        const <CloudEnvironmentConfiguration>[];
    final requestedActiveEnvironment =
        results.option('use')?.trim() ??
        existingState?.activeEnvironment ??
        'local';
    final activeEnvironment = _validateSelectedEnvironmentName(
      requestedActiveEnvironment,
      configuredCloudEnvironments,
      allowLegacyCloudAlias: true,
    );
    final state = LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: repoRootPath,
      activeEnvironment: activeEnvironment,
      cloudEnvironments: configuredCloudEnvironments,
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

  Future<int> _runEnvConfigure(List<String> arguments) async {
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
      )
      ..addOption(
        'provider',
        allowed: CloudEnvironmentConfiguration.supportedProviders,
        help: 'Cloud provider for this named environment.',
      )
      ..addOption('bucket', help: 'AWS S3 bucket name for cloud artifacts.')
      ..addOption(
        'region',
        help: 'AWS region for the S3 bucket and related services.',
      )
      ..addOption(
        'artifacts-prefix',
        defaultsTo: 'artifacts',
        help: 'Object prefix for immutable release artifacts.',
      )
      ..addOption(
        'metadata-prefix',
        defaultsTo: 'metadata',
        help: 'Object prefix for mutable and release metadata records.',
      )
      ..addOption(
        'cloudfront-base-url',
        help:
            'Optional CloudFront base URL used to derive public artifact URLs.',
      )
      ..addOption(
        'api-base-url',
        help: 'Optional API Gateway base URL for discovery and secure routes.',
      )
      ..addOption(
        'aws-profile',
        help: 'Optional AWS CLI profile used for cloud publish commands.',
      )
      ..addOption(
        'stack-name',
        help: 'Optional CloudFormation stack name for AWS cloud deploy.',
      )
      ..addOption(
        'stage-name',
        help: 'Optional API Gateway stage name. Defaults to prod.',
      )
      ..addOption(
        'sam-s3-bucket',
        help:
            'Optional S3 bucket used by sam deploy for packaging. Defaults to the artifact bucket.',
      )
      ..addOption(
        'function-timeout-seconds',
        help: 'Optional Lambda timeout in seconds. Defaults to 15.',
      )
      ..addOption(
        'function-memory-size',
        help: 'Optional Lambda memory size in MB. Defaults to 256.',
      )
      ..addOption(
        'log-level',
        help: 'Optional Lambda log level. Defaults to INFO.',
      )
      ..addFlag(
        'require-access-keys',
        negatable: true,
        defaultsTo: false,
        help:
            'Require AWS delivery routes to validate MiniProgram access keys.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram env configure <env-name> --provider <provider> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'env configure expects exactly one <env-name> positional argument.',
      );
    }

    final environmentName = _validateEnvironmentName(results.rest.single);
    final provider = results.option('provider')?.trim() ?? '';
    if (provider.isEmpty) {
      throw const FormatException(
        'env configure requires --provider <provider>.',
      );
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (environmentName == 'local') {
      throw const FormatException('The environment name "local" is reserved.');
    }

    if (provider != 'aws') {
      throw MiniProgramPublishException(
        'Provider "$provider" is not implemented yet. This phase currently '
        'supports aws only.',
      );
    }

    final values = _buildAwsEnvironmentValues(results);
    final now = DateTime.now().toUtc().toIso8601String();
    final existingEnvironment = resolved.state.cloudEnvironmentNamed(
      environmentName,
    );
    final updatedEnvironment = CloudEnvironmentConfiguration(
      name: environmentName,
      provider: provider,
      values: values,
      configuredAtUtc: existingEnvironment?.configuredAtUtc ?? now,
      updatedAtUtc: now,
    );
    final updatedCloudEnvironments =
        resolved.state.cloudEnvironments
            .where((environment) => environment.name != environmentName)
            .toList()
          ..add(updatedEnvironment);
    updatedCloudEnvironments.sort((a, b) => a.name.compareTo(b.name));

    final updatedState = resolved.state.copyWith(
      schemaVersion: 2,
      cloudEnvironments: updatedCloudEnvironments,
      updatedAtUtc: now,
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }

    _stdout.writeln(
      _formatEnvConfigureResult(
        updatedEnvironment,
        resolved.copyWithState(updatedState),
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

    final resolved = await _resolveEnvironmentState(
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

    _stdout.writeln(_formatEnvListResult(resolved));
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
      _stdout.writeln('Usage: miniprogram env use <local|env-name> [options]');
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.rest.length != 1) {
      throw const FormatException(
        'env use expects exactly one environment: local or a configured env name.',
      );
    }

    final resolved = await _requireEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    final selectedEnvironment = _validateSelectedEnvironmentName(
      results.rest.single,
      resolved.state.cloudEnvironments,
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
      _formatEnvStatusResult(
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

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: results.option('root'),
      explicitRepoRootPath: results.option('repo-root'),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_envStatusJson(resolved)));
    } else {
      _stdout.writeln(_formatEnvStatusResult(resolved));
    }
    return resolved == null ? 1 : 0;
  }

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

  Set<String> _parseCapabilities(String rawCapabilities) => rawCapabilities
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  Map<String, dynamic> _buildAwsEnvironmentValues(ArgResults results) {
    String requiredOption(String name) {
      final value = results.option(name)?.trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('env configure --provider aws requires --$name.');
      }
      return value;
    }

    final values = <String, dynamic>{
      'bucket': requiredOption('bucket'),
      'region': requiredOption('region'),
      'artifactsPrefix': _normalizeEnvironmentPathPrefix(
        results.option('artifacts-prefix') ?? 'artifacts',
      ),
      'metadataPrefix': _normalizeEnvironmentPathPrefix(
        results.option('metadata-prefix') ?? 'metadata',
      ),
    };

    if (results.option('cloudfront-base-url') case final value?
        when value.trim().isNotEmpty) {
      values['cloudFrontBaseUrl'] = _normalizeAbsoluteUrl(value);
    }
    if (results.option('api-base-url') case final value?
        when value.trim().isNotEmpty) {
      values['apiBaseUrl'] = _normalizeAbsoluteUrl(value);
    }
    if (results.option('aws-profile') case final value?
        when value.trim().isNotEmpty) {
      values['awsProfile'] = value.trim();
    }
    if (results.option('stack-name') case final value?
        when value.trim().isNotEmpty) {
      values['stackName'] = _validateEnvironmentName(value);
    }
    if (results.option('stage-name') case final value?
        when value.trim().isNotEmpty) {
      values['stageName'] = _validateEnvironmentName(value);
    }
    if (results.option('sam-s3-bucket') case final value?
        when value.trim().isNotEmpty) {
      values['samS3Bucket'] = value.trim();
    }
    if (results.option('function-timeout-seconds') case final value?
        when value.trim().isNotEmpty) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 3 || parsed > 30) {
        throw const FormatException(
          '--function-timeout-seconds must be an integer from 3 to 30.',
        );
      }
      values['functionTimeoutSeconds'] = parsed;
    }
    if (results.option('function-memory-size') case final value?
        when value.trim().isNotEmpty) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null ||
          !const <int>[128, 256, 512, 1024].contains(parsed)) {
        throw const FormatException(
          '--function-memory-size must be one of 128, 256, 512, or 1024.',
        );
      }
      values['functionMemorySize'] = parsed;
    }
    if (results.option('log-level') case final value?
        when value.trim().isNotEmpty) {
      final normalized = value.trim().toUpperCase();
      if (!const <String>[
        'DEBUG',
        'INFO',
        'WARN',
        'ERROR',
      ].contains(normalized)) {
        throw const FormatException(
          '--log-level must be one of DEBUG, INFO, WARN, or ERROR.',
        );
      }
      values['logLevel'] = normalized;
    }
    if (results.flag('require-access-keys')) {
      values['requireAccessKeys'] = true;
    }
    return values;
  }

  ArgParser _accessKeyParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named cloud environment override.')
    ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
    ..addOption(
      'repo-root',
      help: 'Optional repo root used to locate an existing env.json.',
    );

  ArgParser _cloudAppParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named cloud environment override.')
    ..addOption('root', help: 'Directory that owns .mini_program/env.json.')
    ..addOption(
      'repo-root',
      help: 'Optional repo root used to locate an existing env.json.',
    );

  String _validateEnvironmentName(String rawName) {
    final trimmedName = rawName.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Environment names must not be blank.');
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmedName)) {
      throw FormatException(
        'Environment name "$trimmedName" contains unsupported characters.',
      );
    }
    return trimmedName;
  }

  String _validateSelectedEnvironmentName(
    String rawName,
    List<CloudEnvironmentConfiguration> configuredCloudEnvironments, {
    bool allowLegacyCloudAlias = false,
  }) {
    final trimmedName = rawName.trim();
    if (trimmedName == 'local') {
      return 'local';
    }
    if (trimmedName == 'cloud' && allowLegacyCloudAlias) {
      return 'cloud';
    }
    if (trimmedName == 'cloud') {
      throw const FormatException(
        'env use cloud is no longer the primary workflow. Use a configured '
        'environment name such as my-aws-prod instead.',
      );
    }
    final normalizedName = _validateEnvironmentName(trimmedName);
    if (!configuredCloudEnvironments.any(
      (environment) => environment.name == normalizedName,
    )) {
      throw FormatException(
        'No configured cloud environment named "$normalizedName" was found. '
        'Run `miniprogram env configure $normalizedName --provider aws ...` '
        'first.',
      );
    }
    return normalizedName;
  }

  String _resolvePublishTarget({
    required String? explicitTarget,
    required ResolvedLocalCliEnvironmentState? resolvedEnvironmentState,
  }) {
    if (explicitTarget case final target? when target.trim().isNotEmpty) {
      return target;
    }
    final activeEnvironment = resolvedEnvironmentState?.state.activeEnvironment;
    if (activeEnvironment == null || activeEnvironment == 'local') {
      return 'local';
    }
    return 'cloud';
  }

  CloudEnvironmentConfiguration _resolveConfiguredCloudEnvironment({
    required LocalCliEnvironmentState? state,
    required String? explicitEnvironmentName,
  }) {
    if (state == null) {
      throw const MiniProgramPublishException(
        'No miniprogram env configuration was found. Run '
        '`miniprogram env init` and `miniprogram env configure ...` first.',
      );
    }

    final requestedEnvironmentName =
        explicitEnvironmentName?.trim().isNotEmpty == true
        ? explicitEnvironmentName!.trim()
        : state.activeEnvironment;
    if (requestedEnvironmentName == 'local') {
      throw const MiniProgramPublishException(
        'Cloud publish requires an active or explicit named cloud '
        'environment. Run `miniprogram env use <env-name>` or pass '
        '`--env <env-name>`.',
      );
    }
    if (requestedEnvironmentName == 'cloud') {
      throw const MiniProgramPublishException(
        'Legacy `cloud` env selection is not enough for cloud publish. '
        'Configure and select a named environment first.',
      );
    }

    final environment = state.cloudEnvironmentNamed(requestedEnvironmentName);
    if (environment == null) {
      throw MiniProgramPublishException(
        'No configured cloud environment named "$requestedEnvironmentName" '
        'was found.',
      );
    }
    return environment;
  }

  List<String> _formatCloudEnvironmentValues(
    CloudEnvironmentConfiguration environment,
  ) {
    final lines = <String>[];
    final sortedKeys = environment.values.keys.toList()..sort();
    for (final key in sortedKeys) {
      lines.add('$key: ${environment.values[key]}');
    }
    return lines;
  }

  Future<void> _persistCloudEnvironmentValueUpdates({
    required ResolvedLocalCliEnvironmentState resolved,
    required String environmentName,
    required Map<String, dynamic> updatedValues,
  }) async {
    if (updatedValues.isEmpty) {
      return;
    }

    final existingEnvironment = resolved.state.cloudEnvironmentNamed(
      environmentName,
    );
    if (existingEnvironment == null) {
      return;
    }

    final mergedValues = Map<String, dynamic>.from(existingEnvironment.values);
    for (final entry in updatedValues.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      mergedValues[entry.key] = value;
    }

    final updatedCloudEnvironments =
        resolved.state.cloudEnvironments
            .where((environment) => environment.name != environmentName)
            .toList()
          ..add(
            existingEnvironment.copyWith(
              values: mergedValues,
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    updatedCloudEnvironments.sort((a, b) => a.name.compareTo(b.name));

    final updatedState = resolved.state.copyWith(
      cloudEnvironments: updatedCloudEnvironments,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    if (resolved.scope == 'global') {
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    } else {
      await _stateStore.writeEnvironmentState(resolved.rootPath, updatedState);
      await _stateStore.writeGlobalEnvironmentState(updatedState);
    }
  }

  Future<String> _resolvePartnerPackageApiBaseUrl({
    required String? explicitApiBaseUrl,
    required String? explicitEnvironmentName,
    required String? explicitRootPath,
    required String? explicitRepoRootPath,
  }) async {
    if (explicitApiBaseUrl case final rawValue?
        when rawValue.trim().isNotEmpty) {
      return _normalizeAbsoluteUrl(rawValue);
    }

    final resolved = await _resolveEnvironmentState(
      explicitRootPath: explicitRootPath,
      explicitRepoRootPath: explicitRepoRootPath,
    );
    if (resolved == null) {
      throw const FormatException(
        'partner package requires --api-base-url <url> or a configured cloud '
        'environment. Run `miniprogram env init` and '
        '`miniprogram env configure ...` first.',
      );
    }
    final requestedEnvironmentName =
        explicitEnvironmentName?.trim().isNotEmpty == true
        ? explicitEnvironmentName!.trim()
        : resolved.state.activeEnvironment;
    if (requestedEnvironmentName.isEmpty ||
        requestedEnvironmentName == 'local' ||
        requestedEnvironmentName == 'cloud') {
      throw const FormatException(
        'partner package needs a named cloud environment when '
        '--api-base-url is omitted. Run `miniprogram env use <env-name>` or '
        'pass `--env <env-name>`.',
      );
    }
    final environment = resolved.state.cloudEnvironmentNamed(
      requestedEnvironmentName,
    );
    if (environment == null) {
      throw FormatException(
        'No configured cloud environment named "$requestedEnvironmentName" '
        'was found.',
      );
    }
    final savedApiBaseUrl = environment.values['apiBaseUrl']?.toString().trim();
    if (savedApiBaseUrl != null && savedApiBaseUrl.isNotEmpty) {
      return _normalizeAbsoluteUrl(savedApiBaseUrl);
    }

    final outputs = await _cloudController.outputs(
      MiniProgramCloudOutputsRequest(
        resolvedEnvironmentState: resolved,
        environment: environment,
      ),
    );
    final backendApiBaseUrl = _requireBackendApiBaseUrlFromOutputs(outputs);
    await _persistCloudEnvironmentValueUpdates(
      resolved: resolved,
      environmentName: environment.name,
      updatedValues: <String, dynamic>{'apiBaseUrl': backendApiBaseUrl},
    );
    return backendApiBaseUrl;
  }

  String _normalizeAbsoluteUrl(String rawValue) {
    final trimmedValue = rawValue.trim();
    final uri = Uri.tryParse(trimmedValue);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('Expected an absolute URL, but got: $rawValue');
    }
    return trimmedValue.replaceFirst(RegExp(r'/+$'), '');
  }

  String _defaultTitleForAppId(String appId) {
    final words = appId
        .trim()
        .split(RegExp(r'[._-]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return appId;
    }
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _normalizeEnvironmentPathPrefix(String rawValue) {
    final normalized = rawValue.trim().replaceAll('\\', '/');
    final trimmed = normalized.replaceAll(RegExp(r'^/+|/+$'), '');
    if (trimmed.isEmpty) {
      throw const FormatException('Cloud object prefixes must not be blank.');
    }
    return trimmed;
  }

  String _currentWorkingDirectory() =>
      p.normalize(p.absolute(_workingDirectory ?? Directory.current.path));

  bool _isGroupHelpRequest(List<String> arguments) {
    if (arguments.length != 1) {
      return false;
    }
    return arguments.single == '--help' ||
        arguments.single == '-h' ||
        arguments.single == 'help';
  }

  String _rootUsage() => '''
Usage: miniprogram <command> [arguments]

Commands:
  create <mini-program-id>
  doctor [--json]
  env init|list|status
  env configure <env-name> --provider aws --bucket <bucket> --region <region>
  env use <local|env-name>
  build [mini-program-id]
  preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id]
  validate [mini-program-id]
  publish [mini-program-id] [--target local|cloud|static] [--env <env-name>] [--output <folder>] [--clean]
  access-key create|list|revoke|rotate <mini-program-id> [--env <env-name>]
  cloud deploy|status|outputs|logs|destroy|doctor|rollback [options]
  cloud app list|info|disable|delete [options]
  cloud outputs [--format text|dart-define]
  workflow status [--workspace <path>] [--env <env-name>] [--remote] [--json]
  partner package <mini-program-id> (--access-key <key>|--public) [--env <env-name>]
  host run -d <device> [--env <env-name>]
  host endpoint add <mini-program-id> --title <title> --api-base-url <url> (--access-key <key>|--public)
  host endpoint import <partner-package.json>
  embed init [--project-root <path>] [--with-demo]
  embed cloud configure [--env <env-name>]
  backend init [--root <path>]
  backend start --port 8080
  backend stop
  backend status [--json]
  backend reset-local --yes

Use `miniprogram <command> --help`, `miniprogram <group> --help`, or
`miniprogram <group> <command> --help` for command-specific options.
''';

  String _workflowUsage() => '''
Usage: miniprogram workflow <command> [arguments]

Commands:
  status [--workspace <path>] [--env <env-name>] [--remote] [--json]
''';

  String _partnerUsage() => '''
Usage: miniprogram partner <command> [arguments]

Commands:
  package <mini-program-id> (--access-key <key>|--public) [--api-base-url <url>|--env <env-name>]
''';

  String _accessKeyUsage() => '''
Usage: miniprogram access-key <command> [arguments]

Commands:
  create <mini-program-id> --key-id <id> [--env <env-name>]
  list <mini-program-id> [--env <env-name>] [--json]
  revoke <mini-program-id> --key-id <id> [--env <env-name>]
  rotate <mini-program-id> --key-id <id> [--new-key-id <id>] [--env <env-name>]
''';

  String _embedUsage() => '''
Usage: miniprogram embed <command> [arguments]

Commands:
  init [--project-root <path>] [--force]
  cloud configure [--env <env-name>]
''';

  String _embedCloudUsage() => '''
Usage: miniprogram embed cloud <command> [arguments]

Commands:
  configure [--env <env-name>]
''';

  String _envUsage() => '''
Usage: miniprogram env <command> [arguments]

Commands:
  init
  configure <env-name> --provider aws --bucket <bucket> --region <region>
  list
  use <local|env-name>
  status [--json]
''';

  String _cloudUsage() => '''
Usage: miniprogram cloud <command> [arguments]

Commands:
  deploy [--env <env-name>]
  status [--env <env-name>] [--json]
  outputs [--env <env-name>] [--format text|dart-define]
  logs [--env <env-name>]
  destroy [--env <env-name>]
  doctor [--env <env-name>]
  rollback <version> [mini-program-id] [--env <env-name>]
  app list [--env <env-name>]
  app info <mini-program-id> [--env <env-name>]
  app disable <mini-program-id> [--yes] [--env <env-name>]
  app delete <mini-program-id> [--yes] [--env <env-name>]
''';

  String _cloudAppUsage() => '''
Usage: miniprogram cloud app <command> [arguments]

Commands:
  list [--env <env-name>]
  info <mini-program-id> [--env <env-name>]
  disable <mini-program-id> [--yes] [--env <env-name>]
  delete <mini-program-id> [--yes] [--env <env-name>]
''';

  String _hostUsage() => '''
Usage: miniprogram host <command> [arguments]

Commands:
  run -d <device> [--env <env-name>]
  endpoint add <mini-program-id> --api-base-url <url> (--access-key <key>|--public)
  endpoint import <partner-package.json>
''';

  String _hostEndpointUsage() => '''
Usage: miniprogram host endpoint <command> [arguments]

Commands:
  add <mini-program-id> --api-base-url <url> (--access-key <key>|--public)
  import <partner-package.json>
''';

  String _backendUsage() => '''
Usage: miniprogram backend <command> [arguments]

Commands:
  init [--root <path>]
  start --port 8080
  stop
  status [--json]
  reset-local --yes
''';

  String _prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Map<String, Object?> _doctorResultJson(MiniprogramDoctorResult result) {
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
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'doctor',
      'hasErrors': result.hasErrors,
      'summary': <String, int>{
        'ok': okCount,
        'warning': warningCount,
        'error': errorCount,
        'skipped': skippedCount,
      },
      'checks': result.checks
          .map(
            (check) => <String, Object?>{
              'label': check.label,
              'status': check.status.name,
              'summary': check.summary,
              'detail': check.detail,
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _envStatusJson(
    ResolvedLocalCliEnvironmentState? resolved,
  ) {
    if (resolved == null) {
      return <String, Object?>{
        'schemaVersion': 1,
        'command': 'env status',
        'configured': false,
      };
    }
    final activeCloudEnvironment = resolved.state.cloudEnvironmentNamed(
      resolved.state.activeEnvironment,
    );
    return <String, Object?>{
      'schemaVersion': 1,
      'command': 'env status',
      'configured': true,
      'scope': resolved.scope,
      'rootPath': resolved.rootPath,
      'filePath': resolved.filePath,
      'repoRootPath': resolved.state.repoRootPath,
      'activeEnvironment': resolved.state.activeEnvironment,
      'cloudEnvironmentCount': resolved.state.cloudEnvironments.length,
      'activeCloudEnvironment': activeCloudEnvironment == null
          ? null
          : _cloudEnvironmentJson(activeCloudEnvironment),
      'initializedAtUtc': resolved.state.initializedAtUtc,
      'updatedAtUtc': resolved.state.updatedAtUtc,
    };
  }

  Map<String, Object?> _cloudEnvironmentJson(
    CloudEnvironmentConfiguration environment,
  ) {
    return <String, Object?>{
      'name': environment.name,
      'provider': environment.provider,
      'values': environment.values,
      'configuredAtUtc': environment.configuredAtUtc,
      'updatedAtUtc': environment.updatedAtUtc,
    };
  }

  String _formatWorkflowStatusResult(MiniProgramWorkflowStatusResult result) {
    final json = result.json;
    final workspace = json['workspace'] as Map<String, Object?>;
    final environment = json['environment'] as Map<String, Object?>;
    final miniProgram = json['miniProgram'] as Map<String, Object?>;
    final hostApp = json['hostApp'] as Map<String, Object?>;
    final backend = json['backend'] as Map<String, Object?>;
    final remote = json['remote'] as Map<String, Object?>;
    final nextActions = (json['nextActions'] as List).cast<String>();
    final lines = <String>[
      'MiniProgram workflow status',
      'Workspace: ${workspace['path']}',
      'Type: ${workspace['type']}',
      'Ready: ${json['ready']}',
      'Severity: ${json['severity']}',
    ];
    if (miniProgram['detected'] == true) {
      final build = miniProgram['build'] as Map<String, Object?>;
      final validation = miniProgram['validation'] as Map<String, Object?>;
      lines.addAll(<String>[
        'Mini-program: ${miniProgram['appId'] ?? 'unknown'}',
        'Version: ${miniProgram['version'] ?? 'unknown'}',
        'Build: ${build['exists'] == true ? 'found' : 'missing'} (${build['screenCount']} screen JSON file(s))',
        'Validation: ${validation['status']}',
        'Partner packages: ${(miniProgram['partnerPackages'] as List).length}',
      ]);
    }
    if (hostApp['detected'] == true) {
      lines.addAll(<String>[
        'Host runtime setup: ${hostApp['runtimeSetupExists']}',
        'Host endpoint map: ${hostApp['endpointMapExists']}',
        'Endpoint count: ${hostApp['endpointCount']}',
      ]);
    }
    lines.addAll(<String>[
      'Environment configured: ${environment['configured']}',
      if (environment['selectedEnvironment'] != null)
        'Environment: ${environment['selectedEnvironment']}',
      if (environment['provider'] != null)
        'Provider: ${environment['provider']}',
      if (environment['apiBaseUrl'] != null)
        'API base URL: ${environment['apiBaseUrl']}',
      'Backend configured: ${backend['configured']}',
      'Remote checked: ${remote['checked']}',
    ]);
    if ((remote['errors'] as List?)?.isNotEmpty == true) {
      lines.add('Remote errors: ${(remote['errors'] as List).join('; ')}');
    }
    if (nextActions.isEmpty) {
      lines.add('Next step: no immediate action.');
    } else {
      lines.add('Next actions:');
      lines.addAll(nextActions.map((action) => '- $action'));
    }
    return lines.join('\n');
  }

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

  String _formatCloudPublishResult(MiniProgramCloudPublishResult result) {
    final versionedObjectCount = result.uploadedObjects
        .where((record) => record.versionId != null)
        .length;
    final lines = <String>[
      'Published mini-program to cloud: ${result.miniProgramId}',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Version: ${result.version}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Artifact root key: ${result.artifactRootKey}',
      'Manifest key: ${result.manifestKey}',
      'Screens prefix: ${result.screensPrefixKey}',
      if (result.assetsPrefixKey != null)
        'Assets prefix: ${result.assetsPrefixKey}',
      'Release metadata key: ${result.metadataReleaseKey}',
      'Catalog metadata key: ${result.metadataCatalogKey}',
      if (result.cloudFrontBaseUrl != null)
        'CloudFront base URL: ${result.cloudFrontBaseUrl}',
      if (result.apiBaseUrl != null) 'API base URL: ${result.apiBaseUrl}',
      'Uploaded objects: ${result.uploadedObjects.length}',
      'Versioned objects: $versionedObjectCount',
      'Published at UTC: ${result.publishedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatStaticPublishResult(MiniProgramStaticPublishResult result) {
    final lines = <String>[
      'Published mini-program to static folder: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Output folder: ${result.outputPath}',
      'Build CLI source: ${result.buildResult.cliSource}',
      'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
      'Latest manifest: ${result.manifestLatestPath}',
      'Versioned manifest: ${result.manifestVersionPath}',
      'Screens directory: ${result.screensDirectoryPath}',
      if (result.assetsDirectoryPath != null)
        'Assets directory: ${result.assetsDirectoryPath}',
      'Release metadata: ${result.metadataReleasePath}',
      'Catalog metadata: ${result.metadataCatalogPath}',
      'Instructions: ${result.instructionsPath}',
      'GitHub Pages marker: ${result.nojekyllPath}',
      'Cleaned generated output first: ${result.cleaned}',
      'Written files: ${result.writtenFiles.length}',
      'Published at UTC: ${result.publishedAtUtc}',
      'Host endpoint example:',
      'MiniProgramEndpoint.public(apiBaseUri: Uri.parse(\'https://your-cdn.example.com/public_mini_program/\'))',
    ];
    return lines.join('\n');
  }

  String _formatCloudDeployResult(MiniProgramCloudDeployResult result) {
    final lines = <String>[
      'Deployed cloud backend.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Bucket: ${result.bucketName}',
      'Backend project root: ${result.backendProjectRootPath}',
      if (result.apiBaseUrl != null)
        'Backend API base URL: ${result.apiBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      'Outputs:',
      ...result.outputs.entries.map(
        (entry) => '- ${entry.key}: ${entry.value}',
      ),
      'Deployed at UTC: ${result.deployedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatCloudStatusResult(MiniProgramCloudStatusResult result) {
    final lines = <String>[
      'Cloud backend status:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Stage: ${result.stageName}',
      'Region: ${result.region}',
      'Stack exists: ${result.stackExists}',
      if (result.stackStatus != null) 'Stack status: ${result.stackStatus}',
      if (result.stackStatusReason != null &&
          result.stackStatusReason!.trim().isNotEmpty)
        'Stack status detail: ${result.stackStatusReason}',
      if (result.apiBaseUrl != null)
        'Backend API base URL: ${result.apiBaseUrl}',
      if (result.healthUrl != null) 'Health URL: ${result.healthUrl}',
      if (result.healthy != null) 'Healthy: ${result.healthy}',
      if (result.healthStatusCode != null)
        'Health status code: ${result.healthStatusCode}',
      if (result.healthError != null) 'Health detail: ${result.healthError}',
      if (result.outputs.isNotEmpty) 'Outputs:',
      if (result.outputs.isNotEmpty)
        ...result.outputs.entries.map(
          (entry) => '- ${entry.key}: ${entry.value}',
        ),
    ];
    return lines.join('\n');
  }

  String _formatCloudOutputsResult(
    MiniProgramCloudOutputsResult result, {
    required String format,
  }) {
    if (format == 'dart-define') {
      final backendApiBaseUrl = _requireBackendApiBaseUrlFromOutputs(result);
      return '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=$backendApiBaseUrl';
    }

    final lines = <String>[
      'Cloud backend outputs:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      ...result.outputs.entries.map(
        (entry) => '- ${entry.key}: ${entry.value}',
      ),
    ];
    return lines.join('\n');
  }

  String _formatCloudLogsResult(MiniProgramCloudLogsResult result) {
    final lines = <String>[
      'Cloud backend logs:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      'Lambda function: ${result.lambdaFunctionName}',
      'Since: ${result.since}',
    ];
    if (result.stdoutText.isNotEmpty) {
      lines.add(result.stdoutText);
    } else {
      lines.add('(no log lines returned)');
    }
    if (result.stderrText.isNotEmpty) {
      lines.add('stderr: ${result.stderrText}');
    }
    return lines.join('\n');
  }

  String _formatCloudDestroyResult(MiniProgramCloudDestroyResult result) {
    return <String>[
      'Destroyed cloud backend stack.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Stack: ${result.stackName}',
      'Region: ${result.region}',
      'Deleted at UTC: ${result.deletedAtUtc}',
    ].join('\n');
  }

  String _formatCloudDoctorResult(MiniProgramCloudDoctorResult result) {
    final lines = <String>['Miniprogram cloud doctor report:'];
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

  String _formatCloudRollbackResult(MiniProgramCloudRollbackResult result) {
    return <String>[
      'Rolled back cloud release.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Version: ${result.version}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      'Release key: ${result.releaseKey}',
      'Rolled back at UTC: ${result.rolledBackAtUtc}',
    ].join('\n');
  }

  String _formatAccessKeyCreateResult(MiniProgramAccessKeyCreateResult result) {
    return <String>[
      'Created MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Key id: ${result.keyId}',
      'Access key: ${result.accessKey}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Created at UTC: ${result.createdAtUtc}',
      'Host endpoint command:',
      'miniprogram host endpoint add ${result.miniProgramId} --api-base-url <BackendApiBaseUrl> --access-key ${result.accessKey}',
    ].join('\n');
  }

  String _formatAccessKeyListResult(MiniProgramAccessKeyListResult result) {
    final lines = <String>[
      'MiniProgram access keys:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Policy exists: ${result.policyExists}',
    ];
    if (result.keys.isEmpty) {
      lines.add('(no keys)');
    } else {
      for (final key in result.keys) {
        lines.add(
          '- ${key.id}: ${key.active ? 'active' : 'revoked'} '
          '(created ${key.createdAtUtc}, updated ${key.updatedAtUtc})',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatAccessKeyRevokeResult(MiniProgramAccessKeyRevokeResult result) {
    return <String>[
      'Revoked MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Key id: ${result.keyId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Revoked at UTC: ${result.revokedAtUtc}',
    ].join('\n');
  }

  String _formatAccessKeyRotateResult(MiniProgramAccessKeyRotateResult result) {
    return <String>[
      'Rotated MiniProgram access key.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Revoked key id: ${result.revokedKeyId}',
      'New key id: ${result.newKeyId}',
      'Access key: ${result.accessKey}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Policy key: ${result.policyKey}',
      'Rotated at UTC: ${result.rotatedAtUtc}',
    ].join('\n');
  }

  String _formatCloudAppListResult(MiniProgramCloudAppListResult result) {
    final lines = <String>[
      'Cloud mini-program apps:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
    ];
    if (result.apps.isEmpty) {
      lines.add('(no active apps)');
    } else {
      for (final app in result.apps) {
        lines.add(
          '- ${app.miniProgramId}: '
          '${app.latestVersion ?? 'unknown version'} '
          '(${app.catalogKey})',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatCloudAppInfoResult(MiniProgramCloudAppInfoResult result) {
    return <String>[
      'Cloud mini-program app:',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      if (result.catalog['latestVersion'] != null)
        'Latest version: ${result.catalog['latestVersion']}',
      if (result.releaseKey != null) 'Release key: ${result.releaseKey}',
      if (result.release?['artifacts'] case final artifacts?)
        'Artifacts: $artifacts',
      'Access policy key: ${result.accessPolicyKey ?? 'not found'}',
      'Access keys: ${result.activeAccessKeyCount} active / ${result.accessKeyCount} total',
    ].join('\n');
  }

  String _formatCloudAppDisableResult(MiniProgramCloudAppDisableResult result) {
    return <String>[
      result.dryRun
          ? 'Dry run: cloud mini-program app would be disabled.'
          : 'Disabled cloud mini-program app.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Catalog key: ${result.catalogKey}',
      'Disabled catalog key: ${result.disabledCatalogKey}',
      'Disabled at UTC: ${result.disabledAtUtc}',
      if (result.dryRun)
        'Re-run with --yes to remove the active catalog pointer.',
    ].join('\n');
  }

  String _formatCloudAppDeleteResult(MiniProgramCloudAppDeleteResult result) {
    final lines = <String>[
      result.dryRun
          ? 'Dry run: cloud mini-program app objects would be deleted.'
          : 'Deleted cloud mini-program app objects.',
      'Provider: ${result.provider}',
      'Environment: ${result.environmentName}',
      'Mini-program: ${result.miniProgramId}',
      'Bucket: ${result.bucketName}',
      'Region: ${result.region}',
      'Object count: ${result.deletedKeys.length}',
      if (result.dryRun) 'Re-run with --yes to delete these objects.',
      'Objects:',
      ...result.deletedKeys.map((key) => '- $key'),
      'Completed at UTC: ${result.deletedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatPartnerPackageResult(MiniProgramPartnerPackageResult result) {
    return <String>[
      'Created MiniProgram partner handoff package.',
      'Package file: ${result.filePath}',
      'Mini-program: ${result.handoff.appId}',
      'Title: ${result.handoff.title}',
      'Access mode: ${result.handoff.accessMode}',
      'API base URL: ${result.handoff.apiBaseUri}',
      'Generated at UTC: ${result.handoff.generatedAtUtc}',
      'Host import command:',
      'miniprogram host endpoint import ${result.filePath}',
    ].join('\n');
  }

  String _formatHostEndpointAddResult(MiniProgramHostEndpointAddResult result) {
    return <String>[
      result.created
          ? 'Created MiniProgram host endpoint map.'
          : result.updated
          ? 'Updated MiniProgram host endpoint.'
          : 'Added MiniProgram host endpoint.',
      'Project root: ${result.projectRootPath}',
      'Endpoint file: ${result.filePath}',
      'Registry file: ${result.registryFilePath}',
      'Mini-program: ${result.appId}',
      'Title: ${result.title}',
      'Access mode: ${result.accessMode}',
      'API base URL: ${result.apiBaseUri}',
      'Endpoint count: ${result.endpointCount}',
      'Registry count: ${result.registryCount}',
      'Use it from MiniProgramScope:',
      'config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),',
    ].join('\n');
  }

  String _formatHostEndpointImportResult({
    required String packagePath,
    required MiniProgramPartnerHandoff handoff,
    required MiniProgramHostEndpointAddResult endpointResult,
  }) {
    return <String>[
      endpointResult.created
          ? 'Imported MiniProgram partner handoff and created endpoint map.'
          : endpointResult.updated
          ? 'Imported MiniProgram partner handoff and updated endpoint.'
          : 'Imported MiniProgram partner handoff and added endpoint.',
      'Package file: $packagePath',
      'Project root: ${endpointResult.projectRootPath}',
      'Endpoint file: ${endpointResult.filePath}',
      'Registry file: ${endpointResult.registryFilePath}',
      'Mini-program: ${handoff.appId}',
      'Title: ${handoff.title}',
      'Access mode: ${handoff.accessMode}',
      'API base URL: ${handoff.apiBaseUri}',
      'Endpoint count: ${endpointResult.endpointCount}',
      'Registry count: ${endpointResult.registryCount}',
      'Open from app UI by appId only:',
      "openAppMiniProgram(context, appId: '${handoff.appId}', title: ...);",
    ].join('\n');
  }

  String _formatEmbeddingInitResult(MiniProgramEmbeddingInitResult result) {
    final lines = <String>[
      'Initialized embedded mini-program adapter for: ${result.packageName}',
      'Project root: ${result.projectRootPath}',
      if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
      'Host app id: ${result.hostAppId}',
      'Host version: ${result.hostVersion}',
      if (result.withDemo)
        'Public demo: profile via https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/',
      'Files:',
      ...result.createdPaths.map((path) => '- $path'),
    ];
    return lines.join('\n');
  }

  String _formatEmbeddedHostCloudConfigurationResult({
    required String projectRootPath,
    required String configurationPath,
    required EmbeddedHostCloudConfiguration configuration,
  }) {
    return <String>[
      'Configured embedded host app for cloud mini-program delivery.',
      'Project root: $projectRootPath',
      'Config file: $configurationPath',
      'Environment: ${configuration.environmentName}',
      'Provider: ${configuration.provider}',
      'Backend API base URL: ${configuration.backendApiBaseUrl}',
      'Configured at UTC: ${configuration.configuredAtUtc}',
      'Updated at UTC: ${configuration.updatedAtUtc}',
    ].join('\n');
  }

  String _formatHostRunStart({
    required String projectRootPath,
    required String deviceId,
    required String? environmentName,
    required String backendApiBaseUrl,
  }) {
    return <String>[
      'Running embedded host app.',
      'Project root: $projectRootPath',
      'Device: $deviceId',
      if (environmentName != null) 'Environment: $environmentName',
      'Backend API base URL: $backendApiBaseUrl',
    ].join('\n');
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

    final activeCloudEnvironment = resolved.state.cloudEnvironmentNamed(
      resolved.state.activeEnvironment,
    );
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
      'Configured cloud environments: ${resolved.state.cloudEnvironments.length}',
      if (activeCloudEnvironment != null)
        'Active provider: ${activeCloudEnvironment.provider}',
      if (activeCloudEnvironment != null)
        ..._formatCloudEnvironmentValues(activeCloudEnvironment),
      if (resolved.state.activeEnvironment == 'cloud')
        'Active provider: legacy cloud alias (reconfigure to a named cloud environment)',
      'Initialized at UTC: ${resolved.state.initializedAtUtc}',
      'Updated at UTC: ${resolved.state.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatEnvConfigureResult(
    CloudEnvironmentConfiguration environment,
    ResolvedLocalCliEnvironmentState resolved,
  ) {
    final lines = <String>[
      'Configured cloud environment: ${environment.name}',
      'Provider: ${environment.provider}',
      'Config scope: ${resolved.scope}',
      'Config root: ${resolved.rootPath}',
      'Config file: ${resolved.filePath}',
      ..._formatCloudEnvironmentValues(environment),
      'Configured at UTC: ${environment.configuredAtUtc}',
      'Updated at UTC: ${environment.updatedAtUtc}',
    ];
    return lines.join('\n');
  }

  String _formatEnvListResult(ResolvedLocalCliEnvironmentState resolved) {
    final lines = <String>[
      'Configured environments:',
      '${resolved.state.activeEnvironment == 'local' ? '*' : '-'} local',
    ];
    for (final environment in resolved.state.cloudEnvironments) {
      lines.add(
        '${resolved.state.activeEnvironment == environment.name ? '*' : '-'} '
        '${environment.name} (${environment.provider})',
      );
    }
    if (resolved.state.activeEnvironment == 'cloud') {
      lines.add('- cloud (legacy alias)');
    }
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
      ..._formatBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    if (result.reversedDeviceIds.isNotEmpty) {
      lines.add(
        'ADB reverse: ${result.reversedDeviceIds.join(', ')} '
        '(tcp:${state.port} -> tcp:${state.port})',
      );
    }
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
      ..._formatBackendTargetUrls(state.port),
      'stdout log: ${state.stdoutLogPath}',
      'stderr log: ${state.stderrLogPath}',
    ];
    return lines.join('\n');
  }

  List<String> _formatBackendTargetUrls(int port) {
    return <String>[
      'Android emulator URL: http://10.0.2.2:$port/api/',
      'Desktop/Chrome URL: http://127.0.0.1:$port/api/',
      'Android USB via adb reverse: http://127.0.0.1:$port/api/',
    ];
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

  Future<void> _requireEmbeddedHostProject(String projectRootPath) async {
    final normalizedProjectRootPath = p.normalize(p.absolute(projectRootPath));
    final projectDirectory = Directory(normalizedProjectRootPath);
    if (!await projectDirectory.exists()) {
      throw MiniProgramHostException(
        'Flutter host project root does not exist: $normalizedProjectRootPath',
      );
    }

    final pubspecFile = File(p.join(normalizedProjectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostException(
        'Flutter host project is missing pubspec.yaml: '
        '$normalizedProjectRootPath',
      );
    }

    final generatedRuntimeSetup = File(
      p.join(
        normalizedProjectRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    );
    if (!await generatedRuntimeSetup.exists()) {
      throw const MiniProgramHostException(
        'The generated mini-program embedding adapter was not found. Run '
        '`miniprogram embed init` in the host Flutter app first.',
      );
    }
  }

  String _requireBackendApiBaseUrlFromOutputs(
    MiniProgramCloudOutputsResult result,
  ) {
    final rawBackendApiBaseUrl = result.outputs['BackendApiBaseUrl'];
    if (rawBackendApiBaseUrl == null || rawBackendApiBaseUrl.trim().isEmpty) {
      throw const MiniProgramCloudException(
        'Cloud stack outputs did not include BackendApiBaseUrl.',
      );
    }
    return _normalizeAbsoluteUrl(rawBackendApiBaseUrl);
  }

  CloudEnvironmentConfiguration? _resolveCloudEnvironmentForHostRun({
    required ResolvedLocalCliEnvironmentState? resolvedEnvironmentState,
    required String? explicitEnvironmentName,
    required EmbeddedHostCloudConfiguration? hostConfiguration,
  }) {
    final requestedEnvironmentName =
        explicitEnvironmentName?.trim().isNotEmpty == true
        ? explicitEnvironmentName!.trim()
        : hostConfiguration?.environmentName ??
              resolvedEnvironmentState?.state.activeEnvironment;
    if (requestedEnvironmentName == null || requestedEnvironmentName.isEmpty) {
      throw const MiniProgramHostException(
        'No cloud environment was selected for the host app. Pass '
        '`--env <env-name>` or run `miniprogram embed cloud configure --env '
        '<env-name>` first.',
      );
    }
    if (requestedEnvironmentName == 'local' ||
        requestedEnvironmentName == 'cloud') {
      throw const MiniProgramHostException(
        'host run requires a named cloud environment such as my-aws-prod.',
      );
    }

    final resolvedEnvironment = resolvedEnvironmentState?.state
        .cloudEnvironmentNamed(requestedEnvironmentName);
    if (resolvedEnvironment != null) {
      return resolvedEnvironment;
    }
    if (hostConfiguration != null &&
        hostConfiguration.environmentName == requestedEnvironmentName) {
      return null;
    }

    throw MiniProgramHostException(
      'No configured cloud environment named "$requestedEnvironmentName" was '
      'found. Run `miniprogram env configure $requestedEnvironmentName '
      '--provider aws ...` first.',
    );
  }

  Future<String> _resolveHostBackendApiBaseUrl({
    required String projectRootPath,
    required ResolvedLocalCliEnvironmentState? resolvedEnvironmentState,
    required CloudEnvironmentConfiguration? environment,
    required EmbeddedHostCloudConfiguration? hostConfiguration,
  }) async {
    if (environment != null) {
      final configuredBackendApiBaseUrl = environment.values['apiBaseUrl']
          ?.toString()
          .trim();
      if (configuredBackendApiBaseUrl != null &&
          configuredBackendApiBaseUrl.isNotEmpty) {
        return _normalizeAbsoluteUrl(configuredBackendApiBaseUrl);
      }

      if (resolvedEnvironmentState != null) {
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
        await _stateStore.writeHostCloudConfiguration(
          projectRootPath,
          EmbeddedHostCloudConfiguration(
            environmentName: environment.name,
            provider: environment.provider,
            backendApiBaseUrl: backendApiBaseUrl,
            configuredAtUtc: hostConfiguration?.configuredAtUtc ?? now,
            updatedAtUtc: now,
          ),
        );
        return backendApiBaseUrl;
      }
    }

    if (hostConfiguration != null &&
        hostConfiguration.backendApiBaseUrl.trim().isNotEmpty) {
      return _normalizeAbsoluteUrl(hostConfiguration.backendApiBaseUrl);
    }

    throw const MiniProgramHostException(
      'No cloud backend API base URL could be resolved for the host app. Run '
      '`miniprogram cloud deploy` first, then `miniprogram embed cloud '
      'configure --env <env-name>`.',
    );
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
