import 'package:mini_program_contracts/mini_program_contracts.dart';

/// SDK-local Stac action model for routing remote JSON host actions to the bridge.
class SdkHostAction {
  const SdkHostAction({
    required this.actionName,
    this.requestId,
    this.payload = const <String, dynamic>{},
  });

  static const String stacActionType = 'hostAction';

  final String actionName;
  final String? requestId;
  final Map<String, dynamic> payload;

  factory SdkHostAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['actionType'];
    if (actionType != stacActionType) {
      throw FormatException(
        'Expected actionType "$stacActionType", got "$actionType".',
      );
    }

    final actionName = json['action'];
    if (actionName is! String || actionName.trim().isEmpty) {
      throw const FormatException(
        'Host action JSON must contain a non-empty "action" string.',
      );
    }

    final requestId = json['requestId'];
    if (requestId != null && requestId is! String) {
      throw const FormatException(
        '"requestId" must be a string when provided.',
      );
    }

    final payload = json['payload'];
    if (payload != null && payload is! Map) {
      throw const FormatException('"payload" must be a JSON object.');
    }

    return SdkHostAction(
      actionName: actionName,
      requestId: requestId as String?,
      payload: payload == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(payload as Map),
    );
  }

  HostActionRequest toRequest() {
    return HostActionRequest(
      requestId: requestId,
      actionName: actionName,
      payload: payload,
    );
  }
}
