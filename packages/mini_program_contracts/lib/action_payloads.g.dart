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
