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

/// Contract-level cache behavior for a manifest or screen payload.
///
/// `staleWhileError` means the SDK should prefer fresh network data but may use
/// a previously cached copy when backend loading fails for a retryable reason.
/// `noCache` means the SDK must not persist or reuse cached copies.
@JsonEnum(alwaysCreate: true)
enum MiniProgramCacheMode {
  @JsonValue('staleWhileError')
  staleWhileError,
  @JsonValue('noCache')
  noCache,
}

/// Cache rules declared by a mini-program manifest.
///
/// These rules let the SDK cache low-risk content while keeping sensitive
/// flows, such as secure API entry screens, explicitly non-cacheable.
@freezed
abstract class MiniProgramCachePolicy with _$MiniProgramCachePolicy {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory MiniProgramCachePolicy({
    @Default(MiniProgramCacheMode.staleWhileError)
    MiniProgramCacheMode manifest,
    @Default(MiniProgramCacheMode.staleWhileError)
    MiniProgramCacheMode entryScreen,
  }) = _MiniProgramCachePolicy;

  factory MiniProgramCachePolicy.fromJson(Map<String, dynamic> json) =>
      _$MiniProgramCachePolicyFromJson(json);
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
    @Default(MiniProgramCachePolicy()) MiniProgramCachePolicy cachePolicy,
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

  /// Whether the manifest itself may be reused from stale cache on backend
  /// errors.
  bool get allowsManifestStaleCache =>
      cachePolicy.manifest == MiniProgramCacheMode.staleWhileError;

  /// Whether the entry screen may be reused from stale cache on backend errors.
  bool get allowsEntryScreenStaleCache =>
      cachePolicy.entryScreen == MiniProgramCacheMode.staleWhileError;
}
