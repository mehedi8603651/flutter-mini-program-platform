import 'package:flutter/widgets.dart';

import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'observability/sdk_logger.dart';

/// Inherited runtime context used by SDK actions while a mini-program is active.
class MiniProgramSdkScope extends InheritedWidget {
  const MiniProgramSdkScope({
    super.key,
    required super.child,
    required this.miniProgramId,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.featureFlagEvaluator,
    required this.logger,
  });

  final String miniProgramId;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;

  static MiniProgramSdkScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MiniProgramSdkScope not found in context.');
    return scope!;
  }

  static MiniProgramSdkScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MiniProgramSdkScope>();
  }

  @override
  bool updateShouldNotify(MiniProgramSdkScope oldWidget) {
    return miniProgramId != oldWidget.miniProgramId ||
        hostBridge != oldWidget.hostBridge ||
        capabilityRegistry != oldWidget.capabilityRegistry ||
        featureFlagEvaluator != oldWidget.featureFlagEvaluator ||
        logger != oldWidget.logger;
  }
}
