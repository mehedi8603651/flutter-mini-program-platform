// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MiniProgramFallback _$MiniProgramFallbackFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_MiniProgramFallback', json, ($checkedConvert) {
      final val = _MiniProgramFallback(
        strategy: $checkedConvert(
          'strategy',
          (v) => $enumDecode(_$MiniProgramFallbackStrategyEnumMap, v),
        ),
        route: $checkedConvert('route', (v) => v as String?),
        message: $checkedConvert('message', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$MiniProgramFallbackToJson(
  _MiniProgramFallback instance,
) => <String, dynamic>{
  'strategy': _$MiniProgramFallbackStrategyEnumMap[instance.strategy]!,
  'route': instance.route,
  'message': instance.message,
};

const _$MiniProgramFallbackStrategyEnumMap = {
  MiniProgramFallbackStrategy.errorView: 'errorView',
  MiniProgramFallbackStrategy.hostRoute: 'hostRoute',
  MiniProgramFallbackStrategy.messageOnly: 'messageOnly',
};

_MiniProgramManifest _$MiniProgramManifestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_MiniProgramManifest', json, ($checkedConvert) {
      final val = _MiniProgramManifest(
        id: $checkedConvert('id', (v) => v as String),
        version: $checkedConvert('version', (v) => v as String),
        entry: $checkedConvert('entry', (v) => v as String),
        contractVersion: $checkedConvert('contractVersion', (v) => v as String),
        sdkVersionRange: $checkedConvert(
          'sdkVersionRange',
          (v) => const SdkVersionRangeConverter().fromJson(v as String),
        ),
        requiredCapabilities: $checkedConvert(
          'requiredCapabilities',
          (v) => (v as List<dynamic>)
              .map((e) => $enumDecode(_$CapabilityEnumMap, e))
              .toList(),
        ),
        featureFlags: $checkedConvert(
          'featureFlags',
          (v) =>
              (v as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <FeatureFlagKey>[],
        ),
        fallback: $checkedConvert(
          'fallback',
          (v) => v == null
              ? null
              : MiniProgramFallback.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MiniProgramManifestToJson(
  _MiniProgramManifest instance,
) => <String, dynamic>{
  'id': instance.id,
  'version': instance.version,
  'entry': instance.entry,
  'contractVersion': instance.contractVersion,
  'sdkVersionRange': const SdkVersionRangeConverter().toJson(
    instance.sdkVersionRange,
  ),
  'requiredCapabilities': instance.requiredCapabilities
      .map((e) => _$CapabilityEnumMap[e]!)
      .toList(),
  'featureFlags': instance.featureFlags,
  'fallback': instance.fallback?.toJson(),
};

const _$CapabilityEnumMap = {
  Capability.auth: 'auth',
  Capability.analytics: 'analytics',
  Capability.secureApi: 'secure_api',
  Capability.nativeNavigation: 'native_navigation',
};
