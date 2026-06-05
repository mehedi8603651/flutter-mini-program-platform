// ignore_for_file: deprecated_member_use_from_same_package

import 'package:json_annotation/json_annotation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('MiniProgramManifest', () {
    test('round-trips through json', () {
      final manifest = MiniProgramManifest(
        id: 'profile_center',
        version: '1.2.3',
        entry: 'screens/profile_home',
        contractVersion: '1.0.0',
        sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
        requiredCapabilities: const [
          CapabilityIds.auth,
          CapabilityIds.secureApi,
          CapabilityIds.nativeNavigation,
        ],
        screenFormat: MiniProgramScreenFormats.mp,
        screenSchemaVersion: 1,
        featureFlags: const ['profile_center_v2'],
        cachePolicy: const MiniProgramCachePolicy(
          manifest: MiniProgramCacheRule(
            mode: MiniProgramCacheMode.staleWhileError,
            maxStaleSeconds: 86400,
          ),
          entryScreen: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
        ),
        fallback: const MiniProgramFallback(
          strategy: MiniProgramFallbackStrategy.hostRoute,
          route: '/mini-program-unavailable',
          message: 'Profile center is unavailable on this host.',
        ),
      );

      final json = manifest.toJson();

      expect(json['sdkVersionRange'], '>=1.0.0 <2.0.0');
      expect(json['requiredCapabilities'], [
        'auth',
        'secure_api',
        'native_navigation',
      ]);
      expect(json['screenFormat'], 'mp');
      expect(json['screenSchemaVersion'], 1);
      expect(json['featureFlags'], ['profile_center_v2']);
      expect(json['cachePolicy'], {
        'manifest': {'mode': 'staleWhileError', 'maxStaleSeconds': 86400},
        'entryScreen': {'mode': 'noCache'},
      });
      expect(json['fallback'], {
        'strategy': 'hostRoute',
        'route': '/mini-program-unavailable',
        'message': 'Profile center is unavailable on this host.',
      });

      final decoded = MiniProgramManifest.fromJson(json);

      expect(decoded, manifest);
      expect(decoded.hasFeatureFlag('profile_center_v2'), isTrue);
      expect(decoded.requiresCapability(CapabilityIds.auth), isTrue);
      expect(decoded.requiresCapability(Capability.auth), isTrue);
      expect(decoded.requiresCapability(CapabilityIds.analytics), isFalse);
      expect(decoded.usesMpScreenFormat, isTrue);
      expect(decoded.allowsManifestStaleCache, isTrue);
      expect(decoded.allowsEntryScreenStaleCache, isFalse);
      expect(decoded.manifestMaxStaleAge, const Duration(days: 1));
      expect(decoded.entryScreenMaxStaleAge, const Duration(hours: 1));
    });

    test('decodes manifests without screenFormat as Mp', () {
      final manifest = MiniProgramManifest.fromJson({
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth'],
      });

      expect(manifest.screenFormat, MiniProgramScreenFormats.mp);
      expect(manifest.screenSchemaVersion, 1);
      expect(manifest.usesMpScreenFormat, isTrue);
    });

    test('round-trips unknown but valid capability IDs', () {
      final manifest = MiniProgramManifest.fromJson({
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth', 'media.video'],
      });

      expect(manifest.requiredCapabilities, [
        CapabilityIds.auth,
        CapabilityIds.mediaVideo,
      ]);
      expect(manifest.toJson()['requiredCapabilities'], [
        'auth',
        'media.video',
      ]);
    });

    test('rejects malformed capability values during decode', () {
      final json = {
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth', 'Camera'],
      };

      expect(
        () => MiniProgramManifest.fromJson(json),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('defaults Mp manifests without a screen schema version to v1', () {
      final json = {
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth'],
        'screenFormat': 'mp',
      };

      final manifest = MiniProgramManifest.fromJson(json);

      expect(manifest.screenFormat, MiniProgramScreenFormats.mp);
      expect(manifest.screenSchemaVersion, 1);
    });

    test('rejects non-positive screen schema versions', () {
      final json = {
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth'],
        'screenFormat': 'mp',
        'screenSchemaVersion': 0,
      };

      expect(() => MiniProgramManifest.fromJson(json), throwsA(anything));
    });

    test('preserves unknown screen format strings', () {
      final manifest = MiniProgramManifest.fromJson({
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth'],
        'screenFormat': 'future',
      });

      expect(manifest.screenFormat, 'future');
      expect(manifest.usesMpScreenFormat, isFalse);
    });

    test('rejects malformed manifest payloads', () {
      final json = {
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'requiredCapabilities': ['auth'],
      };

      expect(
        () => MiniProgramManifest.fromJson(json),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test(
      'defaults cache policy to staleWhileError for manifest and entry screen',
      () {
        final manifest = MiniProgramManifest.fromJson({
          'id': 'profile_center',
          'version': '1.2.3',
          'entry': 'screens/profile_home',
          'contractVersion': '1.0.0',
          'sdkVersionRange': '>=1.0.0 <2.0.0',
          'requiredCapabilities': ['auth'],
        });

        expect(
          manifest.cachePolicy.manifest.mode,
          MiniProgramCacheMode.staleWhileError,
        );
        expect(
          manifest.cachePolicy.entryScreen.mode,
          MiniProgramCacheMode.staleWhileError,
        );
        expect(manifest.manifestMaxStaleAge, const Duration(hours: 1));
        expect(manifest.entryScreenMaxStaleAge, const Duration(hours: 1));
      },
    );

    test('decodes legacy string cache policy values compatibly', () {
      final manifest = MiniProgramManifest.fromJson({
        'id': 'profile_center',
        'version': '1.2.3',
        'entry': 'screens/profile_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': ['auth'],
        'cachePolicy': {
          'manifest': 'staleWhileError',
          'entryScreen': 'noCache',
        },
      });

      expect(
        manifest.cachePolicy.manifest.mode,
        MiniProgramCacheMode.staleWhileError,
      );
      expect(
        manifest.cachePolicy.entryScreen.mode,
        MiniProgramCacheMode.noCache,
      );
      expect(manifest.manifestMaxStaleAge, const Duration(hours: 1));
    });
  });

  group('payload models', () {
    test(
      'action payloads and host action requests round-trip through json',
      () {
        final openNativeScreenPayload = OpenNativeScreenActionPayload(
          route: '/recharge/confirm',
          args: const {'planId': 'gold', 'source': 'mini_program'},
          expectResult: true,
        );
        final trackEventPayload = TrackEventActionPayload(
          name: 'recharge_started',
          properties: const {'miniProgramId': 'recharge', 'step': 1},
        );
        final callSecureApiPayload = CallSecureApiActionPayload(
          endpoint: 'feedback/submit',
          body: const {'source': 'feedback_form'},
        );
        const openMiniProgramScreenPayload = OpenMiniProgramScreenActionPayload(
          screenId: 'recharge_plan',
        );
        const resetMiniProgramStackPayload = ResetMiniProgramStackActionPayload(
          screenId: 'recharge_summary',
        );
        const replaceMiniProgramScreenPayload =
            ReplaceMiniProgramScreenActionPayload(screenId: 'recharge_confirm');
        const popMiniProgramScreenPayload = PopMiniProgramScreenActionPayload();
        const popToMiniProgramRootPayload = PopToMiniProgramRootActionPayload();
        const popToMiniProgramScreenPayload =
            PopToMiniProgramScreenActionPayload(screenId: 'recharge_plan');
        final openNativeScreenRequest = HostActionRequest.openNativeScreen(
          requestId: 'req-001',
          payload: openNativeScreenPayload,
        );
        final callSecureApiRequest = HostActionRequest.callSecureApi(
          requestId: 'req-001b',
          payload: callSecureApiPayload,
        );
        final trackEventRequest = HostActionRequest.trackEvent(
          requestId: 'req-002',
          payload: trackEventPayload,
        );

        expect(
          OpenNativeScreenActionPayload.fromJson(
            openNativeScreenPayload.toJson(),
          ),
          openNativeScreenPayload,
        );
        expect(
          CallSecureApiActionPayload.fromJson(callSecureApiPayload.toJson()),
          callSecureApiPayload,
        );
        expect(
          TrackEventActionPayload.fromJson(trackEventPayload.toJson()),
          trackEventPayload,
        );
        expect(
          OpenMiniProgramScreenActionPayload.fromJson(
            openMiniProgramScreenPayload.toJson(),
          ),
          openMiniProgramScreenPayload,
        );
        expect(
          ResetMiniProgramStackActionPayload.fromJson(
            resetMiniProgramStackPayload.toJson(),
          ),
          resetMiniProgramStackPayload,
        );
        expect(
          ReplaceMiniProgramScreenActionPayload.fromJson(
            replaceMiniProgramScreenPayload.toJson(),
          ),
          replaceMiniProgramScreenPayload,
        );
        expect(
          PopMiniProgramScreenActionPayload.fromJson(
            popMiniProgramScreenPayload.toJson(),
          ),
          popMiniProgramScreenPayload,
        );
        expect(
          PopToMiniProgramRootActionPayload.fromJson(
            popToMiniProgramRootPayload.toJson(),
          ),
          popToMiniProgramRootPayload,
        );
        expect(
          PopToMiniProgramScreenActionPayload.fromJson(
            popToMiniProgramScreenPayload.toJson(),
          ),
          popToMiniProgramScreenPayload,
        );
        expect(
          HostActionRequest.fromJson(openNativeScreenRequest.toJson()),
          openNativeScreenRequest,
        );
        expect(
          HostActionRequest.fromJson(callSecureApiRequest.toJson()),
          callSecureApiRequest,
        );
        expect(
          HostActionRequest.fromJson(trackEventRequest.toJson()),
          trackEventRequest,
        );
        expect(
          openNativeScreenRequest.actionName,
          ActionNames.openNativeScreen,
        );
        expect(callSecureApiRequest.actionName, ActionNames.callSecureApi);
        expect(trackEventRequest.actionName, ActionNames.trackEvent);
        expect(ActionNames.openMiniProgramScreen, 'openMiniProgramScreen');
        expect(
          ActionNames.replaceMiniProgramScreen,
          'replaceMiniProgramScreen',
        );
        expect(ActionNames.popMiniProgramScreen, 'popMiniProgramScreen');
        expect(ActionNames.resetMiniProgramStack, 'resetMiniProgramStack');
        expect(ActionNames.popToMiniProgramRoot, 'popToMiniProgramRoot');
        expect(ActionNames.popToMiniProgramScreen, 'popToMiniProgramScreen');
      },
    );

    test('result payloads round-trip through json', () {
      final hostActionResult = HostActionResult.success(
        requestId: 'req-001',
        actionName: ActionNames.openNativeScreen,
        message: 'Native screen completed.',
        data: const {'confirmed': true},
      );
      final failedResult = HostActionResult.failed(
        requestId: 'req-002',
        actionName: ActionNames.trackEvent,
        message: 'Analytics provider unavailable.',
        errorCode: MiniProgramErrorCodes.invalidResultPayload,
      );

      expect(
        HostActionResult.fromJson(hostActionResult.toJson()),
        hostActionResult,
      );
      expect(hostActionResult.isSuccess, isTrue);
      expect(hostActionResult.isFailure, isFalse);
      expect(hostActionResult.toJson()['action'], ActionNames.openNativeScreen);
      expect(failedResult.isFailure, isTrue);
      expect(
        failedResult.errorCode,
        MiniProgramErrorCodes.invalidResultPayload,
      );
    });
  });
}
