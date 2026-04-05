import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('VersionValidator', () {
    const validator = VersionValidator();

    test('accepts compatible SDK versions', () {
      final manifest = _buildManifest();

      final failure = validator.validate(
        manifest: manifest,
        sdkVersion: '1.5.0',
      );

      expect(failure, isNull);
    });

    test('rejects incompatible SDK versions', () {
      final manifest = _buildManifest();

      final failure = validator.validate(
        manifest: manifest,
        sdkVersion: '2.0.0',
      );

      expect(failure, isNotNull);
      expect(failure!.errorCode, MiniProgramErrorCodes.unsupportedSdkVersion);
    });

    test('rejects invalid SDK range expressions', () {
      final manifest = _buildManifest(
        sdkVersionRange: const SdkVersionRange(value: 'not-a-range'),
      );

      final failure = validator.validate(
        manifest: manifest,
        sdkVersion: '1.0.0',
      );

      expect(failure, isNotNull);
      expect(failure!.errorCode, MiniProgramErrorCodes.unsupportedSdkVersion);
    });
  });
}

MiniProgramManifest _buildManifest({
  SdkVersionRange sdkVersionRange = const SdkVersionRange(
    value: '>=1.0.0 <2.0.0',
  ),
}) {
  return MiniProgramManifest(
    id: 'profile_center',
    version: '1.0.0',
    entry: 'profile/home',
    contractVersion: '1.0.0',
    sdkVersionRange: sdkVersionRange,
    requiredCapabilities: const [Capability.auth],
  );
}
