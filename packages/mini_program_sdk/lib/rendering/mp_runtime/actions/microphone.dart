part of '../../mp_screen_renderer.dart';

abstract final class _MpMicrophoneActionHandler {
  static Future<HostActionResult> _run(
    BuildContext context,
    MiniProgramSdkScope scope,
    String action,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    if (action == ActionNames.microphoneRecord) {
      return _record(context, scope, props, userGesture: userGesture);
    }
    final changed = action == ActionNames.microphoneStop
        ? await scope.microphoneManager?.stopFor(scope.miniProgramId) ?? false
        : await scope.microphoneManager?.cancelFor(scope.miniProgramId) ??
              false;
    return HostActionResult.success(
      actionName: action,
      data: {'changed': changed},
    );
  }

  static Future<HostActionResult> _record(
    BuildContext context,
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    const action = ActionNames.microphoneRecord;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        action,
        requestId: requestId,
      );
    }
    bool current() =>
        context.mounted &&
        MiniProgramSdkScope.maybeOf(context)?.miniProgramId ==
            scope.miniProgramId &&
        identical(MiniProgramSdkScope.maybeOf(context)?.stateManager, state) &&
        identical(
          MiniProgramSdkScope.maybeOf(context)?.microphoneManager,
          scope.microphoneManager,
        );
    HostActionResult failure(String code, String message) {
      final cancelled =
          code == MiniProgramErrorCodes.microphoneRecordingCancelled;
      if (current()) {
        _updateStatus(
          state,
          props,
          cancelled ? 'cancelled' : 'error',
          error: cancelled
              ? null
              : {'action': action, 'code': code, 'message': message},
        );
      }
      return HostActionResult(
        requestId: requestId,
        actionName: action,
        status: cancelled
            ? HostActionStatus.cancelled
            : HostActionStatus.failed,
        errorCode: code,
        message: message,
      );
    }

    _updateStatus(state, props, 'starting');
    if (!userGesture) {
      return failure(
        MiniProgramErrorCodes.microphoneUserGestureRequired,
        'Voice recording must be started by an explicit user action.',
      );
    }
    if (!scope.microphonePolicy.enabled) {
      return failure(
        MiniProgramErrorCodes.microphoneNotAccepted,
        'Microphone recording is not accepted by host policy.',
      );
    }
    final manager = scope.microphoneManager;
    if (manager == null) {
      return failure(
        MiniProgramErrorCodes.microphoneUnavailable,
        'The host does not provide microphone recording on this platform.',
      );
    }
    try {
      final result = await manager.record(
        miniProgramId: scope.miniProgramId,
        policy: scope.microphonePolicy,
        maxDurationSeconds: _intProp(props, 'maxDurationSeconds', fallback: 60),
        onStarted: () {
          if (current()) _updateStatus(state, props, 'recording');
        },
      );
      if (!current()) {
        await manager.releaseRecording(scope.miniProgramId, result);
        return failure(
          MiniProgramErrorCodes.microphoneRecordingCancelled,
          'The mini-program closed before voice recording finished.',
        );
      }
      final data = result.toJson();
      try {
        state.batchUpdates(() {
          state.set(_stringProp(props, 'targetState'), data);
          _updateStatus(state, props, 'success');
        });
      } on MiniProgramStateLimitException {
        await manager.releaseRecording(scope.miniProgramId, result);
        rethrow;
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: action,
        data: data,
      );
    } on MiniProgramMicrophoneException catch (error) {
      return failure(error.errorCode, error.message);
    } on MiniProgramStateLimitException catch (error) {
      return failure(
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Microphone recording failed.',
        error: error,
        stackTrace: stackTrace,
      );
      return failure(
        MiniProgramErrorCodes.microphoneOperationFailed,
        'Voice recording failed.',
      );
    }
  }

  static void _updateStatus(
    MpStateManager state,
    Map<String, dynamic> props,
    String status, {
    Map<String, dynamic>? error,
  }) {
    state.batchUpdates(() {
      final statusState = _optionalStringProp(props, 'statusState');
      if (statusState != null) state.set(statusState, status);
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        if (error == null) {
          state.remove(errorState);
        } else {
          state.set(errorState, error);
        }
      }
    });
  }
}
