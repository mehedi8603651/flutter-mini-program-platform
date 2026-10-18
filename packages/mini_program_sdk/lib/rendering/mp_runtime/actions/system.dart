part of '../../mp_screen_renderer.dart';

abstract final class _MpSystemActionHandler {
  static Future<HostActionResult> _run(
    BuildContext context,
    MiniProgramSdkScope scope,
    String action,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    final feature = action.split('.').first;
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
          identical(next?.clipboardProvider, scope.clipboardProvider) &&
          identical(next?.vibrationProvider, scope.vibrationProvider) &&
          identical(next?.phoneProvider, scope.phoneProvider) &&
          next?.clipboardPolicy == scope.clipboardPolicy &&
          next?.vibrationPolicy == scope.vibrationPolicy &&
          next?.phonePolicy == scope.phonePolicy;
    }

    bool foreground() =>
        context.mounted &&
        MiniProgramSdkScope.maybeOf(context)?.isForeground == true &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) &&
        ModalRoute.of(context)?.isCurrent != false;
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
      final code = '${feature}_$suffix';
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
        'This operation requires an explicit user action.',
      );
    }
    if (!foreground()) {
      return failure(
        'foreground_required',
        'The mini-program must be visible and active.',
      );
    }
    final accepted = switch (action) {
      ActionNames.clipboardReadText =>
        scope.clipboardPolicy.enabled && scope.clipboardPolicy.allowRead,
      ActionNames.clipboardWriteText =>
        scope.clipboardPolicy.enabled && scope.clipboardPolicy.allowWrite,
      ActionNames.vibrationTrigger => scope.vibrationPolicy.enabled,
      ActionNames.phoneOpenDialer => scope.phonePolicy.enabled,
      _ => false,
    };
    if (!accepted) {
      return failure(
        'not_accepted',
        'This operation is not accepted by host policy.',
      );
    }
    update('loading');
    try {
      final Map<String, dynamic> data;
      switch (action) {
        case ActionNames.clipboardReadText:
          final provider = scope.clipboardProvider;
          if (provider == null) {
            return failure('unavailable', 'Clipboard access is unavailable.');
          }
          final text = await provider.readText(
            miniProgramId: scope.miniProgramId,
            maxTextLength: scope.clipboardPolicy.maxTextLength,
          );
          if (!current() || !foreground()) {
            return failure(
              'request_cancelled',
              'The mini-program is no longer active.',
            );
          }
          _validateText(
            text,
            scope.clipboardPolicy.maxTextLength,
            nullable: true,
          );
          data = {'hasText': text != null, 'text': text};
        case ActionNames.clipboardWriteText:
          final provider = scope.clipboardProvider;
          if (provider == null) {
            return failure('unavailable', 'Clipboard access is unavailable.');
          }
          final text = props['text'];
          _validateText(text, scope.clipboardPolicy.maxTextLength);
          await provider.writeText(
            miniProgramId: scope.miniProgramId,
            text: text as String,
            sensitive: props['sensitive'] != false,
          );
          data = {'written': true};
        case ActionNames.vibrationTrigger:
          final provider = scope.vibrationProvider;
          if (provider == null) {
            return failure('unavailable', 'System haptics are unavailable.');
          }
          final effect = MiniProgramVibrationEffect.values.byName(
            props['effect'] as String,
          );
          final performed = await provider.trigger(
            miniProgramId: scope.miniProgramId,
            effect: effect,
          );
          data = {'performed': performed, 'effect': effect.name};
        case ActionNames.phoneOpenDialer:
          final provider = scope.phoneProvider;
          if (provider == null) {
            return failure('unavailable', 'The system dialer is unavailable.');
          }
          final raw = props['number'];
          if (raw is! String) {
            throw const FormatException('Invalid phone number.');
          }
          final number = normalizeMiniProgramPhoneNumber(raw);
          await provider.openDialer(
            miniProgramId: scope.miniProgramId,
            number: number,
          );
          data = {'dialerOpened': true};
        default:
          throw const FormatException('Unsupported system action.');
      }
      if (!current()) {
        return failure(
          'request_cancelled',
          'The mini-program changed before completion.',
        );
      }
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
        'The resolved system action value is invalid or exceeds host limits.',
      );
    } on MiniProgramSystemException catch (error) {
      const suffixes = [
        'unavailable',
        'foreground_required',
        'invalid_request',
        'operation_failed',
      ];
      final suffix = suffixes.firstWhere(
        (s) => error.errorCode == '${feature}_$s',
        orElse: () => 'operation_failed',
      );
      return failure(suffix, 'The system operation could not be completed.');
    } catch (error, stackTrace) {
      scope.logger.error(
        'System capability failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'action': action},
      );
      return failure(
        'operation_failed',
        'The system operation could not be completed.',
      );
    }
  }

  static void _validateText(
    Object? value,
    int maximum, {
    bool nullable = false,
  }) {
    if (value == null && nullable) return;
    if (value is! String ||
        value.length > maximum ||
        value.length > miniProgramClipboardMaxTextLength) {
      throw const FormatException('Clipboard text exceeds host limits.');
    }
  }
}
