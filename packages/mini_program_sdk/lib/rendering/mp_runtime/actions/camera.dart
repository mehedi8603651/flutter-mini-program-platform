part of '../../mp_screen_renderer.dart';

abstract final class _MpCameraActionHandler {
  static Future<HostActionResult> _capturePhoto(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = ActionNames.cameraCapturePhoto;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    _setLoading(state, props);
    final policy = scope.cameraPolicy;
    if (!policy.enabled || !policy.allowPhotoCapture) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraNotAccepted,
        message: 'Photo capture is not accepted by host policy.',
      );
    }
    final manager = scope.cameraManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraUnavailable,
        message: 'The host does not provide photo capture on this platform.',
      );
    }
    try {
      final result = await manager.capturePhoto(
        miniProgramId: scope.miniProgramId,
        quality: _intProp(props, 'quality', fallback: 95),
        maxWidth: _optionalIntProp(props, 'maxWidth'),
        maxHeight: _optionalIntProp(props, 'maxHeight'),
      );
      final data = result.toJson();
      try {
        state.batchUpdates(() {
          state.set(_stringProp(props, 'targetState'), data);
          _setSuccess(state, props);
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
    } on MiniProgramCameraException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Camera provider failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraUnavailable,
        message: 'Photo capture is unavailable.',
      );
    }
  }

  static Future<HostActionResult> _cancel(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = ActionNames.cameraCancel;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    _setLoading(state, props);
    if (!scope.cameraPolicy.enabled) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraNotAccepted,
        message: 'Camera access is not accepted by host policy.',
      );
    }
    final manager = scope.cameraManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraUnavailable,
        message: 'The host does not provide photo capture on this platform.',
      );
    }
    try {
      final cancelled = await manager.cancelFor(scope.miniProgramId);
      final data = <String, dynamic>{'cancelled': cancelled};
      state.batchUpdates(() {
        final targetState = _optionalStringProp(props, 'targetState');
        if (targetState != null) {
          state.set(targetState, data);
        }
        _setSuccess(state, props);
      });
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: data,
      );
    } on MiniProgramCameraException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Camera cancellation failed.',
        error: error,
        stackTrace: stackTrace,
      );
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.cameraUnavailable,
        message: 'The photo capture request could not be cancelled.',
      );
    }
  }

  static void _setLoading(MpStateManager state, Map<String, dynamic> props) {
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) {
      state.set(statusState, 'loading');
    }
  }

  static void _setSuccess(MpStateManager state, Map<String, dynamic> props) {
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) {
      state.set(statusState, 'success');
    }
    final errorState = _optionalStringProp(props, 'errorState');
    if (errorState != null) {
      state.remove(errorState);
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
