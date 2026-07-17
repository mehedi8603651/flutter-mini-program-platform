import 'local_cli_state.dart';
import 'mini_program_builder.dart';
import 'mini_program_preview_host_initializer.dart';
import 'mini_program_preview_server.dart';
import 'preview_runtime/controller/coordinator.dart';
import 'preview_runtime/controller/device_transport.dart';
import 'preview_runtime/controller/models.dart';
import 'preview_runtime/controller/process_lifecycle.dart';

export 'preview_runtime/controller/models.dart'
    show
        MiniProgramPreviewRequest,
        PreparedPreviewTransport,
        PreviewAdbReverseMode,
        PreviewAndroidConnectionKind,
        PreviewLanAddressResolver,
        PreviewLaunchTarget,
        PreviewProcessStarter,
        PreviewShellRunner,
        ResolvedPreviewAdbDevice,
        StartedPreviewProcess;
export 'preview_runtime/controller/watcher.dart' show MiniProgramPreviewWatcher;

class MiniProgramPreviewController {
  const MiniProgramPreviewController({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    MiniProgramPreviewBundleLoader bundleLoader =
        const MiniProgramPreviewBundleLoader(),
    MiniProgramPreviewHostInitializer hostInitializer =
        const MiniProgramPreviewHostInitializer(),
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    PreviewShellRunner shellRunner = defaultPreviewShellRunner,
    PreviewLanAddressResolver lanAddressResolver =
        defaultPreviewLanAddressResolver,
    PreviewProcessStarter processStarter = defaultPreviewProcessStarter,
  }) : _builder = builder,
       _bundleLoader = bundleLoader,
       _hostInitializer = hostInitializer,
       _stateStore = stateStore,
       _shellRunner = shellRunner,
       _lanAddressResolver = lanAddressResolver,
       _processStarter = processStarter;

  static const Set<String> supportedDeviceIds = supportedPreviewDeviceIds;

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
  }) {
    return runMiniProgramPreview(
      request,
      stdoutSink: stdoutSink,
      stderrSink: stderrSink,
      builder: _builder,
      bundleLoader: _bundleLoader.load,
      hostInitializer: _hostInitializer.initialize,
      stateStore: _stateStore,
      shellRunner: _shellRunner,
      lanAddressResolver: _lanAddressResolver,
      processStarter: _processStarter,
    );
  }
}
