part of '../../mp_screen_renderer.dart';

abstract final class _MpFeedbackFormLazyActionHandler {
  static Future<HostActionResult> _lazyChunkLoadMore(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
  ) {
    return _MpLazyChunkRegistry.loadMore(
      scope: scope,
      screenId: bindings.screenId,
      id: _stringProp(props, 'id'),
    );
  }

  static Future<MiniProgramBackendResult> _submitForm(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    return _MpAuthBackendActionHandler._callBackend(scope, props);
  }

  static Future<HostActionResult> _showToast(
    BuildContext context,
    Map<String, dynamic> props,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return HostActionResult.failed(
        actionName: 'ui.toast',
        message: 'Overlay is unavailable for Mp toast.',
      );
    }
    final message = _stringProp(props, 'message');
    final durationMs = _intProp(props, 'durationMs', fallback: 2400);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 20,
        right: 20,
        bottom: 28,
        child: _MpToastView(message: message),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(Duration(milliseconds: durationMs));
    entry.remove();
    return HostActionResult.success(actionName: 'ui.toast');
  }

  static Future<HostActionResult> _showDialog(
    BuildContext context,
    Map<String, dynamic> props,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) => _MpDialogView(
        title: _optionalStringProp(props, 'title'),
        message: _stringProp(props, 'message'),
        confirmLabel: _optionalStringProp(props, 'confirmLabel') ?? 'OK',
      ),
    );
    return HostActionResult.success(actionName: 'ui.dialog');
  }
}
