import 'preview_runtime/host/initializer.dart';
import 'preview_runtime/host/models.dart';

export 'preview_runtime/host/models.dart'
    show
        MiniProgramPreviewHostInitException,
        MiniProgramPreviewHostInitRequest,
        MiniProgramPreviewHostInitResult,
        PreviewHostShellRunner;

class MiniProgramPreviewHostInitializer {
  const MiniProgramPreviewHostInitializer({
    PreviewHostShellRunner shellRunner = defaultPreviewHostShellRunner,
  }) : _shellRunner = shellRunner;

  final PreviewHostShellRunner _shellRunner;

  Future<MiniProgramPreviewHostInitResult> initialize(
    MiniProgramPreviewHostInitRequest request,
  ) {
    return initializeMiniProgramPreviewHost(request, shellRunner: _shellRunner);
  }
}
