part of '../../mp_screen_renderer.dart';

abstract final class _MpQrActionHandler {
  static Future<HostActionResult> _scan(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    const actionName = ActionNames.qrScan;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) state.set(statusState, 'loading');
    if (!userGesture) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.qrUserGestureRequired,
        message: 'QR scanning must be started by an explicit user action.',
      );
    }
    final policy = scope.qrPolicy;
    if (!policy.enabled) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.qrNotAccepted,
        message: 'QR scanning is not accepted by host policy.',
      );
    }
    final manager = scope.qrManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.qrUnavailable,
        message: 'The host does not provide QR scanning on this platform.',
      );
    }
    try {
      final result = await manager.scan(
        miniProgramId: scope.miniProgramId,
        allowTorch: policy.allowTorch && _boolProp(props, 'allowTorch'),
        timeout: Duration(
          milliseconds: _intProp(props, 'timeoutMs', fallback: 60000),
        ),
      );
      final data = result.toJson();
      try {
        state.batchUpdates(() {
          state.set(_stringProp(props, 'targetState'), data);
          if (statusState != null) state.set(statusState, 'success');
          final errorState = _optionalStringProp(props, 'errorState');
          if (errorState != null) state.remove(errorState);
        });
      } on MiniProgramStateLimitException catch (error) {
        return _failure(
          state: state,
          props: props,
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
    } on MiniProgramQrException catch (error) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'QR scanner provider failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.qrOperationFailed,
        message: 'The QR scan could not be completed.',
      );
    }
  }

  static HostActionResult _failure({
    required MpStateManager state,
    required Map<String, dynamic> props,
    required String? requestId,
    required String code,
    required String message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    state.batchUpdates(() {
      final statusState = _optionalStringProp(props, 'statusState');
      if (statusState != null) state.set(statusState, 'error');
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        state.set(errorState, <String, dynamic>{
          'action': ActionNames.qrScan,
          'code': code,
          'message': message,
        });
      }
    });
    return HostActionResult.failed(
      requestId: requestId,
      actionName: ActionNames.qrScan,
      message: message,
      errorCode: code,
      data: data,
    );
  }
}
