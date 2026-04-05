// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdk_version.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SdkVersionRange _$SdkVersionRangeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SdkVersionRange', json, ($checkedConvert) {
      final val = _SdkVersionRange(
        value: $checkedConvert('value', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SdkVersionRangeToJson(_SdkVersionRange instance) =>
    <String, dynamic>{'value': instance.value};
