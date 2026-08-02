import 'package:flutter/foundation.dart';

import 'cache/mini_program_cache_bundle.dart';
import 'camera/mini_program_camera.dart';
import 'auth/mini_program_auth.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'file/mini_program_file.dart';
import 'flashlight/mini_program_flashlight.dart';
import 'host_bridge.dart';
import 'location/mini_program_location.dart';
import 'media/mini_program_media.dart';
import 'media_playback/mini_program_media_playback.dart';
import 'mini_program_runtime.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_source.dart';
import 'observability/sdk_logger.dart';
import 'qr/mini_program_qr.dart';
import 'rendering/mini_program_screen_renderer.dart';

@immutable
class MiniProgramConfig {
  const MiniProgramConfig({
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    this.backendConnector,
    this.locationProvider,
    this.fileTransferProvider,
    this.cameraProvider,
    this.mediaProvider,
    this.mediaPlaybackProvider,
    this.flashlightProvider,
    this.qrScannerProvider,
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
  final MiniProgramLocationProvider? locationProvider;
  final MiniProgramFileTransferProvider? fileTransferProvider;
  final MiniProgramCameraProvider? cameraProvider;
  final MiniProgramMediaProvider? mediaProvider;
  final MiniProgramMediaPlaybackProvider? mediaPlaybackProvider;
  final MiniProgramFlashlightProvider? flashlightProvider;
  final MiniProgramQrScannerProvider? qrScannerProvider;
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
      locationProvider: locationProvider,
      fileTransferProvider: fileTransferProvider,
      cameraProvider: cameraProvider,
      mediaProvider: mediaProvider,
      mediaPlaybackProvider: mediaPlaybackProvider,
      flashlightProvider: flashlightProvider,
      qrScannerProvider: qrScannerProvider,
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
