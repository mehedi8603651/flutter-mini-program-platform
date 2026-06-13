import 'package:flutter/foundation.dart';

import 'cache/mini_program_cache_bundle.dart';
import 'auth/mini_program_auth.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'mini_program_runtime.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_source.dart';
import 'observability/sdk_logger.dart';
import 'rendering/mini_program_screen_renderer.dart';

@immutable
class MiniProgramConfig {
  const MiniProgramConfig({
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    this.backendConnector,
    this.authController,
    this.disposeAuthController = false,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.cacheBundle,
    this.logger = const DebugPrintSdkLogger(),
    this.disposeSource = true,
    this.renderers = const <MiniProgramScreenRenderer>[],
  });

  /// Runtime compatibility version sent to mini-program artifact endpoints.
  ///
  /// This is not the pub package version of `mini_program_sdk`. It is compared
  /// with manifest `sdkVersionRange` values to decide whether a mini-program
  /// release can run in this host runtime.
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramBackendConnector? backendConnector;
  final MiniProgramAuthController? authController;
  final bool disposeAuthController;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final MiniProgramCacheBundle? cacheBundle;
  final SdkLogger logger;
  final bool disposeSource;
  final List<MiniProgramScreenRenderer> renderers;

  MiniProgramRuntime createRuntime() {
    return MiniProgramRuntime(
      sdkVersion: sdkVersion,
      source: source,
      hostBridge: hostBridge,
      capabilityRegistry: capabilityRegistry,
      backendConnector: backendConnector,
      authController: authController,
      disposeAuthController: disposeAuthController,
      featureFlagEvaluator: featureFlagEvaluator,
      cacheBundle: cacheBundle ?? MiniProgramCacheBundle.inMemory(),
      logger: logger,
      disposeSource: disposeSource,
      renderers: renderers,
    );
  }

  void disposeOwnedResources() {
    if (disposeSource && source is DisposableMiniProgramSource) {
      (source as DisposableMiniProgramSource).dispose();
    }
    final connector = backendConnector;
    if (connector is DisposableMiniProgramBackendConnector) {
      connector.dispose();
    }
    if (disposeAuthController) {
      authController?.dispose();
    }
  }
}
