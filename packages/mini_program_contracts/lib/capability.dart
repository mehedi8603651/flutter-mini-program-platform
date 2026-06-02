// ignore_for_file: deprecated_member_use_from_same_package

import 'package:json_annotation/json_annotation.dart';

/// Stable wire ID for a host capability.
typedef CapabilityId = String;

/// Standard capability IDs used by published mini-program manifests.
abstract final class CapabilityIds {
  /// Host can provide publisher-owned or host-owned authentication support.
  static const CapabilityId auth = 'auth';

  /// Host can receive analytics events from the mini-program runtime.
  static const CapabilityId analytics = 'analytics';

  /// Host can proxy allowlisted secure API calls.
  static const CapabilityId secureApi = 'secure_api';

  /// Host can open agreed native routes from mini-program actions.
  static const CapabilityId nativeNavigation = 'native_navigation';

  /// Host opted into video playback feature support.
  static const CapabilityId mediaVideo = 'media.video';

  /// Host opted into PDF or document viewing feature support.
  static const CapabilityId documentPdf = 'document.pdf';

  /// Host opted into embedded browser or webview feature support.
  static const CapabilityId browserWebview = 'browser.webview';

  /// Stable ordering used by scaffolds and human-readable output.
  static const List<CapabilityId> standardValues = <CapabilityId>[
    auth,
    analytics,
    secureApi,
    nativeNavigation,
    mediaVideo,
    documentPdf,
    browserWebview,
  ];

  static final RegExp _capabilityIdPattern = RegExp(
    r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
  );

  /// Returns whether [value] is a valid capability ID.
  static bool isValid(CapabilityId value) {
    final normalized = value.trim();
    return normalized.isNotEmpty && _capabilityIdPattern.hasMatch(normalized);
  }

  /// Normalizes and validates a string capability ID.
  static CapabilityId normalize(CapabilityId value) {
    final normalized = value.trim();
    if (!isValid(normalized)) {
      throw FormatException('Invalid capability ID "$value".');
    }
    return normalized;
  }

  /// Normalizes either a new string ID or a deprecated [Capability] value.
  static CapabilityId normalizeObject(Object? value) {
    if (value is Capability) {
      return value.wireValue;
    }
    if (value is String) {
      return normalize(value);
    }
    throw FormatException('Expected a capability ID string, got "$value".');
  }

  /// Normalizes a list of capability values for constructors and JSON.
  static List<CapabilityId> normalizeAll(Iterable<Object?> values) =>
      values.map(normalizeObject).toList(growable: false);
}

/// JSON converter that validates manifest capability IDs.
class CapabilityIdListConverter
    implements JsonConverter<List<CapabilityId>, Object?> {
  /// Creates a capability ID list converter.
  const CapabilityIdListConverter();

  @override
  List<CapabilityId> fromJson(Object? json) {
    if (json == null) {
      return const <CapabilityId>[];
    }
    if (json is Iterable) {
      return CapabilityIds.normalizeAll(json);
    }
    throw const FormatException('Expected a capability ID array.');
  }

  @override
  Object toJson(List<CapabilityId> object) =>
      CapabilityIds.normalizeAll(object);
}

/// Deprecated enum kept for existing source compatibility.
///
/// New code should use [CapabilityId] strings and [CapabilityIds].
@Deprecated('Use CapabilityId strings and CapabilityIds instead.')
@JsonEnum()
enum Capability {
  /// Authentication capability.
  @JsonValue('auth')
  auth,

  /// Analytics capability.
  @JsonValue('analytics')
  analytics,

  /// Secure API capability.
  @JsonValue('secure_api')
  secureApi,

  /// Native navigation capability.
  @JsonValue('native_navigation')
  nativeNavigation,
}

/// Deprecated compatibility helpers for old enum-based code.
@Deprecated('Use CapabilityId strings and CapabilityIds instead.')
extension CapabilityX on Capability {
  /// Stable wire value used in manifests and compatibility checks.
  String get wireValue => switch (this) {
    Capability.auth => 'auth',
    Capability.analytics => 'analytics',
    Capability.secureApi => 'secure_api',
    Capability.nativeNavigation => 'native_navigation',
  };
}
