import 'dart:convert';
import 'dart:collection';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mini_program_ui/mini_program_ui.dart';

part 'mp_screen_renderer_test/validator_tests.dart';
part 'mp_screen_renderer_test/renderer_tests.dart';
part 'mp_screen_renderer_test/media_playback_tests.dart';
part 'mp_screen_renderer_test/gallery_tests.dart';
part 'mp_screen_renderer_test/microphone_tests.dart';
part 'mp_screen_renderer_test/system_tests.dart';
part 'mp_screen_renderer_test/maps_tests.dart';
part 'mp_screen_renderer_test/date_time_tests.dart';
part 'mp_screen_renderer_test/floating_action_button_tests.dart';
part 'mp_screen_renderer_test/app_bar_tests.dart';
part 'mp_screen_renderer_test/test_fixtures.dart';

void main() {
  _mpScreenValidatorTests();
  _mpScreenRendererTests();
  _mpMediaPlaybackTests();
  _mpGalleryTests();
  _mpMicrophoneTests();
  _mpSystemTests();
  _mpMapsTests();
  _mpDateTimeTests();
  _mpFloatingActionButtonTests();
  _mpAppBarTests();
}
