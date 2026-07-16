part of '../mini_program_host.dart';

extension _MiniProgramHostFailures on _MiniProgramHostState {
  MiniProgramFailure _toFailure(
    Object? error,
    StackTrace? stackTrace, {
    MiniProgramManifest? manifest,
    String? screenId,
  }) {
    if (error is MiniProgramLoadException) {
      return error.failure;
    }

    if (error is MiniProgramSourceException) {
      return MiniProgramFailure(
        errorCode: error.errorCode,
        message: error.message,
        fallback: manifest?.fallback,
        cause: error,
        stackTrace: stackTrace,
        details: <String, dynamic>{
          'miniProgramId': manifest?.id ?? widget.miniProgramId,
          if (screenId != null) 'screenId': screenId,
          ...error.details,
        },
      );
    }

    if (error is MiniProgramRenderException) {
      final resolvedManifest =
          manifest ??
          MiniProgramManifest(
            id: widget.miniProgramId,
            version: 'unknown',
            entry: screenId ?? 'unknown',
            contractVersion: 'unknown',
            sdkVersionRange: const SdkVersionRange(value: '>=0.0.0'),
            requiredCapabilities: const <CapabilityId>[],
          );
      return error.toFailure(
        manifest: resolvedManifest,
        screenId: screenId ?? resolvedManifest.entry,
        stackTrace: stackTrace,
      );
    }

    widget.logger.error(
      'Unhandled mini-program host error.',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'miniProgramId': manifest?.id ?? widget.miniProgramId,
        if (screenId != null) 'screenId': screenId,
      },
    );
    return MiniProgramFailure(
      message: screenId == null
          ? 'Failed to load mini-program "${widget.miniProgramId}".'
          : 'Failed to load screen "$screenId" for mini-program "${manifest?.id ?? widget.miniProgramId}".',
      fallback: manifest?.fallback,
      cause: error,
      stackTrace: stackTrace,
      details: <String, dynamic>{
        'miniProgramId': manifest?.id ?? widget.miniProgramId,
        if (screenId != null) 'screenId': screenId,
      },
    );
  }

  Widget _buildError(BuildContext context, MiniProgramFailure failure) {
    return widget.errorBuilder?.call(context, failure) ??
        SdkErrorView(failure: failure);
  }
}
