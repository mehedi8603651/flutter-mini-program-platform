import 'package:json_annotation/json_annotation.dart';

/// Host capabilities that a mini-program can require before rendering.
@JsonEnum()
enum Capability {
  @JsonValue('auth')
  auth,
  @JsonValue('analytics')
  analytics,
  @JsonValue('secure_api')
  secureApi,
  @JsonValue('native_navigation')
  nativeNavigation,
}

extension CapabilityX on Capability {
  /// Stable wire value used in manifests and compatibility checks.
  String get wireValue => switch (this) {
    Capability.auth => 'auth',
    Capability.analytics => 'analytics',
    Capability.secureApi => 'secure_api',
    Capability.nativeNavigation => 'native_navigation',
  };
}
