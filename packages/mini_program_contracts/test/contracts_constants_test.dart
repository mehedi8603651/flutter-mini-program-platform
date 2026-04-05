import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('wire values', () {
    test('capability values stay stable', () {
      expect(Capability.auth.wireValue, 'auth');
      expect(Capability.analytics.wireValue, 'analytics');
      expect(Capability.secureApi.wireValue, 'secure_api');
      expect(Capability.nativeNavigation.wireValue, 'native_navigation');
    });

    test('action names stay stable', () {
      expect(ActionNames.openNativeScreen, 'openNativeScreen');
      expect(ActionNames.callSecureApi, 'callSecureApi');
      expect(ActionNames.trackEvent, 'trackEvent');
    });

    test('error codes stay stable', () {
      expect(
        MiniProgramErrorCodes.manifestParseFailure,
        'manifest_parse_failure',
      );
      expect(
        MiniProgramErrorCodes.unsupportedContractVersion,
        'unsupported_contract_version',
      );
      expect(
        MiniProgramErrorCodes.unsupportedSdkVersion,
        'unsupported_sdk_version',
      );
      expect(
        MiniProgramErrorCodes.unsupportedCapability,
        'unsupported_capability',
      );
      expect(MiniProgramErrorCodes.unknownAction, 'unknown_action');
      expect(
        MiniProgramErrorCodes.invalidResultPayload,
        'invalid_result_payload',
      );
      expect(MiniProgramErrorCodes.backendUnreachable, 'backend_unreachable');
      expect(MiniProgramErrorCodes.backendTimeout, 'backend_timeout');
      expect(
        MiniProgramErrorCodes.secureApiNotAllowlisted,
        'secure_api_not_allowlisted',
      );
    });

    test('cache policy values stay stable', () {
      expect(MiniProgramCacheMode.staleWhileError.name, 'staleWhileError');
      expect(MiniProgramCacheMode.noCache.name, 'noCache');
    });

    test('feature flag keys remain string based', () {
      const FeatureFlagKey key = 'profile_center_v2';
      expect(key, isA<String>());
      expect(FeatureFlagKeys.isValid(key), isTrue);
      expect(FeatureFlagKeys.isValid('   '), isFalse);
    });
  });
}
