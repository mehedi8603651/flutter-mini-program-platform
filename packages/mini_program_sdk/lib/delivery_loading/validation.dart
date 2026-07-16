part of '../manifest_loader.dart';

extension _ManifestHostValidation on ManifestLoader {
  void _validateManifestForHost({
    required MiniProgramManifest manifest,
    required String sdkVersion,
    required CapabilityRegistry capabilityRegistry,
    required FeatureFlagEvaluator featureFlagEvaluator,
    required SdkLogger logger,
  }) {
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
      final missingWireValues = missingCapabilities.toList()..sort();

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
  }
}
