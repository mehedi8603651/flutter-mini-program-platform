part of '../../mp_screen_renderer.dart';

abstract final class _MpMediaActionHandler {
  static Future<HostActionResult> _release(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = ActionNames.mediaRelease;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    final manager = scope.mediaManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.mediaUnavailable,
        message: 'The host does not provide temporary media access.',
      );
    }
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) {
      state.set(statusState, 'loading');
    }
    try {
      final mediaRef = _stringProp(props, 'mediaRef');
      await manager.release(
        miniProgramId: scope.miniProgramId,
        mediaRef: mediaRef,
      );
      final data = <String, dynamic>{'mediaRef': mediaRef, 'released': true};
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
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: data,
      );
    } on MiniProgramStateLimitException catch (error) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.stateLimitExceeded,
        message: error.toString(),
        data: error.details,
      );
    } on MiniProgramMediaException catch (error) {
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
        'Temporary media release failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.mediaUnavailable,
        message: 'The temporary media could not be released.',
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
      if (statusState != null) {
        state.set(statusState, 'error');
      }
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        state.set(errorState, <String, dynamic>{
          'action': ActionNames.mediaRelease,
          'code': code,
          'message': message,
        });
      }
    });
    return HostActionResult.failed(
      requestId: requestId,
      actionName: ActionNames.mediaRelease,
      message: message,
      errorCode: code,
      data: data,
    );
  }
}
