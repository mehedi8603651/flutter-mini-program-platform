part of '../../mp_screen_renderer.dart';

abstract final class _MpBluetoothActionHandler {
  static Future<HostActionResult> run(
    BuildContext context,
    _MpAction request,
    Map<String, dynamic> props,
    _MpActionCallContext callContext,
  ) async {
    final scope = MiniProgramSdkScope.of(context);
    final action = request.type;
    final userGesture = callContext.userGesture;
    final manager = scope.bluetoothManager;
    var generation = manager?.sessionGeneration;
    final state = scope.stateManager;
    final cleanup = const {
      'bluetooth.stopScan',
      'bluetooth.disconnect',
      'bluetooth.unsubscribe',
    }.contains(action);
    bool current() {
      if (!context.mounted) return false;
      final next = MiniProgramSdkScope.maybeOf(context);
      return next?.miniProgramId == scope.miniProgramId &&
          identical(next?.stateManager, state) &&
          identical(next?.bluetoothManager, manager) &&
          generation == manager?.sessionGeneration &&
          next?.bluetoothPolicy == scope.bluetoothPolicy;
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
      final cancelled = code == MiniProgramErrorCodes.bluetoothRequestCancelled;
      try {
        update(
          cancelled ? 'cancelled' : 'error',
          error: {'action': action, 'code': code, 'message': message},
        );
      } on MiniProgramStateLimitException {
        /* Keep the prior state atomically. */
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
    if (!cleanup && action != 'bluetooth.getState' && !userGesture) {
      return failure(
        'bluetooth_user_gesture_required',
        'BLE access requires an explicit user action.',
      );
    }
    if (!cleanup &&
        (!foreground() || ModalRoute.of(context)?.isCurrent == false)) {
      return failure(
        'bluetooth_foreground_required',
        'BLE access requires a foreground mini-program.',
      );
    }
    if (!cleanup && !scope.bluetoothPolicy.enabled) {
      return failure(
        'bluetooth_not_accepted',
        'Bluetooth is not accepted by host policy.',
      );
    }
    if (manager == null) {
      return failure(
        'bluetooth_unavailable',
        'The host has no Bluetooth provider.',
      );
    }
    try {
      final args = MiniProgramBluetooth.arguments(action, {
        for (final entry in props.entries)
          if (!const [
            'targetState',
            'statusState',
            'errorState',
          ].contains(entry.key))
            entry.key: entry.value,
      });
      update('loading');
      final pending = manager.run(
        miniProgramId: scope.miniProgramId,
        action: action,
        arguments: args,
        policy: scope.bluetoothPolicy,
        onValue: (value) {
          if (!current()) return false;
          // A system permission dialog is transient inactivity, not a hidden
          // mini-program. Drop these values without ending its BLE session.
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.inactive) {
            return true;
          }
          if (!foreground()) return false;
          try {
            update('success', data: value);
            return true;
          } on MiniProgramStateLimitException {
            return false;
          }
        },
        onConnection: (value) {
          if (!current()) return false;
          try {
            update(
              value['connected'] == true ? 'success' : 'disconnected',
              data: value,
            );
            return true;
          } on MiniProgramStateLimitException {
            return false;
          }
        },
      );
      generation = manager.sessionGeneration;
      final data = await pending;
      if (!current() || (!cleanup && !foreground())) {
        await manager.releaseFor(
          scope.miniProgramId,
          sessionGeneration: generation,
        );
        return failure(
          'bluetooth_request_cancelled',
          'The mini-program changed or left the foreground.',
        );
      }
      update('success', data: action == 'bluetooth.subscribe' ? null : data);
      return HostActionResult.success(actionName: action, data: data);
    } on MiniProgramBluetoothException catch (error) {
      return failure(error.errorCode, error.message);
    } on MiniProgramStateLimitException catch (error) {
      await manager.releaseFor(
        scope.miniProgramId,
        sessionGeneration: generation,
      );
      return failure(
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
    } on FormatException {
      return failure(
        'bluetooth_invalid_request',
        'Invalid BLE arguments or accepted limits.',
      );
    } catch (error, stack) {
      scope.logger.error(
        'BLE operation failed.',
        error: error,
        stackTrace: stack,
      );
      await manager.releaseFor(
        scope.miniProgramId,
        sessionGeneration: generation,
      );
      return failure(
        'bluetooth_operation_failed',
        'The BLE operation did not complete.',
      );
    }
  }
}
