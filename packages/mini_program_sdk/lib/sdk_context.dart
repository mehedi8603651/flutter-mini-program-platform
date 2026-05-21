import 'package:flutter/widgets.dart';

import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'network/mini_program_backend_connector.dart';
import 'observability/sdk_logger.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

typedef MiniProgramOpenScreenHandler =
    Future<HostActionResult> Function(
      OpenMiniProgramScreenActionPayload payload,
      String? requestId,
    );
typedef MiniProgramResetStackHandler =
    Future<HostActionResult> Function(
      ResetMiniProgramStackActionPayload payload,
      String? requestId,
    );
typedef MiniProgramReplaceScreenHandler =
    Future<HostActionResult> Function(
      ReplaceMiniProgramScreenActionPayload payload,
      String? requestId,
    );
typedef MiniProgramPopScreenHandler =
    Future<HostActionResult> Function(
      PopMiniProgramScreenActionPayload payload,
      String? requestId,
    );
typedef MiniProgramPopToRootHandler =
    Future<HostActionResult> Function(
      PopToMiniProgramRootActionPayload payload,
      String? requestId,
    );
typedef MiniProgramPopToScreenHandler =
    Future<HostActionResult> Function(
      PopToMiniProgramScreenActionPayload payload,
      String? requestId,
    );

/// Inherited runtime context used by SDK actions while a mini-program is active.
class MiniProgramSdkScope extends InheritedWidget {
  const MiniProgramSdkScope({
    super.key,
    required super.child,
    required this.miniProgramId,
    required this.hostBridge,
    required this.capabilityRegistry,
    this.backendConnector,
    required this.featureFlagEvaluator,
    required this.logger,
    required this.openMiniProgramScreen,
    required this.resetMiniProgramStack,
    required this.replaceMiniProgramScreen,
    required this.popMiniProgramScreen,
    required this.popToMiniProgramRoot,
    required this.popToMiniProgramScreen,
  });

  final String miniProgramId;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramBackendConnector? backendConnector;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;
  final MiniProgramOpenScreenHandler openMiniProgramScreen;
  final MiniProgramResetStackHandler resetMiniProgramStack;
  final MiniProgramReplaceScreenHandler replaceMiniProgramScreen;
  final MiniProgramPopScreenHandler popMiniProgramScreen;
  final MiniProgramPopToRootHandler popToMiniProgramRoot;
  final MiniProgramPopToScreenHandler popToMiniProgramScreen;

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
        backendConnector != oldWidget.backendConnector ||
        featureFlagEvaluator != oldWidget.featureFlagEvaluator ||
        logger != oldWidget.logger ||
        openMiniProgramScreen != oldWidget.openMiniProgramScreen ||
        resetMiniProgramStack != oldWidget.resetMiniProgramStack ||
        replaceMiniProgramScreen != oldWidget.replaceMiniProgramScreen ||
        popMiniProgramScreen != oldWidget.popMiniProgramScreen ||
        popToMiniProgramRoot != oldWidget.popToMiniProgramRoot ||
        popToMiniProgramScreen != oldWidget.popToMiniProgramScreen;
  }
}
