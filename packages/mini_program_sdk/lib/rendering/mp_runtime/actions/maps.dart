part of '../../mp_screen_renderer.dart';

abstract final class _MpMapsActionHandler {
  static Future<HostActionResult> _run(
    BuildContext context,
    MiniProgramSdkScope scope,
    String action,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null &&
        const [
          'targetState',
          'statusState',
          'errorState',
        ].any(props.containsKey)) {
      return _MpStateActionHandler._stateUnavailable(
        action,
        requestId: requestId,
      );
    }
    bool current() {
      if (!context.mounted) return false;
      final next = MiniProgramSdkScope.maybeOf(context);
      return next?.miniProgramId == scope.miniProgramId &&
          identical(next?.stateManager, state) &&
          identical(next?.mapsProvider, scope.mapsProvider) &&
          next?.mapsPolicy == scope.mapsPolicy;
    }

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

    HostActionResult failure(String suffix, String message) {
      final code = 'maps_$suffix';
      update(
        'error',
        error: {'action': action, 'code': code, 'message': message},
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: action,
        errorCode: code,
        message: message,
      );
    }

    if (!userGesture) {
      return failure(
        'user_gesture_required',
        'Opening a map requires an explicit user action.',
      );
    }
    if (!context.mounted ||
        !scope.isForeground ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return failure(
        'foreground_required',
        'The mini-program must be visible and active.',
      );
    }
    final directions = action == ActionNames.mapsOpenDirections;
    if (!scope.mapsPolicy.enabled ||
        !(directions
            ? scope.mapsPolicy.allowDirections
            : scope.mapsPolicy.allowOpenLocation)) {
      return failure(
        'not_accepted',
        'This map operation is not accepted by host policy.',
      );
    }
    final provider = scope.mapsProvider;
    if (provider == null) {
      return failure('unavailable', 'Map application support is unavailable.');
    }
    try {
      final destination = MiniProgramMapDestination.fromJson({
        for (final key in [
          'latitude',
          'longitude',
          'name',
          'address',
          'coordinateSystem',
        ])
          if (props.containsKey(key)) key: props[key],
      });
      final mode = props['mode'] ?? 'driving';
      if (directions &&
          !MiniProgramMapTravelMode.values.any((v) => v.name == mode)) {
        throw const FormatException('Invalid map travel mode.');
      }
      update('loading');
      if (directions) {
        await provider.openDirections(
          miniProgramId: scope.miniProgramId,
          destination: destination,
          mode: MiniProgramMapTravelMode.values.byName(mode as String),
        );
      } else {
        await provider.openLocation(
          miniProgramId: scope.miniProgramId,
          destination: destination,
        );
      }
      // The expected external launch pauses our Activity. Do not report that
      // pause as cancellation, or dispose/reopen the mini-program on return.
      if (!current()) {
        return failure(
          'request_cancelled',
          'The mini-program changed before completion.',
        );
      }
      final data = <String, dynamic>{
        'mapOpened': true,
        'operation': directions ? 'directions' : 'location',
      };
      update('success', data: data);
      return HostActionResult.success(
        requestId: requestId,
        actionName: action,
        data: data,
      );
    } on MiniProgramStateLimitException {
      rethrow;
    } on FormatException {
      return failure(
        'invalid_request',
        'The resolved map destination or travel mode is invalid.',
      );
    } on MiniProgramMapsException catch (error) {
      const suffixes = [
        'unavailable',
        'foreground_required',
        'invalid_request',
        'coordinate_system_unsupported',
        'operation_failed',
      ];
      final suffix = suffixes.firstWhere(
        (s) => error.errorCode == 'maps_$s',
        orElse: () => 'operation_failed',
      );
      return failure(suffix, 'The map application could not be opened.');
    } catch (error, stackTrace) {
      scope.logger.error(
        'Map application launch failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'action': action},
      );
      return failure(
        'operation_failed',
        'The map application could not be opened.',
      );
    }
  }
}
