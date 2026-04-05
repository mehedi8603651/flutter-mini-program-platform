import 'package:freezed_annotation/freezed_annotation.dart';

import 'capability.dart';
import 'feature_flags.dart';
import 'sdk_version.dart';

part 'manifest.freezed.dart';
part 'manifest.g.dart';

/// Supported fallback behaviors when a mini-program cannot continue normally.
@JsonEnum(alwaysCreate: true)
enum MiniProgramFallbackStrategy {
  @JsonValue('errorView')
  errorView,
  @JsonValue('hostRoute')
  hostRoute,
  @JsonValue('messageOnly')
  messageOnly,
}

/// Minimal fallback metadata declared by a mini-program manifest.
@freezed
abstract class MiniProgramFallback with _$MiniProgramFallback {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory MiniProgramFallback({
    required MiniProgramFallbackStrategy strategy,
    String? route,
    String? message,
  }) = _MiniProgramFallback;

  factory MiniProgramFallback.fromJson(Map<String, dynamic> json) =>
      _$MiniProgramFallbackFromJson(json);
}

/// Canonical manifest contract delivered to hosts and the shared SDK.
@freezed
abstract class MiniProgramManifest with _$MiniProgramManifest {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory MiniProgramManifest({
    required String id,
    required String version,
    required String entry,
    required String contractVersion,
    @SdkVersionRangeConverter() required SdkVersionRange sdkVersionRange,
    required List<Capability> requiredCapabilities,
    @Default(<FeatureFlagKey>[]) List<FeatureFlagKey> featureFlags,
    MiniProgramFallback? fallback,
  }) = _MiniProgramManifest;

  factory MiniProgramManifest.fromJson(Map<String, dynamic> json) =>
      _$MiniProgramManifestFromJson(json);
}

extension MiniProgramManifestX on MiniProgramManifest {
  /// Whether the manifest declares the given feature flag key.
  bool hasFeatureFlag(FeatureFlagKey key) => featureFlags.contains(key);

  /// Whether the manifest requires a given host capability.
  bool requiresCapability(Capability capability) =>
      requiredCapabilities.contains(capability);
}
