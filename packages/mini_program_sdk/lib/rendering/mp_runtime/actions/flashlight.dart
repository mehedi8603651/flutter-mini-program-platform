part of '../../mp_screen_renderer.dart';

abstract final class _MpFlashlightActionHandler {
  static Future<HostActionResult> _run(
    MiniProgramSdkScope scope,
    String actionName,
    Map<String, dynamic> props,
  ) async {
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) {
      state.set(statusState, 'loading');
    }
    if (!scope.flashlightPolicy.enabled) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.flashlightNotAccepted,
        message: 'Flashlight control is not accepted by host policy.',
      );
    }
    final manager = scope.flashlightManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.flashlightUnavailable,
        message: 'The host does not provide a flashlight on this platform.',
      );
    }
    try {
      final result = await switch (actionName) {
        ActionNames.flashlightTurnOn => manager.turnOn(scope.miniProgramId),
        ActionNames.flashlightTurnOff => manager.turnOff(scope.miniProgramId),
        ActionNames.flashlightToggle => manager.toggle(scope.miniProgramId),
        ActionNames.flashlightGetStatus => manager.getStatus(),
        _ => throw const FormatException('Unsupported flashlight action.'),
      };
      final data = result.toJson();
      try {
        state.batchUpdates(() {
          final targetState = _optionalStringProp(props, 'targetState');
          if (targetState != null) {
            state.set(targetState, data);
          }
          if (statusState != null) {
            state.set(statusState, 'success');
          }
          final errorState = _optionalStringProp(props, 'errorState');
          if (errorState != null) {
            state.remove(errorState);
          }
        });
      } on MiniProgramStateLimitException catch (error) {
        return _failure(
          state: state,
          props: props,
          actionName: actionName,
          requestId: requestId,
          code: MiniProgramErrorCodes.stateLimitExceeded,
          message: error.toString(),
          data: error.details,
        );
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: data,
      );
    } on MiniProgramFlashlightException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } on FormatException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.flashlightUnavailable,
        message: error.message.toString(),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Flashlight provider failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.flashlightOperationFailed,
        message: 'The flashlight operation failed.',
      );
    }
  }

  static HostActionResult _failure({
    required MpStateManager state,
    required Map<String, dynamic> props,
    required String actionName,
    required String? requestId,
    required String code,
    required String message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    state.batchUpdates(() {
      final statusState = _optionalStringProp(props, 'statusState');
      if (statusState != null) {
        state.set(statusState, 'error');
      }
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        state.set(errorState, <String, dynamic>{
          'action': actionName,
          'code': code,
          'message': message,
        });
      }
    });
    return HostActionResult.failed(
      requestId: requestId,
      actionName: actionName,
      message: message,
      errorCode: code,
      data: data,
    );
  }
}
