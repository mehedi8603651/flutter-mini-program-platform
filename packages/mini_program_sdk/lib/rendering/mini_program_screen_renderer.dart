import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../mini_program_failure.dart';
import '../observability/sdk_logger.dart';
import 'mp_screen_renderer.dart';
import 'stac_screen_renderer.dart';

/// Input passed to a screen renderer for one loaded mini-program screen.
@immutable
class MiniProgramRenderRequest {
  /// Creates a render request for a screen document.
  const MiniProgramRenderRequest({
    required this.context,
    required this.manifest,
    required this.screenId,
    required this.screenJson,
    required this.logger,
  });

  /// Build context inside [MiniProgramSdkScope].
  final BuildContext context;

  /// Manifest that selected this renderer.
  final MiniProgramManifest manifest;

  /// Screen ID being rendered.
  final String screenId;

  /// Raw loaded screen JSON.
  final Map<String, dynamic> screenJson;

  /// SDK logger for controlled diagnostics.
  final SdkLogger logger;
}

/// Controlled rendering failure that can be converted to SDK error UI.
class MiniProgramRenderException implements Exception {
  /// Creates a controlled render exception.
  const MiniProgramRenderException({
    required this.message,
    this.errorCode = MiniProgramErrorCodes.manifestParseFailure,
    this.details = const <String, dynamic>{},
  });

  /// User-facing failure message.
  final String message;

  /// Stable SDK error code.
  final String errorCode;

  /// Diagnostic details safe to expose through SDK failure state.
  final Map<String, dynamic> details;

  /// Converts this render exception to a mini-program failure.
  MiniProgramFailure toFailure({
    required MiniProgramManifest manifest,
    required String screenId,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return MiniProgramFailure(
      errorCode: errorCode,
      message: message,
      fallback: manifest.fallback,
      cause: cause ?? this,
      stackTrace: stackTrace,
      details: <String, dynamic>{
        'miniProgramId': manifest.id,
        'screenId': screenId,
        'screenFormat': manifest.screenFormat,
        if (manifest.screenSchemaVersion != null)
          'screenSchemaVersion': manifest.screenSchemaVersion,
        ...details,
      },
    );
  }

  @override
  String toString() => message;
}

/// Renders one screen document format into Flutter widgets.
abstract class MiniProgramScreenRenderer {
  /// Creates a screen renderer.
  const MiniProgramScreenRenderer();

  /// Manifest `screenFormat` value this renderer supports.
  MiniProgramScreenFormat get screenFormat;

  /// Supported schema versions. Empty means schema-less legacy format.
  Set<int> get supportedSchemaVersions;

  /// Performs async one-time setup before rendering.
  Future<void> ensureInitialized({required SdkLogger logger}) async {}

  /// Renders a validated screen into Flutter widgets.
  Widget render(MiniProgramRenderRequest request);
}

/// Immutable registry of available screen renderers.
class MiniProgramScreenRendererRegistry {
  /// Creates a renderer registry from explicit renderers.
  MiniProgramScreenRendererRegistry(
    Iterable<MiniProgramScreenRenderer> renderers,
  ) : _renderers = Map<String, MiniProgramScreenRenderer>.unmodifiable(
        _normalize(renderers),
      );

  /// Creates a registry with built-in renderers plus optional additions.
  factory MiniProgramScreenRendererRegistry.withDefaults([
    Iterable<MiniProgramScreenRenderer> renderers =
        const <MiniProgramScreenRenderer>[],
  ]) {
    return MiniProgramScreenRendererRegistry(<MiniProgramScreenRenderer>[
      ...defaultRenderers,
      ...renderers,
    ]);
  }

  /// Built-in screen renderers.
  static const List<MiniProgramScreenRenderer> defaultRenderers =
      <MiniProgramScreenRenderer>[StacScreenRenderer(), MpScreenRenderer()];

  final Map<String, MiniProgramScreenRenderer> _renderers;

  /// Registered screen formats.
  Set<String> get screenFormats => Set<String>.unmodifiable(_renderers.keys);

  /// Resolves a renderer for [manifest].
  MiniProgramScreenRenderer resolve(MiniProgramManifest manifest) {
    final format = MiniProgramScreenFormats.normalize(manifest.screenFormat);
    final renderer = _renderers[format];
    if (renderer == null) {
      throw MiniProgramRenderException(
        message: 'Unsupported mini-program screen format "$format".',
        details: <String, dynamic>{'unsupportedScreenFormat': format},
      );
    }

    final supportedVersions = renderer.supportedSchemaVersions;
    if (supportedVersions.isNotEmpty) {
      final version = manifest.screenSchemaVersion;
      if (version == null || !supportedVersions.contains(version)) {
        throw MiniProgramRenderException(
          message:
              'Unsupported mini-program screen schema version "$version" for format "$format".',
          details: <String, dynamic>{
            'unsupportedScreenSchemaVersion': version,
            'supportedScreenSchemaVersions': supportedVersions.toList()..sort(),
          },
        );
      }
    }

    return renderer;
  }

  static Map<String, MiniProgramScreenRenderer> _normalize(
    Iterable<MiniProgramScreenRenderer> renderers,
  ) {
    final normalized = <String, MiniProgramScreenRenderer>{};
    for (final renderer in renderers) {
      final format = MiniProgramScreenFormats.normalize(renderer.screenFormat);
      if (normalized.containsKey(format)) {
        throw ArgumentError.value(
          format,
          'screenFormat',
          'Duplicate mini-program screen renderer registration.',
        );
      }
      normalized[format] = renderer;
    }
    return normalized;
  }
}
