part of '../../mp_screen_renderer.dart';

abstract final class _MpGalleryActionHandler {
  static Future<HostActionResult> _pickImages(
    BuildContext context,
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    const action = ActionNames.galleryPickImages;
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
          MiniProgramSdkScope.maybeOf(context)?.galleryManager,
          scope.galleryManager,
        );
    HostActionResult failure(String code, String message) {
      final cancelled = code == MiniProgramErrorCodes.gallerySelectionCancelled;
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

    _updateStatus(state, props, 'loading');
    if (!userGesture) {
      return failure(
        MiniProgramErrorCodes.galleryUserGestureRequired,
        'Photo selection must be started by an explicit user action.',
      );
    }
    if (!scope.galleryPolicy.enabled) {
      return failure(
        MiniProgramErrorCodes.galleryNotAccepted,
        'Gallery selection is not accepted by host policy.',
      );
    }
    final manager = scope.galleryManager;
    if (manager == null) {
      return failure(
        MiniProgramErrorCodes.galleryUnavailable,
        'The host does not provide gallery selection on this platform.',
      );
    }
    try {
      final result = await manager.pickImages(
        miniProgramId: scope.miniProgramId,
        policy: scope.galleryPolicy,
        maxImages: _intProp(props, 'maxImages', fallback: 1),
        maxWidth: _intProp(props, 'maxWidth', fallback: 2048),
        maxHeight: _intProp(props, 'maxHeight', fallback: 2048),
        quality: _intProp(props, 'quality', fallback: 90),
      );
      if (!current()) {
        await manager.releaseSelection(scope.miniProgramId, result);
        return failure(
          MiniProgramErrorCodes.gallerySelectionCancelled,
          'The mini-program closed before photo selection finished.',
        );
      }
      final data = result.toJson();
      try {
        state.batchUpdates(() {
          state.set(_stringProp(props, 'targetState'), data);
          _updateStatus(state, props, 'success');
        });
      } on MiniProgramStateLimitException {
        await manager.releaseSelection(scope.miniProgramId, result);
        rethrow;
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: action,
        data: data,
      );
    } on MiniProgramGalleryException catch (error) {
      return failure(error.errorCode, error.message);
    } on MiniProgramStateLimitException catch (error) {
      return failure(
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Gallery selection failed.',
        error: error,
        stackTrace: stackTrace,
      );
      return failure(
        MiniProgramErrorCodes.galleryOperationFailed,
        'Photo selection failed.',
      );
    }
  }

  static Future<HostActionResult> _cancel(MiniProgramSdkScope scope) async {
    final cancelled =
        await scope.galleryManager?.cancelFor(scope.miniProgramId) ?? false;
    return HostActionResult.success(
      actionName: ActionNames.galleryCancel,
      data: {'cancelled': cancelled},
    );
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
