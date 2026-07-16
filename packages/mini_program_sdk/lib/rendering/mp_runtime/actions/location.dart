part of '../../mp_screen_renderer.dart';

abstract final class _MpLocationActionHandler {
  static final Expando<Set<String>> _activeLocationRequests =
      Expando<Set<String>>('miniProgramLocationRequests');

  static Future<HostActionResult> _getCurrentLocation(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = ActionNames.locationGetCurrent;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }

    state.batchUpdates(() {
      final statusState = _optionalStringProp(props, 'statusState');
      if (statusState != null) {
        state.set(statusState, 'loading');
      }
    });

    final policy = scope.locationPolicy;
    if (!policy.enabled || policy.mode != MiniProgramLocationMode.whenInUse) {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationNotAccepted,
        message:
            'Current location is not accepted by host policy for this mini-program.',
      );
    }

    final accuracy = miniProgramLocationAccuracyFromWire(
      _stringProp(props, 'accuracy'),
    );
    if (accuracy != policy.accuracy) {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationNotAccepted,
        message:
            'The requested location accuracy is not accepted by host policy.',
      );
    }

    final provider = scope.locationProvider;
    if (provider == null) {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationUnavailable,
        message: 'The host does not provide current location on this platform.',
      );
    }

    final activeRequests = _activeLocationRequests[provider] ?? <String>{};
    _activeLocationRequests[provider] = activeRequests;
    if (!activeRequests.add(scope.miniProgramId)) {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationRequestInProgress,
        message: 'A current-location request is already in progress.',
      );
    }

    final timeout = Duration(milliseconds: props['timeoutMs'] as int);
    try {
      final result = await provider
          .getCurrentLocation(accuracy: accuracy, timeout: timeout)
          .timeout(
            timeout,
            onTimeout: () => throw const MiniProgramLocationException(
              errorCode: MiniProgramErrorCodes.locationTimeout,
              message: 'The current-location request timed out.',
            ),
          );
      late final Map<String, dynamic> data;
      try {
        data = result.toJson();
      } on FormatException catch (error) {
        return _locationFailure(
          state: state,
          props: props,
          requestId: requestId,
          code: MiniProgramErrorCodes.locationInvalidResult,
          message: error.message,
        );
      }

      try {
        state.batchUpdates(() {
          state.set(_stringProp(props, 'targetState'), data);
          final statusState = _optionalStringProp(props, 'statusState');
          if (statusState != null) {
            state.set(statusState, 'success');
          }
          final errorState = _optionalStringProp(props, 'errorState');
          if (errorState != null) {
            state.remove(errorState);
          }
        });
      } on MiniProgramStateLimitException catch (error) {
        return _locationFailure(
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
    } on MiniProgramLocationException catch (error) {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } on TimeoutException {
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationTimeout,
        message: 'The current-location request timed out.',
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Current-location provider failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _locationFailure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.locationUnavailable,
        message: 'Current location is unavailable.',
      );
    } finally {
      activeRequests.remove(scope.miniProgramId);
    }
  }

  static HostActionResult _locationFailure({
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
          'action': ActionNames.locationGetCurrent,
          'code': code,
          'message': message,
        });
      }
    });
    return HostActionResult.failed(
      requestId: requestId,
      actionName: ActionNames.locationGetCurrent,
      message: message,
      errorCode: code,
      data: data,
    );
  }
}
