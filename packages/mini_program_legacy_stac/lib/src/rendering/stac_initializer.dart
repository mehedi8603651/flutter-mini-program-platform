import 'package:flutter/foundation.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';

import '../actions/sdk_mini_program_navigation_parser.dart';
import '../actions/sdk_mini_program_auth_parser.dart';
import '../actions/sdk_host_action_parser.dart';
import '../actions/sdk_mini_program_backend_parser.dart';
import '../actions/sdk_mini_program_backend_query_parser.dart';
import '../actions/sdk_mini_program_load_more_parser.dart';
import 'sdk_mini_program_auth_builder_parser.dart';
import 'sdk_mini_program_backend_builder_parser.dart';
import 'sdk_mini_program_paged_backend_builder_parser.dart';

/// Ensures the SDK's Stac extensions are registered exactly once per isolate.
abstract final class StacInitializer {
  static bool _initialized = false;
  static Future<void>? _initialization;

  static Future<void> ensureInitialized({required SdkLogger logger}) {
    if (_initialized) {
      return Future<void>.value();
    }

    return _initialization ??= _initialize(logger);
  }

  static Future<void> _initialize(SdkLogger logger) async {
    try {
      await Stac.initialize(
        parsers: const [
          SdkMiniProgramAuthBuilderParser(),
          SdkMiniProgramBackendBuilderParser(),
          SdkMiniProgramPagedBackendBuilderParser(),
        ],
        actionParsers: const [
          SdkHostActionParser(),
          SdkMiniProgramAuthParser(),
          SdkMiniProgramBackendParser(),
          SdkMiniProgramBackendQueryParser(),
          SdkMiniProgramLoadMoreParser(),
          SdkMiniProgramNavigationParser(),
        ],
        showErrorWidgets: false,
        logStackTraces: true,
      );
      _initialized = true;
      logger.info('Stac initialized for mini_program_sdk.');
    } catch (error, stackTrace) {
      logger.error(
        'Failed to initialize Stac for mini_program_sdk.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _initialization = null;
    }
  }

  @visibleForTesting
  static bool get isInitializedForTesting => _initialized;

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _initialization = null;
  }
}
