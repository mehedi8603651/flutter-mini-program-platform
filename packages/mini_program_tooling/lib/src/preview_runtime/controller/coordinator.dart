import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../local_cli_state.dart';
import '../../mini_program_builder.dart';
import '../host/models.dart';
import '../server/bundle_loader.dart';
import '../server/models.dart';
import '../server/runtime.dart';
import 'device_transport.dart';
import 'models.dart';
import 'process_lifecycle.dart';
import 'watcher.dart';

typedef PreviewBundleLoad =
    Future<MiniProgramPreviewBundle> Function(
      MiniProgramBuildResult buildResult,
    );

typedef PreviewHostInitialize =
    Future<MiniProgramPreviewHostInitResult> Function(
      MiniProgramPreviewHostInitRequest request,
    );

Future<int> runMiniProgramPreview(
  MiniProgramPreviewRequest request, {
  required StringSink stdoutSink,
  required StringSink stderrSink,
  required MiniProgramBuilder builder,
  PreviewBundleLoad bundleLoader = loadMiniProgramPreviewBundle,
  required PreviewHostInitialize hostInitializer,
  required LocalCliStateStore stateStore,
  required PreviewShellRunner shellRunner,
  required PreviewLanAddressResolver lanAddressResolver,
  required PreviewProcessStarter processStarter,
}) async {
  final deviceTransport = PreviewDeviceTransportResolver(
    shellRunner: shellRunner,
    lanAddressResolver: lanAddressResolver,
  );
  final rawDeviceId = request.deviceId.trim();
  final launchTarget = await deviceTransport.resolveLaunchTarget(rawDeviceId);

  final miniProgramRootPath = p.normalize(
    p.absolute(request.miniProgramRootPath),
  );
  final previewHostRootPath = p.join(
    stateStore.stateDirectoryPath(miniProgramRootPath),
    'preview_host',
  );

  final initialBuildResult = await _buildPreviewBundle(
    request,
    builder: builder,
    skipPubGet: false,
  );
  final initialBundle = await bundleLoader(initialBuildResult);

  await hostInitializer(
    MiniProgramPreviewHostInitRequest(
      hostRootPath: previewHostRootPath,
      repoRootPath: request.repoRootPath,
      screenFormat: initialBuildResult.screenFormat,
      requiredPlatforms: launchTarget.flutterPlatforms,
    ),
  );
  await resetTransientPreviewHostState(previewHostRootPath);

  final previewServer = PreviewServerRuntime(
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
    final previewTransport = await deviceTransport.prepareTransport(
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
    flutterRunProcess = await processStarter(
      executable: 'flutter',
      arguments: buildPreviewFlutterRunArguments(
        hostRootPath: previewHostRootPath,
        deviceId: launchTarget.deviceId,
        previewBaseUrl: previewServer.baseUri.toString(),
        miniProgramId: request.miniProgramId,
        title: initialBundle.title,
      ),
      workingDirectory: previewHostRootPath,
    );

    stdoutSink.writeln('Watching $miniProgramRootPath for preview changes...');
    stdoutSink.writeln('Press Ctrl+C to stop preview.');

    await watcher.start(
      rootPath: miniProgramRootPath,
      onRebuild: () async {
        previewServer.markBuilding();
        stdoutSink.writeln('Preview rebuild triggered...');
        try {
          final buildResult = await _buildPreviewBundle(
            request,
            builder: builder,
            skipPubGet: true,
          );
          final bundle = await bundleLoader(buildResult);
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
  required MiniProgramBuilder builder,
  required bool skipPubGet,
}) {
  return builder.build(
    MiniProgramBuildRequest(
      repoRootPath: request.repoRootPath,
      miniProgramId: request.miniProgramId,
      miniProgramRootPath: request.miniProgramRootPath,
      mpBuildScriptPath: request.mpBuildScriptPath,
      skipPubGet: skipPubGet,
    ),
  );
}
