part of '../../mp_screen_renderer.dart';

abstract final class _MpInteractionActionHandler {
  static Future<Object?> run(
    String actionName,
    _MpActionCallContext callContext,
    Future<Object?> Function(_MpActionCallContext) operation,
  ) {
    final execution = MiniProgramInteractionExecution.current;
    if (execution == null) return operation(callContext);
    if (execution.cancelled || !execution.isAllowed()) {
      return Future.value(
        HostActionResult.failed(
          actionName: actionName,
          message: 'The foreground interaction was interrupted.',
          errorCode: 'interaction_interrupted',
        ),
      );
    }
    return execution.track(
      operation(
        _MpActionCallContext(stack: callContext.stack, userGesture: false),
      ),
    );
  }
}
