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

typedef PreviewLanAddressResolver =
    Future<String?> Function({String? preferredPeerHost});

class PreviewLaunchTarget {
  const PreviewLaunchTarget({
    required this.deviceId,
    required this.flutterPlatforms,
    required this.previewServerBindAddress,
    required this.previewServerFallbackPublicHost,
    this.adbReverseMode = PreviewAdbReverseMode.none,
    this.requiresLanPreviewHost = false,
    this.preferredLanPeerHost,
  });

  final String deviceId;
  final Set<String> flutterPlatforms;
  final InternetAddress previewServerBindAddress;
  final String previewServerFallbackPublicHost;
  final PreviewAdbReverseMode adbReverseMode;
  final bool requiresLanPreviewHost;
  final String? preferredLanPeerHost;
}

enum PreviewAdbReverseMode { none, prefer, require }

enum PreviewAndroidConnectionKind { usb, wifi }

class ResolvedPreviewAdbDevice {
  const ResolvedPreviewAdbDevice({
    required this.deviceId,
    required this.connectionKind,
    this.peerHost,
  });

  final String deviceId;
  final PreviewAndroidConnectionKind connectionKind;
  final String? peerHost;
}

class PreparedPreviewTransport {
  const PreparedPreviewTransport({
    required this.publicHost,
    this.usedAdbReverse = false,
    this.diagnosticMessage,
  });

  final String publicHost;
  final bool usedAdbReverse;
  final String? diagnosticMessage;
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
    this.mpBuildScriptPath,
  });

  final String miniProgramId;
  final String miniProgramRootPath;
  final String deviceId;
  final String? repoRootPath;
  final String? mpBuildScriptPath;
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
    final mpBuildScriptPath = p.join(
      normalizedRootPath,
      'tool',
      'build_mp.dart',
    );

    if (p.equals(normalizedPath, manifestPath) ||
        p.equals(normalizedPath, mpBuildScriptPath)) {
      return true;
    }

    if (!p.isWithin(normalizedRootPath, normalizedPath)) {
      return false;
    }

    if (_isIgnoredPath(normalizedPath, rootPath: normalizedRootPath)) {
      return false;
    }

    return p.isWithin(p.join(normalizedRootPath, 'mp'), normalizedPath) ||
        p.isWithin(p.join(normalizedRootPath, 'assets'), normalizedPath);
  }

  static bool _isIgnoredPath(String path, {required String rootPath}) {
    return _pathEqualsOrIsWithin(p.join(rootPath, '.mini_program'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, '.dart_tool'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'build'), path) ||
        _pathEqualsOrIsWithin(p.join(rootPath, 'mp', '.build'), path);
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
    PreviewLanAddressResolver lanAddressResolver = _defaultLanAddressResolver,
    PreviewProcessStarter processStarter = _defaultProcessStarter,
  }) : _builder = builder,
       _bundleLoader = bundleLoader,
       _hostInitializer = hostInitializer,
       _stateStore = stateStore,
       _shellRunner = shellRunner,
       _lanAddressResolver = lanAddressResolver,
       _processStarter = processStarter;

  static const Set<String> supportedDeviceIds = <String>{
    'chrome',
    'edge',
    'ios',
    'linux',
    'macos',
    'windows',
  };
  static final RegExp _androidEmulatorDeviceIdPattern = RegExp(
    r'^emulator-\d+$',
  );

  final MiniProgramBuilder _builder;
  final MiniProgramPreviewBundleLoader _bundleLoader;
  final MiniProgramPreviewHostInitializer _hostInitializer;
  final LocalCliStateStore _stateStore;
  final PreviewShellRunner _shellRunner;
  final PreviewLanAddressResolver _lanAddressResolver;
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
        screenFormat: initialBuildResult.screenFormat,
        requiredPlatforms: launchTarget.flutterPlatforms,
      ),
    );
    await _resetTransientPreviewHostState(previewHostRootPath);

    final previewServer = MiniProgramPreviewServer(
      bindAddress: launchTarget.previewServerBindAddress,
      publicHost: launchTarget.previewServerFallbackPublicHost,
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
      final previewTransport = await _preparePreviewTransport(
        launchTarget,
        port: previewServer.baseUri.port,
      );
      previewServer.updatePublicHost(previewTransport.publicHost);

      stdoutSink.writeln('Preview server: ${previewServer.baseUri}');
      stdoutSink.writeln('Managed preview host: $previewHostRootPath');
      if (previewTransport.usedAdbReverse) {
        stdoutSink.writeln(
          'ADB reverse: ${launchTarget.deviceId} '
          '(tcp:${previewServer.baseUri.port} -> tcp:${previewServer.baseUri.port})',
        );
      }
      if (previewTransport.diagnosticMessage case final message?
          when message.trim().isNotEmpty) {
        stdoutSink.writeln(message);
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
        mpBuildScriptPath: request.mpBuildScriptPath,
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
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'edge') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'web'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'ios') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'ios'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'windows') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'windows'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'linux') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'linux'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'macos') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'macos'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (_androidEmulatorDeviceIdPattern.hasMatch(normalizedDeviceId)) {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: '10.0.2.2',
        adbReverseMode: PreviewAdbReverseMode.prefer,
      );
    }

    final adbDevice = await _resolveConnectedAdbDevice(trimmedDeviceId);
    if (adbDevice != null &&
        adbDevice.connectionKind == PreviewAndroidConnectionKind.usb) {
      return PreviewLaunchTarget(
        deviceId: adbDevice.deviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
        adbReverseMode: PreviewAdbReverseMode.require,
      );
    }

    if (adbDevice != null &&
        adbDevice.connectionKind == PreviewAndroidConnectionKind.wifi) {
      return PreviewLaunchTarget(
        deviceId: adbDevice.deviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
        requiresLanPreviewHost: true,
        preferredLanPeerHost: adbDevice.peerHost,
      );
    }

    throw MiniProgramPreviewException(_unsupportedDeviceMessage(deviceId));
  }

  String _unsupportedDeviceMessage(String deviceId) {
    final supported = <String>[
      ...supportedDeviceIds.toList()..sort(),
      'Android emulator ids like emulator-5554',
      'Android USB device ids like R58M123ABC',
      'Android Wi-Fi device ids like 192.168.1.25:5555',
    ];
    return 'Preview currently supports only these devices: '
        '${supported.join(', ')}. '
        'Received: $deviceId';
  }

  Future<ResolvedPreviewAdbDevice?> _resolveConnectedAdbDevice(
    String requestedDeviceId,
  ) async {
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
        if (_looksLikeWirelessAdbDeviceId(connectedDeviceId)) {
          return ResolvedPreviewAdbDevice(
            deviceId: connectedDeviceId,
            connectionKind: PreviewAndroidConnectionKind.wifi,
            peerHost: _extractWirelessDeviceHost(connectedDeviceId),
          );
        }

        return ResolvedPreviewAdbDevice(
          deviceId: connectedDeviceId,
          connectionKind: PreviewAndroidConnectionKind.usb,
        );
      }
    }

    return null;
  }

  Future<PreparedPreviewTransport> _preparePreviewTransport(
    PreviewLaunchTarget launchTarget, {
    required int port,
  }) async {
    if (launchTarget.requiresLanPreviewHost) {
      final lanPreviewHost = await _resolvePreviewLanHost(
        preferredPeerHost: launchTarget.preferredLanPeerHost,
      );
      return PreparedPreviewTransport(
        publicHost: lanPreviewHost,
        diagnosticMessage:
            'Android Wi-Fi preview: using LAN host $lanPreviewHost '
            'for ${launchTarget.deviceId}.',
      );
    }

    if (launchTarget.adbReverseMode == PreviewAdbReverseMode.none) {
      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
      );
    }

    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
        throw const MiniProgramPreviewException(
          'Android USB preview requires adb, but no adb executable was found.',
        );
      }

      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
        diagnosticMessage:
            'ADB reverse was not available for ${launchTarget.deviceId}. '
            'Falling back to ${launchTarget.previewServerFallbackPublicHost}.',
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
      if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
        throw MiniProgramPreviewException(
          'Android USB preview could not run adb reverse for ${launchTarget.deviceId}.',
        );
      }

      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
        diagnosticMessage:
            'ADB reverse could not run for ${launchTarget.deviceId}. '
            'Falling back to ${launchTarget.previewServerFallbackPublicHost}.',
      );
    }
    if (reverseResult.exitCode == 0) {
      return const PreparedPreviewTransport(
        publicHost: '127.0.0.1',
        usedAdbReverse: true,
      );
    }

    final stderrText = '${reverseResult.stderr}'.trim();
    final stdoutText = '${reverseResult.stdout}'.trim();
    final details = [
      'Command: adb -s ${launchTarget.deviceId} reverse tcp:$port tcp:$port',
      if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
      if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
    ].join('\n');

    if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
      throw MiniProgramPreviewException(
        [
          'Android USB preview requires adb reverse, but it failed for ${launchTarget.deviceId}.',
          details,
        ].join('\n'),
      );
    }

    return PreparedPreviewTransport(
      publicHost: launchTarget.previewServerFallbackPublicHost,
      diagnosticMessage:
          'ADB reverse failed for ${launchTarget.deviceId}. '
          'Falling back to ${launchTarget.previewServerFallbackPublicHost}.\n'
          '$details',
    );
  }

  Future<String> _resolvePreviewLanHost({String? preferredPeerHost}) async {
    final manualHost =
        Platform.environment['MINI_PROGRAM_PREVIEW_LAN_HOST']?.trim() ?? '';
    final fallbackManualHost =
        Platform.environment['MINI_PROGRAM_PREVIEW_PUBLIC_HOST']?.trim() ?? '';
    if (manualHost.isNotEmpty) {
      return manualHost;
    }
    if (fallbackManualHost.isNotEmpty) {
      return fallbackManualHost;
    }

    final resolvedHost = await _lanAddressResolver(
      preferredPeerHost: preferredPeerHost,
    );
    if (resolvedHost case final host? when host.trim().isNotEmpty) {
      return host.trim();
    }

    throw MiniProgramPreviewException(
      'Android Wi-Fi preview requires a reachable LAN IPv4 address on this '
      'machine, but none could be resolved. Set MINI_PROGRAM_PREVIEW_LAN_HOST '
      'to your dev machine IP and try again.',
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
      '--no-hot',
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

  static bool _looksLikeWirelessAdbDeviceId(String deviceId) {
    if (!deviceId.contains(':')) {
      return false;
    }

    final host = _extractWirelessDeviceHost(deviceId);
    return host != null && host.trim().isNotEmpty;
  }

  static String? _extractWirelessDeviceHost(String deviceId) {
    final separatorIndex = deviceId.lastIndexOf(':');
    if (separatorIndex <= 0 || separatorIndex == deviceId.length - 1) {
      return null;
    }

    return deviceId.substring(0, separatorIndex).trim();
  }

  static Future<String?> _defaultLanAddressResolver({
    String? preferredPeerHost,
  }) async {
    List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
    } on SocketException {
      return null;
    }

    final candidates = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final host = address.address.trim();
        if (host.isEmpty ||
            address.isLoopback ||
            host == InternetAddress.anyIPv4.address ||
            _isLinkLocalIpv4(host)) {
          continue;
        }
        candidates.add(host);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    final uniqueCandidates = candidates.toSet().toList();
    if (preferredPeerHost != null && preferredPeerHost.trim().isNotEmpty) {
      uniqueCandidates.sort(
        (left, right) => _compareLanCandidates(
          left,
          right,
          preferredPeerHost: preferredPeerHost,
        ),
      );
    } else {
      uniqueCandidates.sort((left, right) {
        final leftPrivate = _isPrivateIpv4(left);
        final rightPrivate = _isPrivateIpv4(right);
        if (leftPrivate != rightPrivate) {
          return leftPrivate ? -1 : 1;
        }
        return left.compareTo(right);
      });
    }

    return uniqueCandidates.first;
  }

  static int _compareLanCandidates(
    String left,
    String right, {
    required String preferredPeerHost,
  }) {
    final leftScore = _sharedIpv4OctetPrefixLength(left, preferredPeerHost);
    final rightScore = _sharedIpv4OctetPrefixLength(right, preferredPeerHost);
    if (leftScore != rightScore) {
      return rightScore.compareTo(leftScore);
    }

    final leftPrivate = _isPrivateIpv4(left);
    final rightPrivate = _isPrivateIpv4(right);
    if (leftPrivate != rightPrivate) {
      return leftPrivate ? -1 : 1;
    }

    return left.compareTo(right);
  }

  static int _sharedIpv4OctetPrefixLength(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    if (leftParts.length != 4 || rightParts.length != 4) {
      return 0;
    }

    var score = 0;
    for (var index = 0; index < 4; index += 1) {
      if (leftParts[index] != rightParts[index]) {
        break;
      }
      score += 1;
    }
    return score;
  }

  static bool _isPrivateIpv4(String host) {
    final octets = host.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((value) => value == null)) {
      return false;
    }

    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  static bool _isLinkLocalIpv4(String host) {
    final octets = host.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((value) => value == null)) {
      return false;
    }
    return octets[0] == 169 && octets[1] == 254;
  }
}
