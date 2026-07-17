import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../delivery_validation.dart';
import 'shared_validation.dart';
import 'validation_context.dart';

void validateDeliveryManifestSemantics({
  required DeliveryValidationContext context,
  required MiniProgramManifest manifest,
  required String manifestPath,
}) {
  validateDeliverySemanticVersion(
    context: context,
    value: manifest.version,
    code: 'manifest_invalid_version',
    filePath: manifestPath,
    label: 'version',
  );

  validateDeliverySemanticVersion(
    context: context,
    value: manifest.contractVersion,
    code: 'manifest_invalid_contract_version',
    filePath: manifestPath,
    label: 'contractVersion',
  );

  if (!manifest.sdkVersionRange.isValid) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'manifest_invalid_sdk_version_range',
        path: context.relativePath(manifestPath),
        message:
            'sdkVersionRange "${manifest.sdkVersionRange.value}" is not a valid semantic version range.',
      ),
    );
  }

  if (manifest.entry.trim().isEmpty) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'manifest_blank_entry',
        path: context.relativePath(manifestPath),
        message: 'entry must not be blank.',
      ),
    );
  }

  if (manifest.fallback?.strategy == MiniProgramFallbackStrategy.hostRoute &&
      (manifest.fallback?.route == null ||
          manifest.fallback!.route!.trim().isEmpty)) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'manifest_host_route_fallback_missing_route',
        path: context.relativePath(manifestPath),
        message:
            'fallback.route is required when fallback.strategy is hostRoute.',
      ),
    );
  }

  if (manifest.requiresCapability(CapabilityIds.secureApi) &&
      manifest.cachePolicy.entryScreen.mode != MiniProgramCacheMode.noCache) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'secure_api_entry_screen_must_not_cache',
        path: context.relativePath(manifestPath),
        message:
            'Mini-programs requiring secure_api must set entryScreen cache mode to noCache.',
      ),
    );
  }
}

MiniProgramManifest? parseDeliveryManifest(
  Map<String, dynamic> manifestJson,
  String manifestPath, {
  required DeliveryValidationContext context,
}) {
  try {
    return MiniProgramManifest.fromJson(manifestJson);
  } catch (error) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'manifest_parse_failed',
        path: context.relativePath(manifestPath),
        message: 'Manifest could not be parsed: $error',
      ),
    );
    return null;
  }
}
