part of '../../mp_screen_renderer.dart';

abstract final class _MpOverlayActionHandler {
  static const _actions = {
    ActionNames.drawerOpen,
    ActionNames.drawerClose,
    ActionNames.sheetOpen,
    ActionNames.sheetClose,
    ActionNames.dialogOpen,
    ActionNames.dialogClose,
  };

  static Future<HostActionResult> run(
    BuildContext context,
    String type,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
  ) async {
    final owner = _MpOverlayScope.maybeOf(context);
    if (owner == null) {
      return HostActionResult.failed(
        actionName: type,
        message: 'The current mini-program renderer cannot own a panel.',
        errorCode: MiniProgramErrorCodes.overlayUnavailable,
      );
    }
    final kind = type.split('.')[1];
    if (type.endsWith('.close')) return owner.close(kind, type);
    return owner.open(context, kind, type, props, bindings);
  }
}
