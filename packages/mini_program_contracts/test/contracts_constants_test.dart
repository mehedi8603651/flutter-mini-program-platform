// ignore_for_file: deprecated_member_use_from_same_package

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('wire values', () {
    test('capability values stay stable', () {
      expect(CapabilityIds.auth, 'auth');
      expect(CapabilityIds.analytics, 'analytics');
      expect(CapabilityIds.secureApi, 'secure_api');
      expect(CapabilityIds.nativeNavigation, 'native_navigation');
      expect(CapabilityIds.mediaVideo, 'media.video');
      expect(CapabilityIds.documentPdf, 'document.pdf');
      expect(CapabilityIds.browserWebview, 'browser.webview');
      expect(Capability.auth.wireValue, 'auth');
      expect(Capability.analytics.wireValue, 'analytics');
      expect(Capability.secureApi.wireValue, 'secure_api');
      expect(Capability.nativeNavigation.wireValue, 'native_navigation');
      expect(CapabilityIds.isValid('media.video'), isTrue);
      expect(CapabilityIds.isValid('secure_api'), isTrue);
      expect(CapabilityIds.isValid(''), isFalse);
      expect(CapabilityIds.isValid('Media.Video'), isFalse);
    });

    test('screen format values stay stable', () {
      expect(MiniProgramScreenFormats.stac, 'stac');
      expect(MiniProgramScreenFormats.mp, 'mp');
    });

    test('action names stay stable', () {
      expect(ActionNames.openNativeScreen, 'openNativeScreen');
      expect(ActionNames.callSecureApi, 'callSecureApi');
      expect(ActionNames.trackEvent, 'trackEvent');
      expect(ActionNames.openMiniProgramScreen, 'openMiniProgramScreen');
      expect(ActionNames.replaceMiniProgramScreen, 'replaceMiniProgramScreen');
      expect(ActionNames.popMiniProgramScreen, 'popMiniProgramScreen');
      expect(ActionNames.resetMiniProgramStack, 'resetMiniProgramStack');
      expect(ActionNames.popToMiniProgramRoot, 'popToMiniProgramRoot');
      expect(ActionNames.popToMiniProgramScreen, 'popToMiniProgramScreen');
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
      expect(MiniProgramErrorCodes.screenNotFound, 'screen_not_found');
      expect(MiniProgramErrorCodes.screenNotInStack, 'screen_not_in_stack');
      expect(MiniProgramErrorCodes.unknownAction, 'unknown_action');
      expect(
        MiniProgramErrorCodes.invalidResultPayload,
        'invalid_result_payload',
      );
      expect(MiniProgramErrorCodes.backendUnreachable, 'backend_unreachable');
      expect(MiniProgramErrorCodes.backendTimeout, 'backend_timeout');
      expect(
        MiniProgramErrorCodes.endpointNotConfigured,
        'endpoint_not_configured',
      );
      expect(
        MiniProgramErrorCodes.accessKeyNotConfigured,
        'access_key_not_configured',
      );
      expect(MiniProgramErrorCodes.accessKeyMissing, 'access_key_missing');
      expect(MiniProgramErrorCodes.accessKeyInvalid, 'access_key_invalid');
      expect(
        MiniProgramErrorCodes.secureApiNotAllowlisted,
        'secure_api_not_allowlisted',
      );
    });

    test('publisher backend header and error values stay stable', () {
      expect(
        MiniProgramPublisherBackendHeaders.accessKey,
        'x-mini-program-access-key',
      );
      expect(MiniProgramPublisherBackendHeaders.appId, 'x-mini-program-app-id');
      expect(
        MiniProgramPublisherBackendHeaders.hostApp,
        'x-mini-program-host-app',
      );
      expect(
        MiniProgramPublisherBackendHeaders.hostVersion,
        'x-mini-program-host-version',
      );
      expect(
        MiniProgramPublisherBackendHeaders.sdkVersion,
        'x-mini-program-sdk-version',
      );
      expect(MiniProgramPublisherBackendHeaders.authorization, 'authorization');
      expect(
        MiniProgramPublisherBackendHeaders.requestId,
        'x-mini-program-request-id',
      );
      expect(
        MiniProgramPublisherBackendHeaders.contractVersion,
        'x-mini-program-backend-contract-version',
      );
      expect(
        MiniProgramPublisherBackendErrorCodes.unreachable,
        'publisher_backend_unreachable',
      );
      expect(
        MiniProgramPublisherBackendErrorCodes.unexpectedStatus,
        'publisher_backend_unexpected_status',
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
