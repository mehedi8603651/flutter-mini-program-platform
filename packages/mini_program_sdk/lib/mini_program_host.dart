import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;

import 'cache/asset_cache.dart';
import 'camera/mini_program_camera.dart';
import 'gallery/mini_program_gallery.dart';
import 'microphone/mini_program_microphone.dart';
import 'cache/manifest_cache.dart';
import 'cache/runtime_cache.dart';
import 'cache/screen_cache.dart';
import 'auth/mini_program_auth.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'file/mini_program_file.dart';
import 'display/mini_program_display.dart';
import 'flashlight/mini_program_flashlight.dart';
import 'data/mini_program_data_resource.dart';
import 'host_bridge.dart';
import 'location/mini_program_location.dart';
import 'media/mini_program_media.dart';
import 'media_playback/mini_program_media_playback.dart';
import 'manifest_loader.dart';
import 'mini_program_failure.dart';
import 'mini_program_visibility.dart';
import 'network/asset_resolver.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_backend_store.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'qr/mini_program_qr.dart';
import 'share/mini_program_share.dart';
import 'system/mini_program_system.dart';
import 'rendering/mini_program_screen_renderer.dart';
import 'sdk_context.dart';
import 'state/mp_state.dart';
import 'widgets/sdk_error_view.dart';
import 'widgets/sdk_loading_view.dart';
import 'widgets/sdk_offline_notice.dart';

part 'host_runtime/host_state.dart';
part 'host_runtime/loading.dart';
part 'host_runtime/policies.dart';
part 'host_runtime/publisher_backend.dart';
part 'host_runtime/cache_lifecycle.dart';
part 'host_runtime/navigation.dart';
part 'host_runtime/rendering.dart';
part 'host_runtime/failures.dart';
part 'host_runtime/models.dart';

typedef MiniProgramErrorBuilder =
    Widget Function(BuildContext context, MiniProgramFailure failure);

/// Entry widget for loading, validating, and rendering a portable mini-program.
class MiniProgramHost extends StatefulWidget {
  const MiniProgramHost({
    super.key,
    required this.miniProgramId,
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    this.visibility = MiniProgramVisibility.foreground,
    this.backendConnector,
    this.locationProvider,
    this.fileTransferProvider,
    this.displayBrightnessProvider,
    this.cameraProvider,
    this.galleryProvider,
    this.microphoneProvider,
    this.mediaProvider,
    this.mediaPlaybackProvider,
    this.flashlightProvider,
    this.qrScannerProvider,
    this.clipboardProvider,
    this.vibrationProvider,
    this.phoneProvider,
    this.shareProvider,
    this.authController,
    this.assetCache,
    this.manifestCache,
    this.screenCache,
    this.cacheManager,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.logger = const DebugPrintSdkLogger(),
    this.renderers = const <MiniProgramScreenRenderer>[],
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String miniProgramId;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramVisibility visibility;
  final MiniProgramBackendConnector? backendConnector;
  final MiniProgramLocationProvider? locationProvider;
  final MiniProgramFileTransferProvider? fileTransferProvider;
  final MiniProgramDisplayBrightnessProvider? displayBrightnessProvider;
  final MiniProgramCameraProvider? cameraProvider;
  final MiniProgramGalleryProvider? galleryProvider;
  final MiniProgramMicrophoneProvider? microphoneProvider;
  final MiniProgramMediaProvider? mediaProvider;
  final MiniProgramMediaPlaybackProvider? mediaPlaybackProvider;
  final MiniProgramFlashlightProvider? flashlightProvider;
  final MiniProgramQrScannerProvider? qrScannerProvider;
  final MiniProgramClipboardProvider? clipboardProvider;
  final MiniProgramVibrationProvider? vibrationProvider;
  final MiniProgramPhoneProvider? phoneProvider;
  final MiniProgramShareProvider? shareProvider;
  final MiniProgramAuthController? authController;
  final AssetCache? assetCache;
  final ManifestCache? manifestCache;
  final ScreenCache? screenCache;
  final MiniProgramCacheManager? cacheManager;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;
  final List<MiniProgramScreenRenderer> renderers;
  final WidgetBuilder? loadingBuilder;
  final MiniProgramErrorBuilder? errorBuilder;

  @override
  State<MiniProgramHost> createState() => _MiniProgramHostState();
}
