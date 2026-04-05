import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/actions/host_action_dispatcher.dart';
import 'package:mini_program_sdk/host_bridge.dart';
import 'package:mini_program_sdk/observability/sdk_logger.dart';

void main() {
  group('HostActionDispatcher', () {
    test('routes openNativeScreen to the host bridge', () async {
      final bridge = _FakeHostBridge();
      const logger = DebugPrintSdkLogger();
      final dispatcher = HostActionDispatcher(
        hostBridge: bridge,
        logger: logger,
      );
      final request = HostActionRequest.openNativeScreen(
        requestId: 'req-001',
        payload: const OpenNativeScreenActionPayload(
          route: '/host/profile',
          args: {'source': 'test'},
          expectResult: true,
        ),
      );

      final result = await dispatcher.dispatch(request);

      expect(bridge.openNativeScreenCalls, hasLength(1));
      expect(bridge.openNativeScreenCalls.single.route, '/host/profile');
      expect(result.isSuccess, isTrue);
      expect(result.requestId, 'req-001');
      expect(result.actionName, ActionNames.openNativeScreen);
    });

    test('routes trackEvent to the host bridge', () async {
      final bridge = _FakeHostBridge();
      const logger = DebugPrintSdkLogger();
      final dispatcher = HostActionDispatcher(
        hostBridge: bridge,
        logger: logger,
      );
      final request = HostActionRequest.trackEvent(
        requestId: 'req-002',
        payload: const TrackEventActionPayload(
          name: 'screen_view',
          properties: {'screen': 'profile_center'},
        ),
      );

      final result = await dispatcher.dispatch(request);

      expect(bridge.trackEventCalls, hasLength(1));
      expect(bridge.trackEventCalls.single.name, 'screen_view');
      expect(result.isSuccess, isTrue);
      expect(result.actionName, ActionNames.trackEvent);
    });

    test('routes callSecureApi to the host bridge', () async {
      final bridge = _FakeHostBridge();
      const logger = DebugPrintSdkLogger();
      final dispatcher = HostActionDispatcher(
        hostBridge: bridge,
        logger: logger,
      );
      final request = HostActionRequest.callSecureApi(
        requestId: 'req-002b',
        payload: const CallSecureApiActionPayload(
          endpoint: 'feedback/submit',
          body: <String, dynamic>{'source': 'feedback_form'},
        ),
      );

      final result = await dispatcher.dispatch(request);

      expect(bridge.callSecureApiCalls, hasLength(1));
      expect(bridge.callSecureApiCalls.single.endpoint, 'feedback/submit');
      expect(result.isSuccess, isTrue);
      expect(result.actionName, ActionNames.callSecureApi);
    });

    test('returns unknownAction failure for unsupported actions', () async {
      final bridge = _FakeHostBridge();
      const logger = DebugPrintSdkLogger();
      final dispatcher = HostActionDispatcher(
        hostBridge: bridge,
        logger: logger,
      );
      final request = HostActionRequest(
        requestId: 'req-003',
        actionName: 'unsupportedAction',
        payload: const <String, dynamic>{},
      );

      final result = await dispatcher.dispatch(request);

      expect(result.isFailure, isTrue);
      expect(result.errorCode, MiniProgramErrorCodes.unknownAction);
    });

    test('returns invalidResultPayload when payload decoding fails', () async {
      final bridge = _FakeHostBridge();
      const logger = DebugPrintSdkLogger();
      final dispatcher = HostActionDispatcher(
        hostBridge: bridge,
        logger: logger,
      );
      final request = HostActionRequest(
        requestId: 'req-004',
        actionName: ActionNames.trackEvent,
        payload: const {'properties': 'not-a-map'},
      );

      final result = await dispatcher.dispatch(request);

      expect(result.isFailure, isTrue);
      expect(result.errorCode, MiniProgramErrorCodes.invalidResultPayload);
    });
  });
}

class _FakeHostBridge implements HostBridge {
  final List<OpenNativeScreenActionPayload> openNativeScreenCalls = [];
  final List<CallSecureApiActionPayload> callSecureApiCalls = [];
  final List<TrackEventActionPayload> trackEventCalls = [];

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    openNativeScreenCalls.add(payload);
    return HostActionResult.success(
      message: 'opened',
      data: const {'opened': true},
    );
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    callSecureApiCalls.add(payload);
    return HostActionResult.success(
      message: 'secured',
      data: const {'secured': true},
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    trackEventCalls.add(payload);
    return HostActionResult.success(
      message: 'tracked',
      data: const {'tracked': true},
    );
  }
}
