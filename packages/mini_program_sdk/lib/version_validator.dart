import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'mini_program_failure.dart';

/// Validates whether a manifest can run on the current SDK version.
class VersionValidator {
  const VersionValidator();

  MiniProgramFailure? validate({
    required MiniProgramManifest manifest,
    required String sdkVersion,
  }) {
    final sdkRange = manifest.sdkVersionRange;

    if (!sdkRange.isValid) {
      return MiniProgramFailure(
        errorCode: MiniProgramErrorCodes.unsupportedSdkVersion,
        message:
            'Mini-program "${manifest.id}" declares an invalid SDK version range: ${sdkRange.value}.',
        fallback: manifest.fallback,
        details: <String, dynamic>{
          'miniProgramId': manifest.id,
          'sdkVersionRange': sdkRange.value,
        },
      );
    }

    if (!sdkRange.allows(sdkVersion)) {
      return MiniProgramFailure(
        errorCode: MiniProgramErrorCodes.unsupportedSdkVersion,
        message:
            'Mini-program "${manifest.id}" requires SDK ${sdkRange.value}, but host SDK is $sdkVersion.',
        fallback: manifest.fallback,
        details: <String, dynamic>{
          'miniProgramId': manifest.id,
          'sdkVersionRange': sdkRange.value,
          'hostSdkVersion': sdkVersion,
        },
      );
    }

    return null;
  }
}
