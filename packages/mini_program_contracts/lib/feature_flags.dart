typedef FeatureFlagKey = String;

/// Utility helpers for feature flag key contract values.
abstract final class FeatureFlagKeys {
  static bool isValid(FeatureFlagKey key) => key.trim().isNotEmpty;
}
