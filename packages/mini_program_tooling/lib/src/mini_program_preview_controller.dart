import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_preview_host_initializer.dart';
import 'mini_program_preview_server.dart';

typedef PreviewProcessStarter =
    Future<StartedPreviewProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
      Map<String, String>? environment,
    });

class MiniProgramPreviewRequest {
  const MiniProgramPreviewRequest({
    required this.miniProgramId,
    required this.miniProgramRootPath,
    required this.deviceId,
    this.repoRootPath,
    this.stacCliScriptPath,
  });

  final String miniProgramId;
  final String miniProgramRootPath;
  final String deviceId;
  final String? repoRootPath;
  final String? stacCliScriptPath;
}

class StartedPreviewProcess {
  const StartedPreviewProcess({
    required this.pid,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.kill,
  });

  final int pid;
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Future<int> exitCode;
  final bool Function([ProcessSignal signal]) kill;
}

class MiniProgramPreviewWatcher {
  MiniProgramPreviewWatcher({
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  final Duration debounceDuration;

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  Future<void> Function()? _onRebuild;
  String? _rootPath;
  bool _rebuildInProgress = false;
  bool _queuedRebuild = false;

  Future<void> start({
    required String rootPath,
    required Future<void> Function() onRebuild,
  }) async {
    await stop();
    _rootPath = p.normalize(p.absolute(rootPath));
    _onRebuild = onRebuild;

    _subscription = Directory(_rootPath!).watch(recursive: true).listen((
      event,
    ) {
      if (!_isRelevantPath(event.path)) {
        return;
      }

      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, _scheduleRebuild);
    });
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _onRebuild = null;
    _rootPath = null;
    _rebuildInProgress = false;
    _queuedRebuild = false;
  }

  bool _isRelevantPath(String path) {
    final rootPath = _rootPath;
    if (rootPath == null) {
      return false;
    }

    final normalizedPath = p.normalize(p.absolute(path));
    final manifestPath = p.join(rootPath, 'manifest.json');
    final defaultOptionsPath = p.join(
      rootPath,
      'lib',
      'default_stac_options.dart',
    );

    if (normalizedPath == manifestPath ||
        normalizedPath == defaultOptionsPath) {
      return true;
    }

    if (!p.isWithin(rootPath, normalizedPath)) {
      return false;
    }

    if (_isIgnoredPath(normalizedPath, rootPath: rootPath)) {
      return false;
    }

    return p.isWithin(p.join(rootPath, 'stac'), normalizedPath) ||
        p.isWithin(p.join(rootPath, 'assets'), normalizedPath);
  }

  bool _isIgnoredPath(String path, {required String rootPath}) {
    return p.isWithin(p.join(rootPath, '.mini_program'), path) ||
        p.isWithin(p.join(rootPath, '.dart_tool'), path) ||
        p.isWithin(p.join(rootPath, 'build'), path) ||
        p.isWithin(p.join(rootPath, 'stac', '.build'), path);
  }

  void _scheduleRebuild() {
    final onRebuild = _onRebuild;
    if (onRebuild == null) {
      return;
    }

    if (_rebuildInProgress) {
      _queuedRebuild = true;
      return;
    }

    unawaited(_runRebuildLoop(onRebuild));
  }

  Future<void> _runRebuildLoop(Future<void> Function() onRebuild) async {
    _rebuildInProgress = true;
    try {
      do {
        _queuedRebuild = false;
        await onRebuild();
      } while (_queuedRebuild);
    } finally {
      _rebuildInProgress = false;
    }
  }
}

class MiniProgramPreviewController {
  const MiniProgramPreviewController({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    MiniProgramPreviewBundleLoader bundleLoader =
        const MiniProgramPreviewBundleLoader(),
    MiniProgramPreviewHostInitializer hostInitializer =
        const MiniProgramPreviewHostInitializer(),
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    PreviewProcessStarter processStarter = _defaultProcessStarter,
  }) : _builder = builder,
       _bundleLoader = bundleLoader,
       _hostInitializer = hostInitializer,
       _stateStore = stateStore,
       _processStarter = processStarter;

  static const Set<String> supportedDeviceIds = <String>{'chrome', 'windows'};

  final MiniProgramBuilder _builder;
  final MiniProgramPreviewBundleLoader _bundleLoader;
  final MiniProgramPreviewHostInitializer _hostInitializer;
  final LocalCliStateStore _stateStore;
  final PreviewProcessStarter _processStarter;

  Future<int> preview(
    MiniProgramPreviewRequest request, {
    required StringSink stdoutSink,
    required StringSink stderrSink,
  }) async {
    final normalizedDeviceId = request.deviceId.trim().toLowerCase();
    _validateDeviceId(normalizedDeviceId);

    final miniProgramRootPath = p.normalize(
      p.absolute(request.miniProgramRootPath),
    );
    final previewHostRootPath = p.join(
      _stateStore.stateDirectoryPath(miniProgramRootPath),
      'preview_host',
    );

    final initialBuildResult = await _buildPreviewBundle(
      request,
      skipPubGet: false,
    );
    final initialBundle = await _bundleLoader.load(initialBuildResult);

    await _hostInitializer.initialize(
      MiniProgramPreviewHostInitRequest(
        hostRootPath: previewHostRootPath,
        repoRootPath: request.repoRootPath,
      ),
    );

    final previewServer = MiniProgramPreviewServer();
    await previewServer.start(initialBundle: initialBundle);
    StartedPreviewProcess? flutterRunProcess;
    final watcher = MiniProgramPreviewWatcher();
    StreamSubscription<String>? stdoutSubscription;
    StreamSubscription<String>? stderrSubscription;
    StreamSubscription<ProcessSignal>? interruptSubscription;
    final interrupt = Completer<void>();
    int exitCode = 0;
    var childExitHandled = false;

    try {
      stdoutSink.writeln('Preview server: ${previewServer.baseUri}');
      stdoutSink.writeln('Managed preview host: $previewHostRootPath');

      flutterRunProcess = await _processStarter(
        executable: 'flutter',
        arguments: _flutterRunArguments(
          hostRootPath: previewHostRootPath,
          deviceId: normalizedDeviceId,
          previewBaseUrl: previewServer.baseUri.toString(),
          miniProgramId: request.miniProgramId,
          title: initialBundle.title,
        ),
        workingDirectory: previewHostRootPath,
      );

      stdoutSink.writeln(
        'Watching $miniProgramRootPath for preview changes...',
      );
      stdoutSink.writeln('Press Ctrl+C to stop preview.');

      await watcher.start(
        rootPath: miniProgramRootPath,
        onRebuild: () async {
          previewServer.markBuilding();
          stdoutSink.writeln('Preview rebuild triggered...');
          try {
            final buildResult = await _buildPreviewBundle(
              request,
              skipPubGet: true,
            );
            final bundle = await _bundleLoader.load(buildResult);
            previewServer.applyBundle(bundle);
            stdoutSink.writeln(
              'Preview refreshed (buildVersion: ${previewServer.buildVersion}).',
            );
          } catch (error) {
            final message = '$error'.trim();
            previewServer.markBuildFailed(message);
            stderrSink.writeln(message);
          }
        },
      );

      stdoutSubscription = flutterRunProcess.stdout
          .transform(utf8.decoder)
          .listen(stdoutSink.write);
      stderrSubscription = flutterRunProcess.stderr
          .transform(utf8.decoder)
          .listen(stderrSink.write);

      try {
        interruptSubscription = ProcessSignal.sigint.watch().listen((_) {
          if (!interrupt.isCompleted) {
            interrupt.complete();
          }
        });
      } catch (_) {
        // Ignore unsupported signal subscriptions in tests or unusual runtimes.
      }

      final result = await Future.any<Object?>(<Future<Object?>>[
        flutterRunProcess.exitCode,
        interrupt.future.then<Object?>((_) => null),
      ]);

      if (result is int) {
        childExitHandled = true;
        exitCode = result;
      } else {
        stdoutSink.writeln('Stopping preview...');
        flutterRunProcess.kill();
        exitCode = await flutterRunProcess.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => 130,
        );
        childExitHandled = true;
        if (exitCode == 0) {
          exitCode = 130;
        }
      }
    } finally {
      await interruptSubscription?.cancel();
      if (flutterRunProcess != null && !childExitHandled) {
        flutterRunProcess.kill();
      }
      await watcher.stop();
      await previewServer.close();
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();
    }

    return exitCode;
  }

  Future<MiniProgramBuildResult> _buildPreviewBundle(
    MiniProgramPreviewRequest request, {
    required bool skipPubGet,
  }) {
    return _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: request.repoRootPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: request.miniProgramRootPath,
        stacCliScriptPath: request.stacCliScriptPath,
        skipPubGet: skipPubGet,
      ),
    );
  }

  void _validateDeviceId(String deviceId) {
    if (supportedDeviceIds.contains(deviceId.trim().toLowerCase())) {
      return;
    }

    throw MiniProgramPreviewException(
      'Preview v1 supports only these devices: '
      '${(supportedDeviceIds.toList()..sort()).join(', ')}. '
      'Received: $deviceId',
    );
  }

  List<String> _flutterRunArguments({
    required String hostRootPath,
    required String deviceId,
    required String previewBaseUrl,
    required String miniProgramId,
    required String title,
  }) {
    return <String>[
      'run',
      '--project-root',
      hostRootPath,
      '-d',
      deviceId,
      '--dart-define=MINI_PROGRAM_PREVIEW_BASE_URL=$previewBaseUrl',
      '--dart-define=MINI_PROGRAM_PREVIEW_MINI_PROGRAM_ID=$miniProgramId',
      '--dart-define=MINI_PROGRAM_PREVIEW_TITLE=$title',
    ];
  }

  static Future<StartedPreviewProcess> _defaultProcessStarter({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: Platform.isWindows,
    );
    return StartedPreviewProcess(
      pid: process.pid,
      stdout: process.stdout,
      stderr: process.stderr,
      exitCode: process.exitCode,
      kill: ([signal = ProcessSignal.sigterm]) => process.kill(signal),
    );
  }
}
