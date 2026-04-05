import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import '../app/app_routes.dart';

typedef TrackEventObserver = void Function(TrackEventActionPayload payload);

class HostBridgeImpl implements HostBridge {
  HostBridgeImpl({required this.navigatorKey, this.onTrackEvent});

  final GlobalKey<NavigatorState> navigatorKey;
  final TrackEventObserver? onTrackEvent;
  static const Map<String, String> _routeAliases = <String, String>{
    'profile_editor': AppRoutes.nativeProfileEditor,
    'feedback_follow_up': AppRoutes.nativeFeedbackInbox,
  };
  static const String _feedbackSubmitEndpoint = 'feedback/submit';

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'The host navigator is not available.',
      );
    }

    try {
      final routeName = _routeAliases[payload.route] ?? payload.route;
      final result = await navigator.pushNamed<Object?>(
        routeName,
        arguments: payload.args,
      );

      if (payload.expectResult && result == null) {
        return HostActionResult.cancelled(
          actionName: ActionNames.openNativeScreen,
          message: 'The native screen closed without returning a result.',
          data: <String, dynamic>{'route': routeName},
        );
      }

      return HostActionResult.success(
        actionName: ActionNames.openNativeScreen,
        message: 'Opened native screen "$routeName".',
        data: result == null
            ? <String, dynamic>{'route': routeName}
            : _serializeResult(result),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[super_app_host][ERROR] Failed to open native route "${payload.route}".'
        ' error=$error\n$stackTrace',
      );
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Failed to open native screen "${payload.route}".',
      );
    }
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    final method = payload.method.trim().toUpperCase();
    if (payload.endpoint != _feedbackSubmitEndpoint) {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message:
            'Secure API endpoint "${payload.endpoint}" is not allowlisted in super_app_host.',
      );
    }

    if (method != 'POST') {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message:
            'Secure API endpoint "${payload.endpoint}" only supports POST in super_app_host.',
      );
    }

    debugPrint(
      '[super_app_host][secure_api] $method ${payload.endpoint} ${payload.body}',
    );

    final message = payload.body['message']?.toString().trim();
    return HostActionResult.success(
      actionName: ActionNames.callSecureApi,
      message: 'Submitted secure feedback for super-app review.',
      data: <String, dynamic>{
        'endpoint': payload.endpoint,
        'method': method,
        'status': 'accepted',
        'host': 'super_app_host',
        'ticketId': 'super-feedback-001',
        if (message != null && message.isNotEmpty) 'messagePreview': message,
      },
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    onTrackEvent?.call(payload);
    debugPrint(
      '[super_app_host][analytics] ${payload.name} ${payload.properties}',
    );

    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
      message: 'Tracked event "${payload.name}".',
      data: payload.properties,
    );
  }

  Map<String, dynamic> _serializeResult(Object result) {
    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return result.map((key, value) => MapEntry(key.toString(), value));
    }

    return <String, dynamic>{'result': result.toString()};
  }
}
