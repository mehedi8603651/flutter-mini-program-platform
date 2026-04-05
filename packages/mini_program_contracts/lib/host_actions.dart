import 'package:freezed_annotation/freezed_annotation.dart';

import 'action_names.dart';
import 'action_payloads.dart';

part 'host_actions.freezed.dart';
part 'host_actions.g.dart';

/// Terminal outcome states for a host-dispatched action.
@JsonEnum(alwaysCreate: true)
enum HostActionStatus {
  @JsonValue('success')
  success,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('failed')
  failed,
}

/// Standard request envelope sent from the SDK to a host bridge action handler.
///
/// The `action` field is the stable wire name, while `payload` stays JSON-shaped
/// so the SDK and host can validate and deserialize it into the appropriate
/// typed action payload model.
@freezed
abstract class HostActionRequest with _$HostActionRequest {
  const HostActionRequest._();

  @JsonSerializable(checked: true, explicitToJson: true)
  const factory HostActionRequest({
    String? requestId,
    @JsonKey(name: 'action') required String actionName,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
  }) = _HostActionRequest;

  factory HostActionRequest.fromJson(Map<String, dynamic> json) =>
      _$HostActionRequestFromJson(json);

  factory HostActionRequest.openNativeScreen({
    String? requestId,
    required OpenNativeScreenActionPayload payload,
  }) => HostActionRequest(
    requestId: requestId,
    actionName: ActionNames.openNativeScreen,
    payload: payload.toJson(),
  );

  factory HostActionRequest.trackEvent({
    String? requestId,
    required TrackEventActionPayload payload,
  }) => HostActionRequest(
    requestId: requestId,
    actionName: ActionNames.trackEvent,
    payload: payload.toJson(),
  );
}

/// Standard result envelope returned by the host bridge after handling an action.
///
/// `requestId` and `action` allow correlation with the original request.
/// `errorCode` is only expected on failures and should use a stable contract
/// value whenever the failure maps to a known platform condition.
@freezed
abstract class HostActionResult with _$HostActionResult {
  const HostActionResult._();

  @JsonSerializable(checked: true, explicitToJson: true)
  const factory HostActionResult({
    String? requestId,
    @JsonKey(name: 'action') String? actionName,
    required HostActionStatus status,
    String? message,
    String? errorCode,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
  }) = _HostActionResult;

  factory HostActionResult.fromJson(Map<String, dynamic> json) =>
      _$HostActionResultFromJson(json);

  factory HostActionResult.success({
    String? requestId,
    String? actionName,
    String? message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) => HostActionResult(
    requestId: requestId,
    actionName: actionName,
    status: HostActionStatus.success,
    message: message,
    data: data,
  );

  factory HostActionResult.cancelled({
    String? requestId,
    String? actionName,
    String? message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) => HostActionResult(
    requestId: requestId,
    actionName: actionName,
    status: HostActionStatus.cancelled,
    message: message,
    data: data,
  );

  factory HostActionResult.failed({
    String? requestId,
    String? actionName,
    String? message,
    String? errorCode,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) => HostActionResult(
    requestId: requestId,
    actionName: actionName,
    status: HostActionStatus.failed,
    message: message,
    errorCode: errorCode,
    data: data,
  );
}

extension HostActionResultX on HostActionResult {
  /// Whether the host reports successful completion.
  bool get isSuccess => status == HostActionStatus.success;

  /// Whether the user or host cancelled the operation without success.
  bool get isCancelled => status == HostActionStatus.cancelled;

  /// Whether the operation failed.
  bool get isFailure => status == HostActionStatus.failed;
}
