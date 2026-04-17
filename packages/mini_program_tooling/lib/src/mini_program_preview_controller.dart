import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_preview_host_initializer.dart';
import 'mini_program_preview_server.dart';

typedef PreviewShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class PreviewLaunchTarget {
  const PreviewLaunchTarget({
    required this.deviceId,
    required this.flutterPlatforms,
    required this.previewServerBindAddress,
    required this.previewServerPublicHost,
    this.requiresAdbReverse = false,
  });

  final String deviceId;
  final Set<String> flutterPlatforms;
  final InternetAddress previewServerBindAddress;
  final String previewServerPublicHost;
  final bool requiresAdbReverse;
}

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
      if (!isRelevantPath(rootPath: _rootPath!, path: event.path)) {
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

  static bool isRelevantPath({required String rootPath, required String path}) {
    final normalizedRootPath = p.normalize(p.absolute(rootPath));
    final normalizedPath = p.normalize(p.absolute(path));
    final manifestPath = p.join(normalizedRootPath, 'manifest.json');
    final defaultOptionsPath = p.join(
      normalizedRootPath,
      'lib',
      'default_stac_options.dart',
    );

    if (p.equals(normalizedPath, manifestPath) ||
        p.equals(normalizedPath, defaultOptionsPath)) {
      return true;
    }

    if (!p.isWithin(normalizedRootPath, normalizedPath)) {
      return false;
    }

    if (_isIgnoredPath(normalizedPath, rootPath: normalizedRootPath)) {
      return false;
    }

    return p.isWithin(p.join(normalizedRootPath, 'stac'), normalizedPath) ||
        p.isWithin(p.join(normalizedRootPath, 'assets'), normalizedPath);
  }

  static bool _isIgnoredPath(String path, {required String rootPath}) {
    return _pathEqualsOrIsWithin(p.join(rootPath, '.mini_program'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, '.dart_tool'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'build'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'stac', '.build'), path);
  }

  static bool _pathEqualsOrIsWithin(String rootPath, String path) {
    return p.equals(rootPath, path) || p.isWithin(rootPath, path);
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
    PreviewShellRunner shellRunner = _defaultShellRunner,
    PreviewProcessStarter processStarter = _defaultProcessStarter,
  }) : _builder = builder,
       _bundleLoader = bundleLoader,
       _hostInitializer = hostInitializer,
       _stateStore = stateStore,
       _shellRunner = shellRunner,
       _processStarter = processStarter;

  static const Set<String> supportedDeviceIds = <String>{'chrome', 'windows'};
  static final RegExp _androidEmulatorDeviceIdPattern = RegExp(
    r'^emulator-\d+$',
  );

  final MiniProgramBuilder _builder;
  final MiniProgramPreviewBundleLoader _bundleLoader;
  final MiniProgramPreviewHostInitializer _hostInitializer;
  final LocalCliStateStore _stateStore;
  final PreviewShellRunner _shellRunner;
  final PreviewProcessStarter _processStarter;

  Future<int> preview(
    MiniProgramPreviewRequest request, {
    required StringSink stdoutSink,
    required StringSink stderrSink,
  }) async {
    final rawDeviceId = request.deviceId.trim();
    final launchTarget = await _resolveLaunchTarget(rawDeviceId);

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
        requiredPlatforms: launchTarget.flutterPlatforms,
      ),
    );
    await _resetTransientPreviewHostState(previewHostRootPath);

    final previewServer = MiniProgramPreviewServer(
      bindAddress: launchTarget.previewServerBindAddress,
      publicHost: launchTarget.previewServerPublicHost,
    );
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
      await _configureAdbReverseIfNeeded(
        launchTarget,
        port: previewServer.baseUri.port,
      );
      if (launchTarget.requiresAdbReverse) {
        stdoutSink.writeln(
          'ADB reverse: ${launchTarget.deviceId} '
          '(tcp:${previewServer.baseUri.port} -> tcp:${previewServer.baseUri.port})',
        );
      }

      flutterRunProcess = await _processStarter(
        executable: 'flutter',
        arguments: _flutterRunArguments(
          hostRootPath: previewHostRootPath,
          deviceId: launchTarget.deviceId,
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

  Future<PreviewLaunchTarget> _resolveLaunchTarget(String deviceId) async {
    final trimmedDeviceId = deviceId.trim();
    final normalizedDeviceId = trimmedDeviceId.toLowerCase();
    if (normalizedDeviceId == 'chrome') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'web'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'windows') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'windows'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (_androidEmulatorDeviceIdPattern.hasMatch(normalizedDeviceId)) {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerPublicHost: '10.0.2.2',
      );
    }

    final adbDeviceId = await _resolveConnectedAdbDeviceId(trimmedDeviceId);
    if (adbDeviceId != null) {
      return PreviewLaunchTarget(
        deviceId: adbDeviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerPublicHost: InternetAddress.loopbackIPv4.address,
        requiresAdbReverse: true,
      );
    }

    throw MiniProgramPreviewException(_unsupportedDeviceMessage(deviceId));
  }

  String _unsupportedDeviceMessage(String deviceId) {
    final supported = <String>[
      ...supportedDeviceIds.toList()..sort(),
      'Android emulator ids like emulator-5554',
      'Android USB device ids like R58M123ABC',
    ];
    return 'Preview currently supports only these devices: '
        '${supported.join(', ')}. '
        'Received: $deviceId';
  }

  Future<String?> _resolveConnectedAdbDeviceId(String requestedDeviceId) async {
    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      return null;
    }

    final devicesResult = await _tryShell(adbExecutable, const <String>[
      'devices',
    ]);
    if (devicesResult == null || devicesResult.exitCode != 0) {
      return null;
    }

    final connectedDeviceIds = const LineSplitter()
        .convert('${devicesResult.stdout}')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('List of devices attached'),
        )
        .map((line) => line.split(RegExp(r'\s+')))
        .where((parts) => parts.length >= 2 && parts[1] == 'device')
        .map((parts) => parts.first)
        .where(
          (deviceId) =>
              !_androidEmulatorDeviceIdPattern.hasMatch(deviceId.toLowerCase()),
        )
        .toList();

    for (final connectedDeviceId in connectedDeviceIds) {
      if (connectedDeviceId.toLowerCase() == requestedDeviceId.toLowerCase()) {
        return connectedDeviceId;
      }
    }

    return null;
  }

  Future<void> _configureAdbReverseIfNeeded(
    PreviewLaunchTarget launchTarget, {
    required int port,
  }) async {
    if (!launchTarget.requiresAdbReverse) {
      return;
    }

    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      throw const MiniProgramPreviewException(
        'Android USB preview requires adb, but no adb executable was found.',
      );
    }

    final reverseResult = await _tryShell(adbExecutable, <String>[
      '-s',
      launchTarget.deviceId,
      'reverse',
      'tcp:$port',
      'tcp:$port',
    ]);
    if (reverseResult == null) {
      throw MiniProgramPreviewException(
        'Android USB preview could not run adb reverse for ${launchTarget.deviceId}.',
      );
    }
    if (reverseResult.exitCode == 0) {
      return;
    }

    final stderrText = '${reverseResult.stderr}'.trim();
    final stdoutText = '${reverseResult.stdout}'.trim();
    throw MiniProgramPreviewException(
      [
        'Android USB preview requires adb reverse, but it failed for ${launchTarget.deviceId}.',
        'Command: adb -s ${launchTarget.deviceId} reverse tcp:$port tcp:$port',
        if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
        if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
      ].join('\n'),
    );
  }

  Future<String?> _resolveAdbExecutable() async {
    final candidates = <String>[
      if (Platform.isWindows)
        p.join(
          _resolveLocalAppDataDirectoryPath(),
          'Android',
          'Sdk',
          'platform-tools',
          'adb.exe',
        ),
      if (Platform.environment['ANDROID_SDK_ROOT'] case final sdkRoot?
          when sdkRoot.trim().isNotEmpty)
        p.join(
          sdkRoot,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      if (Platform.environment['ANDROID_HOME'] case final androidHome?
          when androidHome.trim().isNotEmpty)
        p.join(
          androidHome,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      Platform.isWindows ? 'adb.exe' : 'adb',
    ];

    for (final candidate in candidates.toSet()) {
      final result = await _tryShell(candidate, const <String>['version']);
      if (result != null && result.exitCode == 0) {
        return candidate;
      }
    }

    return null;
  }

  Future<ProcessResult?> _tryShell(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await _shellRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return null;
    }
  }

  static String _resolveLocalAppDataDirectoryPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return localAppData;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'AppData', 'Local');
    }

    return Directory.current.path;
  }

  Future<void> _resetTransientPreviewHostState(String hostRootPath) async {
    final buildDirectory = Directory(p.join(hostRootPath, 'build'));
    final flutterBuildDirectory = Directory(
      p.join(hostRootPath, '.dart_tool', 'flutter_build'),
    );

    await _deleteDirectoryIfExists(
      buildDirectory,
      label: 'preview host build output',
    );
    await _deleteDirectoryIfExists(
      flutterBuildDirectory,
      label: 'preview host flutter build cache',
    );
    await _deleteCrashLogs(hostRootPath);
  }

  Future<void> _deleteDirectoryIfExists(
    Directory directory, {
    required String label,
  }) async {
    if (!await directory.exists()) {
      return;
    }

    await _withCleanupRetries(
      () => directory.delete(recursive: true),
      label: label,
      path: directory.path,
    );
  }

  Future<void> _deleteCrashLogs(String hostRootPath) async {
    final hostRootDirectory = Directory(hostRootPath);
    if (!await hostRootDirectory.exists()) {
      return;
    }

    await for (final entity in hostRootDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final basename = p.basename(entity.path);
      if (!RegExp(r'^flutter_\d+\.log$').hasMatch(basename)) {
        continue;
      }

      await _withCleanupRetries(
        () => entity.delete(),
        label: 'preview host crash log',
        path: entity.path,
      );
    }
  }

  Future<void> _withCleanupRetries(
    Future<void> Function() operation, {
    required String label,
    required String path,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < 4; attempt += 1) {
      try {
        await operation();
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == 3) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
    }

    Error.throwWithStackTrace(
      MiniProgramPreviewException(
        'Failed to clear $label at $path before launch. '
        'Close any leftover Chrome or Flutter preview windows and try again. '
        'Original error: $lastError',
      ),
      lastStackTrace ?? StackTrace.current,
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

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );
  }
}
