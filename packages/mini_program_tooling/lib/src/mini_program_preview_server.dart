import 'dart:io';

import 'mini_program_builder.dart';
import 'preview_runtime/server/bundle_loader.dart';
import 'preview_runtime/server/models.dart';
import 'preview_runtime/server/runtime.dart';

export 'preview_runtime/server/models.dart'
    show
        MiniProgramPreviewBundle,
        MiniProgramPreviewException,
        MiniProgramPreviewStates,
        PreviewHttpServerBinder;

class MiniProgramPreviewBundleLoader {
  const MiniProgramPreviewBundleLoader();

  Future<MiniProgramPreviewBundle> load(MiniProgramBuildResult buildResult) {
    return loadMiniProgramPreviewBundle(buildResult);
  }
}

class MiniProgramPreviewServer {
  MiniProgramPreviewServer({
    PreviewHttpServerBinder serverBinder = defaultPreviewServerBinder,
    InternetAddress? bindAddress,
    String publicHost = '127.0.0.1',
  }) : _runtime = PreviewServerRuntime(
         serverBinder: serverBinder,
         bindAddress: bindAddress,
         publicHost: publicHost,
       );

  final PreviewServerRuntime _runtime;

  int get buildVersion => _runtime.buildVersion;

  void updatePublicHost(String publicHost) {
    _runtime.updatePublicHost(publicHost);
  }

  Uri get baseUri => _runtime.baseUri;

  Future<void> start({required MiniProgramPreviewBundle initialBundle}) {
    return _runtime.start(initialBundle: initialBundle);
  }

  void markBuilding() {
    _runtime.markBuilding();
  }

  void applyBundle(MiniProgramPreviewBundle bundle) {
    _runtime.applyBundle(bundle);
  }

  void markBuildFailed(String error) {
    _runtime.markBuildFailed(error);
  }

  Future<void> close() {
    return _runtime.close();
  }
}
