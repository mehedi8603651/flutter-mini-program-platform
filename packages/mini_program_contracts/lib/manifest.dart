import 'package:freezed_annotation/freezed_annotation.dart';

import 'capability.dart';
import 'feature_flags.dart';
import 'sdk_version.dart';
import 'screen_format.dart';

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

const int _defaultMiniProgramCacheMaxStaleSeconds = 3600;

/// Backward-compatible cache-rule converter for manifest cache policy fields.
///
/// Older manifests may still serialize cache policy values as simple strings,
/// for example `"staleWhileError"`. Newer manifests may use the object form
/// with a mode plus an explicit `maxStaleSeconds` limit.
class MiniProgramCacheRuleConverter
    implements JsonConverter<MiniProgramCacheRule, Object?> {
  const MiniProgramCacheRuleConverter();

  @override
  MiniProgramCacheRule fromJson(Object? json) {
    if (json == null) {
      return const MiniProgramCacheRule();
    }

    if (json is String) {
      return MiniProgramCacheRule(mode: _cacheModeFromWireValue(json));
    }

    if (json is Map<String, dynamic>) {
      return MiniProgramCacheRule.fromJson(json);
    }

    if (json is Map) {
      return MiniProgramCacheRule.fromJson(
        json.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    throw const FormatException('Expected a cache rule string or object.');
  }

  @override
  Object toJson(MiniProgramCacheRule object) => object.toJson();

  MiniProgramCacheMode _cacheModeFromWireValue(String value) {
    switch (value) {
      case 'staleWhileError':
        return MiniProgramCacheMode.staleWhileError;
      case 'noCache':
        return MiniProgramCacheMode.noCache;
      default:
        throw FormatException('Unsupported cache mode "$value".');
    }
  }
}

/// Cache rules declared by a mini-program manifest for one payload class.
///
/// `maxStaleSeconds` bounds how long a stale cached copy may be reused after a
/// retryable backend failure. When omitted, the SDK falls back to the default
/// contract value of 3600 seconds.
@freezed
abstract class MiniProgramCacheRule with _$MiniProgramCacheRule {
  @JsonSerializable(checked: true, explicitToJson: true)
  @Assert(
    'maxStaleSeconds == null || maxStaleSeconds > 0',
    'maxStaleSeconds must be greater than zero when provided.',
  )
  const factory MiniProgramCacheRule({
    @Default(MiniProgramCacheMode.staleWhileError) MiniProgramCacheMode mode,
    @JsonKey(includeIfNull: false) int? maxStaleSeconds,
  }) = _MiniProgramCacheRule;

  factory MiniProgramCacheRule.fromJson(Map<String, dynamic> json) =>
      _$MiniProgramCacheRuleFromJson(json);
}

/// Cache rules declared by a mini-program manifest.
///
/// These rules let the SDK cache low-risk content while keeping sensitive
/// flows, such as secure API entry screens, explicitly non-cacheable.
@freezed
abstract class MiniProgramCachePolicy with _$MiniProgramCachePolicy {
  @JsonSerializable(checked: true, explicitToJson: true)
  const factory MiniProgramCachePolicy({
    @MiniProgramCacheRuleConverter()
    @Default(MiniProgramCacheRule())
    MiniProgramCacheRule manifest,
    @MiniProgramCacheRuleConverter()
    @Default(MiniProgramCacheRule())
    MiniProgramCacheRule entryScreen,
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
  @Assert(
    "screenFormat != 'mp' || screenSchemaVersion != null",
    'screenSchemaVersion is required when screenFormat is "mp".',
  )
  @Assert(
    'screenSchemaVersion == null || screenSchemaVersion > 0',
    'screenSchemaVersion must be greater than zero when provided.',
  )
  const factory MiniProgramManifest({
    required String id,
    required String version,
    required String entry,
    required String contractVersion,
    @SdkVersionRangeConverter() required SdkVersionRange sdkVersionRange,
    @CapabilityIdListConverter()
    required List<CapabilityId> requiredCapabilities,
    @MiniProgramScreenFormatConverter()
    @Default(MiniProgramScreenFormats.mp)
    MiniProgramScreenFormat screenFormat,
    @Default(1) int? screenSchemaVersion,
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
  bool requiresCapability(Object? capability) =>
      requiredCapabilities.contains(CapabilityIds.normalizeObject(capability));

  /// Whether this manifest points at an Mp JSON screen document.
  bool get usesMpScreenFormat => screenFormat == MiniProgramScreenFormats.mp;

  /// Whether the manifest itself may be reused from stale cache on backend
  /// errors.
  bool get allowsManifestStaleCache => cachePolicy.manifest.allowsStaleCache;

  /// Whether the entry screen may be reused from stale cache on backend errors.
  bool get allowsEntryScreenStaleCache =>
      cachePolicy.entryScreen.allowsStaleCache;

  /// Maximum allowed stale age for manifest reuse after retryable failures.
  Duration get manifestMaxStaleAge => cachePolicy.manifest.effectiveMaxStaleAge;

  /// Maximum allowed stale age for entry-screen reuse after retryable failures.
  Duration get entryScreenMaxStaleAge =>
      cachePolicy.entryScreen.effectiveMaxStaleAge;
}

extension MiniProgramCacheRuleX on MiniProgramCacheRule {
  /// Whether stale cached content may be reused for this payload.
  bool get allowsStaleCache => mode == MiniProgramCacheMode.staleWhileError;

  /// Contract-defined maximum stale age for retryable offline fallback.
  Duration get effectiveMaxStaleAge => Duration(
    seconds: maxStaleSeconds ?? _defaultMiniProgramCacheMaxStaleSeconds,
  );
}
