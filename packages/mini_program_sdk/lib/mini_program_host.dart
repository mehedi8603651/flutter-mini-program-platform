import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:stac/stac.dart';

import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'manifest_loader.dart';
import 'mini_program_failure.dart';
import 'network/mini_program_source.dart';
import 'observability/sdk_logger.dart';
import 'rendering/stac_initializer.dart';
import 'sdk_context.dart';
import 'widgets/sdk_error_view.dart';
import 'widgets/sdk_loading_view.dart';

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
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.logger = const DebugPrintSdkLogger(),
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String miniProgramId;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;
  final WidgetBuilder? loadingBuilder;
  final MiniProgramErrorBuilder? errorBuilder;

  @override
  State<MiniProgramHost> createState() => _MiniProgramHostState();
}

class _MiniProgramHostState extends State<MiniProgramHost> {
  late Future<LoadedMiniProgram> _loadFuture;
  final ManifestLoader _manifestLoader = const ManifestLoader();

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadMiniProgram();
  }

  @override
  void didUpdateWidget(covariant MiniProgramHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.miniProgramId != oldWidget.miniProgramId ||
        widget.sdkVersion != oldWidget.sdkVersion ||
        widget.source != oldWidget.source ||
        widget.hostBridge != oldWidget.hostBridge ||
        widget.capabilityRegistry != oldWidget.capabilityRegistry ||
        widget.featureFlagEvaluator != oldWidget.featureFlagEvaluator ||
        widget.logger != oldWidget.logger) {
      _loadFuture = _loadMiniProgram();
    }
  }

  Future<LoadedMiniProgram> _loadMiniProgram() async {
    await StacInitializer.ensureInitialized(logger: widget.logger);

    return _manifestLoader.load(
      miniProgramId: widget.miniProgramId,
      sdkVersion: widget.sdkVersion,
      source: widget.source,
      capabilityRegistry: widget.capabilityRegistry,
      featureFlagEvaluator: widget.featureFlagEvaluator,
      logger: widget.logger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoadedMiniProgram>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ?? const SdkLoadingView();
        }

        if (snapshot.hasError) {
          final failure = _toFailure(snapshot.error, snapshot.stackTrace);
          return _buildError(context, failure);
        }

        final loadedMiniProgram = snapshot.data!;

        return MiniProgramSdkScope(
          miniProgramId: loadedMiniProgram.manifest.id,
          hostBridge: widget.hostBridge,
          capabilityRegistry: widget.capabilityRegistry,
          featureFlagEvaluator: widget.featureFlagEvaluator,
          logger: widget.logger,
          child: Builder(
            builder: (context) {
              final rendered = Stac.fromJson(
                loadedMiniProgram.entryScreenJson,
                context,
              );

              if (rendered == null) {
                final failure = MiniProgramFailure(
                  errorCode: MiniProgramErrorCodes.manifestParseFailure,
                  message:
                      'Failed to render entry screen "${loadedMiniProgram.manifest.entry}" for mini-program "${loadedMiniProgram.manifest.id}".',
                  fallback: loadedMiniProgram.manifest.fallback,
                  details: <String, dynamic>{
                    'miniProgramId': loadedMiniProgram.manifest.id,
                    'entryScreen': loadedMiniProgram.manifest.entry,
                  },
                );

                widget.logger.warn(
                  'Stac returned null while rendering the entry screen.',
                  context: <String, Object?>{
                    'miniProgramId': loadedMiniProgram.manifest.id,
                    'entryScreen': loadedMiniProgram.manifest.entry,
                  },
                );
                return _buildError(context, failure);
              }

              return rendered;
            },
          ),
        );
      },
    );
  }

  MiniProgramFailure _toFailure(Object? error, StackTrace? stackTrace) {
    if (error is MiniProgramLoadException) {
      return error.failure;
    }

    widget.logger.error(
      'Unhandled mini-program host error.',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{'miniProgramId': widget.miniProgramId},
    );
    return MiniProgramFailure(
      message: 'Failed to load mini-program "${widget.miniProgramId}".',
      cause: error,
      stackTrace: stackTrace,
      details: <String, dynamic>{'miniProgramId': widget.miniProgramId},
    );
  }

  Widget _buildError(BuildContext context, MiniProgramFailure failure) {
    return widget.errorBuilder?.call(context, failure) ??
        SdkErrorView(failure: failure);
  }
}
