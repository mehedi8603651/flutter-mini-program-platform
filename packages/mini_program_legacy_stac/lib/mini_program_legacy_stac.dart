library;

import 'package:mini_program_sdk/mini_program_sdk.dart';

export 'src/rendering/stac_screen_renderer.dart';

import 'src/rendering/stac_screen_renderer.dart';

/// Optional renderer registrations for hosts that still consume Stac screens.
const List<MiniProgramScreenRenderer> legacyStacRenderers =
    <MiniProgramScreenRenderer>[StacScreenRenderer()];
