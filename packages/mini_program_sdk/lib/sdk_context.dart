import 'package:flutter/widgets.dart';

import 'capability_registry.dart';
import 'auth/mini_program_auth.dart';
import 'cache/runtime_cache.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_backend_store.dart';
import 'observability/sdk_logger.dart';
import 'state/mp_state.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;

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
    this.authController,
    required this.cacheManager,
    required this.cachePolicy,
    required this.backendStore,
    this.stateManager,
    this.router,
    this.routeParams = const <String, dynamic>{},
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
  final MiniProgramAuthController? authController;
  final MiniProgramCacheManager cacheManager;
  final MiniProgramCachePolicy cachePolicy;
  final MiniProgramBackendStore backendStore;
  final MpStateManager? stateManager;
  final MpRouter? router;
  final Map<String, dynamic> routeParams;
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
        authController != oldWidget.authController ||
        cacheManager != oldWidget.cacheManager ||
        cachePolicy != oldWidget.cachePolicy ||
        backendStore != oldWidget.backendStore ||
        stateManager != oldWidget.stateManager ||
        router != oldWidget.router ||
        routeParams != oldWidget.routeParams ||
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
