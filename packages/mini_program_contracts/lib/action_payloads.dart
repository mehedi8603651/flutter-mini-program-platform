import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_payloads.freezed.dart';
part 'action_payloads.g.dart';

/// Payload for a host-controlled native navigation request.
@freezed
abstract class OpenNativeScreenActionPayload
    with _$OpenNativeScreenActionPayload {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory OpenNativeScreenActionPayload({
    required String route,
    @Default(<String, dynamic>{}) Map<String, dynamic> args,
    @Default(false) bool expectResult,
  }) = _OpenNativeScreenActionPayload;

  factory OpenNativeScreenActionPayload.fromJson(Map<String, dynamic> json) =>
      _$OpenNativeScreenActionPayloadFromJson(json);
}

/// Payload for a host-controlled secure API operation.
@freezed
abstract class CallSecureApiActionPayload with _$CallSecureApiActionPayload {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory CallSecureApiActionPayload({
    required String endpoint,
    @Default('POST') String method,
    @Default(<String, dynamic>{}) Map<String, dynamic> body,
  }) = _CallSecureApiActionPayload;

  factory CallSecureApiActionPayload.fromJson(Map<String, dynamic> json) =>
      _$CallSecureApiActionPayloadFromJson(json);
}

/// Payload for a host-controlled analytics event dispatch.
@freezed
abstract class TrackEventActionPayload with _$TrackEventActionPayload {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory TrackEventActionPayload({
    required String name,
    @Default(<String, dynamic>{}) Map<String, dynamic> properties,
  }) = _TrackEventActionPayload;

  factory TrackEventActionPayload.fromJson(Map<String, dynamic> json) =>
      _$TrackEventActionPayloadFromJson(json);
}
