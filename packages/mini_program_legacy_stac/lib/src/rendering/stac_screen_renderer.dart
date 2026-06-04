import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';

import 'stac_initializer.dart';

/// Legacy renderer for Stac screen JSON.
class StacScreenRenderer extends MiniProgramScreenRenderer {
  /// Creates the legacy Stac renderer.
  const StacScreenRenderer();

  @override
  MiniProgramScreenFormat get screenFormat => MiniProgramScreenFormats.stac;

  @override
  Set<int> get supportedSchemaVersions => const <int>{};

  @override
  Future<void> ensureInitialized({required SdkLogger logger}) {
    return StacInitializer.ensureInitialized(logger: logger);
  }

  @override
  Widget render(MiniProgramRenderRequest request) {
    final rendered = Stac.fromJson(request.screenJson, request.context);
    if (rendered == null) {
      throw MiniProgramRenderException(
        message:
            'Failed to render screen "${request.screenId}" for mini-program "${request.manifest.id}".',
      );
    }
    return rendered;
  }
}
