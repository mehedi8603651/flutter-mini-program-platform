import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Evaluates whether a manifest-declared feature flag is enabled for the host.
abstract interface class FeatureFlagEvaluator {
  bool isEnabled(FeatureFlagKey key);
}

/// Default evaluator used by the SDK when the host does not provide one.
class AllowAllFeatureFlagEvaluator implements FeatureFlagEvaluator {
  const AllowAllFeatureFlagEvaluator();

  @override
  bool isEnabled(FeatureFlagKey key) => true;
}
