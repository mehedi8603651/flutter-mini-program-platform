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
      expect(MiniProgramErrorCodes.actionNotFound, 'action_not_found');
      expect(
        MiniProgramErrorCodes.actionCallLimitExceeded,
        'action_call_limit_exceeded',
      );
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
        MiniProgramErrorCodes.secureApiNotAllowlisted,
        'secure_api_not_allowlisted',
      );
      expect(MiniProgramErrorCodes.stateInvalidValue, 'state_invalid_value');
      expect(MiniProgramErrorCodes.stateLimitExceeded, 'state_limit_exceeded');
      expect(
        MiniProgramErrorCodes.stateIndexOutOfRange,
        'state_index_out_of_range',
      );
      expect(
        MiniProgramErrorCodes.conditionInvalidValue,
        'condition_invalid_value',
      );
      expect(
        MiniProgramErrorCodes.mathInvalidExpression,
        'math_invalid_expression',
      );
      expect(MiniProgramErrorCodes.mathDivisionByZero, 'math_division_by_zero');
      expect(MiniProgramErrorCodes.mathDomainError, 'math_domain_error');
      expect(
        MiniProgramErrorCodes.mathResultNotFinite,
        'math_result_not_finite',
      );
      expect(
        MiniProgramErrorCodes.mathComplexityExceeded,
        'math_complexity_exceeded',
      );
      expect(MiniProgramErrorCodes.mathInvalidOperand, 'math_invalid_operand');
      expect(MiniProgramErrorCodes.mathInvalidRange, 'math_invalid_range');
      expect(MiniProgramErrorCodes.mathEmptyValues, 'math_empty_values');
    });

    test('Publisher API header and error values stay stable', () {
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
