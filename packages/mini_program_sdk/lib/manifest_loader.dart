import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'mini_program_failure.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'version_validator.dart';

/// Fully resolved mini-program state ready for rendering.
class LoadedMiniProgram {
  const LoadedMiniProgram({
    required this.manifest,
    required this.entryScreenJson,
  });

  final MiniProgramManifest manifest;
  final Map<String, dynamic> entryScreenJson;
}

/// Loads, validates, and resolves the entry screen for a mini-program.
class ManifestLoader {
  const ManifestLoader({this.versionValidator = const VersionValidator()});

  final VersionValidator versionValidator;

  Future<LoadedMiniProgram> load({
    required String miniProgramId,
    required String sdkVersion,
    required MiniProgramSource source,
    required CapabilityRegistry capabilityRegistry,
    required FeatureFlagEvaluator featureFlagEvaluator,
    required SdkLogger logger,
  }) async {
    final MiniProgramManifest manifest;
    try {
      manifest = await source.loadManifest(miniProgramId);
    } catch (error, stackTrace) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;
      logger.error(
        'Failed to load manifest.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': miniProgramId},
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode:
              sourceException?.errorCode ??
              MiniProgramErrorCodes.manifestParseFailure,
          message:
              sourceException?.message ??
              'Failed to load manifest for mini-program "$miniProgramId".',
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            if (sourceException != null) ...sourceException.details,
          },
        ),
      );
    }

    final versionFailure = versionValidator.validate(
      manifest: manifest,
      sdkVersion: sdkVersion,
    );
    if (versionFailure != null) {
      logger.warn(
        'Manifest rejected by SDK version validation.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'sdkVersionRange': manifest.sdkVersionRange.value,
          'hostSdkVersion': sdkVersion,
        },
      );
      throw MiniProgramLoadException(versionFailure);
    }

    final missingCapabilities = capabilityRegistry.missingCapabilities(
      manifest.requiredCapabilities,
    );
    if (missingCapabilities.isNotEmpty) {
      final missingWireValues =
          missingCapabilities.map((capability) => capability.wireValue).toList()
            ..sort();

      logger.warn(
        'Manifest rejected because required capabilities are missing.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'missingCapabilities': missingWireValues.join(', '),
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode: MiniProgramErrorCodes.unsupportedCapability,
          message:
              'Host app does not support required capabilities: ${missingWireValues.join(', ')}.',
          fallback: manifest.fallback,
          details: <String, dynamic>{
            'miniProgramId': manifest.id,
            'missingCapabilities': missingWireValues,
          },
        ),
      );
    }

    final disabledFlags =
        manifest.featureFlags
            .where((flag) => !featureFlagEvaluator.isEnabled(flag))
            .toList()
          ..sort();
    if (disabledFlags.isNotEmpty) {
      logger.warn(
        'Manifest rejected because required feature flags are disabled.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'disabledFeatureFlags': disabledFlags.join(', '),
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          message:
              'Required feature flags are disabled: ${disabledFlags.join(', ')}.',
          fallback: manifest.fallback,
          details: <String, dynamic>{
            'miniProgramId': manifest.id,
            'disabledFeatureFlags': disabledFlags,
          },
        ),
      );
    }

    try {
      final entryScreenJson = await source.loadScreen(
        miniProgramId: miniProgramId,
        version: manifest.version,
        screenId: manifest.entry,
      );

      if (entryScreenJson.isEmpty) {
        throw const FormatException('Entry screen JSON is empty.');
      }

      return LoadedMiniProgram(
        manifest: manifest,
        entryScreenJson: entryScreenJson,
      );
    } catch (error, stackTrace) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;
      logger.error(
        'Failed to load entry screen JSON.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': miniProgramId,
          'entryScreen': manifest.entry,
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode:
              sourceException?.errorCode ??
              MiniProgramErrorCodes.manifestParseFailure,
          message:
              sourceException?.message ??
              'Failed to load entry screen "${manifest.entry}" for mini-program "${manifest.id}".',
          fallback: manifest.fallback,
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'entryScreen': manifest.entry,
            if (sourceException != null) ...sourceException.details,
          },
        ),
      );
    }
  }
}
