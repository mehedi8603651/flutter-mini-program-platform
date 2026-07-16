import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'cache/manifest_cache.dart';
import 'cache/screen_cache.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'mini_program_failure.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'version_validator.dart';

part 'delivery_loading/manifest_cache.dart';
part 'delivery_loading/models.dart';
part 'delivery_loading/pipeline.dart';
part 'delivery_loading/publisher_backend.dart';
part 'delivery_loading/screen_cache.dart';
part 'delivery_loading/stale_cache.dart';
part 'delivery_loading/validation.dart';

/// Loads, validates, and resolves the entry screen for a mini-program.
class ManifestLoader {
  const ManifestLoader({this.versionValidator = const VersionValidator()});

  final VersionValidator versionValidator;

  Future<LoadedMiniProgram> load({
    required String miniProgramId,
    required String sdkVersion,
    required MiniProgramSource source,
    required ManifestCache manifestCache,
    required ScreenCache screenCache,
    required CapabilityRegistry capabilityRegistry,
    required FeatureFlagEvaluator featureFlagEvaluator,
    required SdkLogger logger,
  }) {
    return _loadMiniProgram(
      miniProgramId: miniProgramId,
      sdkVersion: sdkVersion,
      source: source,
      manifestCache: manifestCache,
      screenCache: screenCache,
      capabilityRegistry: capabilityRegistry,
      featureFlagEvaluator: featureFlagEvaluator,
      logger: logger,
    );
  }

  Future<LoadedMiniProgramScreen> loadScreen({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required String screenId,
    required MiniProgramSource source,
    required ScreenCache screenCache,
    required SdkLogger logger,
  }) {
    return _loadResolvedScreen(
      miniProgramId: miniProgramId,
      manifest: manifest,
      screenId: screenId,
      source: source,
      screenCache: screenCache,
      logger: logger,
    );
  }
}
