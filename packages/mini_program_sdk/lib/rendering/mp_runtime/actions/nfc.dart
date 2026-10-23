part of '../../mp_screen_renderer.dart';

abstract final class _MpNfcActionHandler {
  static Future<HostActionResult> run(
    BuildContext context,
    _MpAction request,
    Map<String, dynamic> props,
    _MpActionCallContext callContext,
  ) async {
    final scope = MiniProgramSdkScope.of(context);
    final action = request.type;
    final manager = scope.nfcManager;
    final state = scope.stateManager;
    var generation = manager?.sessionGeneration;
    int? ownedGeneration;
    Future<void> releaseOwned() async {
      final owned = ownedGeneration;
      if (owned != null) {
        await manager?.releaseFor(
          scope.miniProgramId,
          sessionGeneration: owned,
        );
      }
    }

    final cleanup = action == 'nfc.cancel';
    bool current() {
      if (!context.mounted) return false;
      final next = MiniProgramSdkScope.maybeOf(context);
      return next?.miniProgramId == scope.miniProgramId &&
          identical(next?.stateManager, state) &&
          identical(next?.nfcManager, manager) &&
          next?.nfcPolicy == scope.nfcPolicy &&
          generation == manager?.sessionGeneration;
    }

    bool foreground() =>
        current() &&
        MiniProgramSdkScope.of(context).isForeground &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed);
    void update(
      String status, {
      Map<String, dynamic>? data,
      Map<String, dynamic>? error,
    }) {
      if (state == null || !current()) return;
      state.batchUpdates(() {
        final target = _optionalStringProp(props, 'targetState');
        if (target != null && data != null) state.set(target, data);
        final statusKey = _optionalStringProp(props, 'statusState');
        if (statusKey != null) state.set(statusKey, status);
        final errorKey = _optionalStringProp(props, 'errorState');
        if (errorKey != null) {
          if (error == null) {
            state.remove(errorKey);
          } else {
            state.set(errorKey, error);
          }
        }
      });
    }

    HostActionResult failure(String code, String message) {
      final cancelled = code == MiniProgramErrorCodes.nfcRequestCancelled;
      try {
        update(
          cancelled ? 'cancelled' : 'error',
          error: {'action': action, 'code': code, 'message': message},
        );
      } on MiniProgramStateLimitException {
        /* Preserve prior state atomically. */
      }
      return HostActionResult(
        actionName: action,
        status: cancelled
            ? HostActionStatus.cancelled
            : HostActionStatus.failed,
        errorCode: code,
        message: message,
      );
    }

    if (state == null &&
        props.keys.any(
          (key) =>
              const ['targetState', 'statusState', 'errorState'].contains(key),
        )) {
      return _MpStateActionHandler._stateUnavailable(action);
    }
    if (action == 'nfc.read' && !callContext.userGesture) {
      return failure(
        'nfc_user_gesture_required',
        'NFC reading requires an explicit user action.',
      );
    }
    if (!cleanup &&
        (!foreground() || ModalRoute.of(context)?.isCurrent == false)) {
      return failure(
        'nfc_foreground_required',
        'NFC requires a foreground mini-program.',
      );
    }
    if (!cleanup && !scope.nfcPolicy.enabled) {
      return failure('nfc_not_accepted', 'NFC is not accepted by host policy.');
    }
    if (manager == null) {
      return failure('nfc_unavailable', 'The host has no NFC provider.');
    }
    try {
      final args = MiniProgramNfc.arguments(action, {
        for (final entry in props.entries)
          if (!const [
            'targetState',
            'statusState',
            'errorState',
          ].contains(entry.key))
            entry.key: entry.value,
      });
      update('loading');
      final before = manager.sessionGeneration;
      final pending = manager.run(
        miniProgramId: scope.miniProgramId,
        action: action,
        arguments: args,
        policy: scope.nfcPolicy,
      );
      generation = manager.sessionGeneration;
      if (generation != before) ownedGeneration = generation;
      final data = await pending;
      if (!current() || (!cleanup && !foreground())) {
        await releaseOwned();
        return failure(
          'nfc_request_cancelled',
          'The mini-program changed or left the foreground.',
        );
      }
      update('success', data: data);
      return HostActionResult.success(actionName: action, data: data);
    } on MiniProgramNfcException catch (error) {
      return failure(error.errorCode, error.message);
    } on MiniProgramStateLimitException catch (error) {
      await releaseOwned();
      return failure(
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
    } on FormatException {
      return failure(
        'nfc_invalid_request',
        'Invalid NFC arguments or accepted limits.',
      );
    } catch (error, stack) {
      scope.logger.error(
        'NFC operation failed.',
        error: error,
        stackTrace: stack,
      );
      await releaseOwned();
      return failure(
        'nfc_operation_failed',
        'The NFC operation did not complete.',
      );
    }
  }
}
