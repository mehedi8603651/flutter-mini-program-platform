// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_payloads.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenNativeScreenActionPayload _$OpenNativeScreenActionPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_OpenNativeScreenActionPayload', json, ($checkedConvert) {
  final val = _OpenNativeScreenActionPayload(
    route: $checkedConvert('route', (v) => v as String),
    args: $checkedConvert(
      'args',
      (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
    ),
    expectResult: $checkedConvert('expectResult', (v) => v as bool? ?? false),
  );
  return val;
});

Map<String, dynamic> _$OpenNativeScreenActionPayloadToJson(
  _OpenNativeScreenActionPayload instance,
) => <String, dynamic>{
  'route': instance.route,
  'args': instance.args,
  'expectResult': instance.expectResult,
};

_CallSecureApiActionPayload _$CallSecureApiActionPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_CallSecureApiActionPayload', json, ($checkedConvert) {
  final val = _CallSecureApiActionPayload(
    endpoint: $checkedConvert('endpoint', (v) => v as String),
    method: $checkedConvert('method', (v) => v as String? ?? 'POST'),
    body: $checkedConvert(
      'body',
      (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
    ),
  );
  return val;
});

Map<String, dynamic> _$CallSecureApiActionPayloadToJson(
  _CallSecureApiActionPayload instance,
) => <String, dynamic>{
  'endpoint': instance.endpoint,
  'method': instance.method,
  'body': instance.body,
};

_TrackEventActionPayload _$TrackEventActionPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_TrackEventActionPayload', json, ($checkedConvert) {
  final val = _TrackEventActionPayload(
    name: $checkedConvert('name', (v) => v as String),
    properties: $checkedConvert(
      'properties',
      (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
    ),
  );
  return val;
});

Map<String, dynamic> _$TrackEventActionPayloadToJson(
  _TrackEventActionPayload instance,
) => <String, dynamic>{
  'name': instance.name,
  'properties': instance.properties,
};
