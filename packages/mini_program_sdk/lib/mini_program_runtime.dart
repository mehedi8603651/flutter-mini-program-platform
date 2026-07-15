import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache/mini_program_cache_bundle.dart';
import 'auth/mini_program_auth.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'location/mini_program_location.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_source.dart';
import 'observability/sdk_logger.dart';
import 'rendering/mini_program_screen_renderer.dart';

/// Shared embedded runtime that existing apps configure once, then reuse to
/// open many mini-programs by ID.
@immutable
class MiniProgramRuntime {
  const MiniProgramRuntime({
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    required this.cacheBundle,
    this.backendConnector,
    this.locationProvider,
    this.authController,
    this.disposeAuthController = false,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.logger = const DebugPrintSdkLogger(),
    this.disposeSource = false,
    this.renderers = const <MiniProgramScreenRenderer>[],
  });

  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramBackendConnector? backendConnector;
  final MiniProgramLocationProvider? locationProvider;
  final MiniProgramAuthController? authController;
  final bool disposeAuthController;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final MiniProgramCacheBundle cacheBundle;
  final SdkLogger logger;
  final bool disposeSource;
  final List<MiniProgramScreenRenderer> renderers;

  MiniProgramRuntime copyWith({
    String? sdkVersion,
    MiniProgramSource? source,
    HostBridge? hostBridge,
    CapabilityRegistry? capabilityRegistry,
    MiniProgramBackendConnector? backendConnector,
    MiniProgramLocationProvider? locationProvider,
    MiniProgramAuthController? authController,
    bool? disposeAuthController,
    FeatureFlagEvaluator? featureFlagEvaluator,
    MiniProgramCacheBundle? cacheBundle,
    SdkLogger? logger,
    bool? disposeSource,
    List<MiniProgramScreenRenderer>? renderers,
  }) {
    return MiniProgramRuntime(
      sdkVersion: sdkVersion ?? this.sdkVersion,
      source: source ?? this.source,
      hostBridge: hostBridge ?? this.hostBridge,
      capabilityRegistry: capabilityRegistry ?? this.capabilityRegistry,
      backendConnector: backendConnector ?? this.backendConnector,
      locationProvider: locationProvider ?? this.locationProvider,
      authController: authController ?? this.authController,
      disposeAuthController:
          disposeAuthController ?? this.disposeAuthController,
      featureFlagEvaluator: featureFlagEvaluator ?? this.featureFlagEvaluator,
      cacheBundle: cacheBundle ?? this.cacheBundle,
      logger: logger ?? this.logger,
      disposeSource: disposeSource ?? this.disposeSource,
      renderers: renderers ?? this.renderers,
    );
  }

  void dispose() {
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

/// Inherited scope that exposes a configured [MiniProgramRuntime] to embedded
/// mini-program pages in an existing app.
class MiniProgramRuntimeScope extends InheritedWidget {
  const MiniProgramRuntimeScope({
    super.key,
    required this.runtime,
    required super.child,
  });

  final MiniProgramRuntime runtime;

  static MiniProgramRuntime of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('MiniProgramRuntimeScope not found in context.'),
        ErrorDescription(
          'MiniProgramPage requires either an explicit MiniProgramRuntime or '
          'a MiniProgramRuntimeScope ancestor.',
        ),
      ]);
    }

    return scope.runtime;
  }

  static MiniProgramRuntimeScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MiniProgramRuntimeScope>();
  }

  @override
  bool updateShouldNotify(MiniProgramRuntimeScope oldWidget) {
    return runtime.sdkVersion != oldWidget.runtime.sdkVersion ||
        runtime.source != oldWidget.runtime.source ||
        runtime.hostBridge != oldWidget.runtime.hostBridge ||
        runtime.capabilityRegistry != oldWidget.runtime.capabilityRegistry ||
        runtime.backendConnector != oldWidget.runtime.backendConnector ||
        runtime.locationProvider != oldWidget.runtime.locationProvider ||
        runtime.authController != oldWidget.runtime.authController ||
        runtime.disposeAuthController !=
            oldWidget.runtime.disposeAuthController ||
        runtime.featureFlagEvaluator !=
            oldWidget.runtime.featureFlagEvaluator ||
        runtime.cacheBundle != oldWidget.runtime.cacheBundle ||
        runtime.logger != oldWidget.runtime.logger ||
        runtime.disposeSource != oldWidget.runtime.disposeSource ||
        !listEquals(runtime.renderers, oldWidget.runtime.renderers);
  }
}
