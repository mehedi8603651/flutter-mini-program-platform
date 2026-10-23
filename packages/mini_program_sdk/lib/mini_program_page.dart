import 'package:flutter/material.dart';

import 'mini_program_host.dart';
import 'mini_program_runtime.dart';
import 'mini_program_visibility.dart';
import 'widgets/sdk_error_view.dart';
import 'widgets/sdk_loading_view.dart';

/// High-level embedded page wrapper for existing Flutter apps.
class MiniProgramPage extends StatelessWidget {
  const MiniProgramPage({
    super.key,
    required this.miniProgramId,
    this.title,
    this.runtime,
    this.visibility = MiniProgramVisibility.foreground,
    this.showAppBar = true,
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  final String miniProgramId;
  final String? title;
  final MiniProgramRuntime? runtime;
  final MiniProgramVisibility visibility;
  final bool showAppBar;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedRuntime = runtime ?? MiniProgramRuntimeScope.of(context);
    final resolvedTitle = title ?? _defaultTitle(miniProgramId);

    final page = Scaffold(
      appBar: showAppBar ? AppBar(title: Text(resolvedTitle)) : null,
      backgroundColor: backgroundColor,
      body: MiniProgramHost(
        miniProgramId: miniProgramId,
        sdkVersion: resolvedRuntime.sdkVersion,
        source: resolvedRuntime.source,
        hostBridge: resolvedRuntime.hostBridge,
        capabilityRegistry: resolvedRuntime.capabilityRegistry,
        visibility: visibility,
        backendConnector: resolvedRuntime.backendConnector,
        locationProvider: resolvedRuntime.locationProvider,
        fileTransferProvider: resolvedRuntime.fileTransferProvider,
        displayBrightnessProvider: resolvedRuntime.displayBrightnessProvider,
        cameraProvider: resolvedRuntime.cameraProvider,
        galleryProvider: resolvedRuntime.galleryProvider,
        microphoneProvider: resolvedRuntime.microphoneProvider,
        mediaProvider: resolvedRuntime.mediaProvider,
        mediaPlaybackProvider: resolvedRuntime.mediaPlaybackProvider,
        flashlightProvider: resolvedRuntime.flashlightProvider,
        qrScannerProvider: resolvedRuntime.qrScannerProvider,
        clipboardProvider: resolvedRuntime.clipboardProvider,
        vibrationProvider: resolvedRuntime.vibrationProvider,
        phoneProvider: resolvedRuntime.phoneProvider,
        mapsProvider: resolvedRuntime.mapsProvider,
        bluetoothProvider: resolvedRuntime.bluetoothProvider,
        nfcProvider: resolvedRuntime.nfcProvider,
        shareProvider: resolvedRuntime.shareProvider,
        authController: resolvedRuntime.authController,
        featureFlagEvaluator: resolvedRuntime.featureFlagEvaluator,
        assetCache: resolvedRuntime.cacheBundle.assetCache,
        manifestCache: resolvedRuntime.cacheBundle.manifestCache,
        screenCache: resolvedRuntime.cacheBundle.screenCache,
        cacheManager: resolvedRuntime.cacheBundle.runtimeCache,
        logger: resolvedRuntime.logger,
        renderers: resolvedRuntime.renderers,
        loadingBuilder: (context) {
          return SdkLoadingView(
            title: 'Loading $resolvedTitle',
            message: 'Fetching the latest mini-program release.',
          );
        },
        errorBuilder: (context, failure) {
          return SdkErrorView(failure: failure);
        },
      ),
    );

    final isForeground = visibility == MiniProgramVisibility.foreground;
    return TickerMode(
      enabled: isForeground,
      child: Offstage(offstage: !isForeground, child: page),
    );
  }

  String _defaultTitle(String rawMiniProgramId) {
    final words = rawMiniProgramId
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        );
    return words.isEmpty ? rawMiniProgramId : words.join(' ');
  }
}
