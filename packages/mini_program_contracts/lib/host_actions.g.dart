// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_actions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HostActionRequest _$HostActionRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HostActionRequest', json, ($checkedConvert) {
      final val = _HostActionRequest(
        requestId: $checkedConvert('requestId', (v) => v as String?),
        actionName: $checkedConvert('action', (v) => v as String),
        payload: $checkedConvert(
          'payload',
          (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
        ),
      );
      return val;
    }, fieldKeyMap: const {'actionName': 'action'});

Map<String, dynamic> _$HostActionRequestToJson(_HostActionRequest instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'action': instance.actionName,
      'payload': instance.payload,
    };

_HostActionResult _$HostActionResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_HostActionResult', json, ($checkedConvert) {
      final val = _HostActionResult(
        requestId: $checkedConvert('requestId', (v) => v as String?),
        actionName: $checkedConvert('action', (v) => v as String?),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$HostActionStatusEnumMap, v),
        ),
        message: $checkedConvert('message', (v) => v as String?),
        errorCode: $checkedConvert('errorCode', (v) => v as String?),
        data: $checkedConvert(
          'data',
          (v) => v as Map<String, dynamic>? ?? const <String, dynamic>{},
        ),
      );
      return val;
    }, fieldKeyMap: const {'actionName': 'action'});

Map<String, dynamic> _$HostActionResultToJson(_HostActionResult instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'action': instance.actionName,
      'status': _$HostActionStatusEnumMap[instance.status]!,
      'message': instance.message,
      'errorCode': instance.errorCode,
      'data': instance.data,
    };

const _$HostActionStatusEnumMap = {
  HostActionStatus.success: 'success',
  HostActionStatus.cancelled: 'cancelled',
  HostActionStatus.failed: 'failed',
};
