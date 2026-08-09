part of '../../mp_screen_renderer.dart';

abstract final class _MpShareActionHandler {
  static Future<HostActionResult> _open(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool userGesture,
  }) async {
    const actionName = ActionNames.shareOpen;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    final usesState =
        props.containsKey('targetState') ||
        props.containsKey('statusState') ||
        props.containsKey('errorState');
    if (usesState && state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) state?.set(statusState, 'loading');
    if (!userGesture) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.shareUserGestureRequired,
        message: 'System sharing must be started by an explicit user action.',
      );
    }
    final policy = scope.sharePolicy;
    if (!policy.enabled) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.shareNotAccepted,
        message: 'System sharing is not accepted by host policy.',
      );
    }
    final manager = scope.shareManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.shareUnavailable,
        message: 'The host does not provide system sharing on this platform.',
      );
    }
    try {
      final title = _shareOptionalString(
        props['title'],
        maxLength: miniProgramShareMaxTitleLength,
      );
      final text = _shareOptionalString(
        props['text'],
        maxLength: miniProgramShareMaxTextLength,
      );
      final url = _shareUri(props['url']);
      final mediaRefs = _shareRefs(props['mediaRefs']);
      if (text != null && !policy.allowText ||
          url != null && !policy.allowUrls ||
          mediaRefs.isNotEmpty && !policy.allowMedia) {
        throw const MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareNotAccepted,
          message: 'The host policy does not accept this share content type.',
        );
      }
      if (mediaRefs.length > policy.maxMediaItems) {
        throw const MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareTooManyItems,
          message: 'The share request exceeds the host media-item limit.',
        );
      }
      if (mediaRefs.isNotEmpty) {
        try {
          scope.mediaManager?.requireOwned(scope.miniProgramId, mediaRefs);
          if (scope.mediaManager == null) {
            throw const MiniProgramMediaException(
              errorCode: MiniProgramErrorCodes.mediaNotOwned,
              message: 'No app-owned media registry is available.',
            );
          }
        } on MiniProgramMediaException catch (error) {
          throw MiniProgramShareException(
            errorCode: MiniProgramErrorCodes.shareMediaNotOwned,
            message: error.message,
          );
        }
      }
      final result = await manager.open(
        miniProgramId: scope.miniProgramId,
        title: title,
        text: text,
        url: url,
        mediaRefs: mediaRefs,
      );
      final data = result.toJson();
      if (state != null) {
        try {
          state.batchUpdates(() {
            final targetState = _optionalStringProp(props, 'targetState');
            if (targetState != null) state.set(targetState, data);
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
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: data,
      );
    } on MiniProgramShareException catch (error) {
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
        'System share provider failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        requestId: requestId,
        code: MiniProgramErrorCodes.shareOperationFailed,
        message: 'The system share chooser could not be opened.',
      );
    }
  }

  static HostActionResult _failure({
    required MpStateManager? state,
    required Map<String, dynamic> props,
    required String? requestId,
    required String code,
    required String message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    if (state != null) {
      state.batchUpdates(() {
        final statusState = _optionalStringProp(props, 'statusState');
        if (statusState != null) state.set(statusState, 'error');
        final errorState = _optionalStringProp(props, 'errorState');
        if (errorState != null) {
          state.set(errorState, <String, dynamic>{
            'action': ActionNames.shareOpen,
            'code': code,
            'message': message,
          });
        }
      });
    }
    return HostActionResult.failed(
      requestId: requestId,
      actionName: ActionNames.shareOpen,
      message: message,
      errorCode: code,
      data: data,
    );
  }

  static String? _shareOptionalString(Object? value, {required int maxLength}) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'The resolved share text is invalid.',
      );
    }
    return value.trim();
  }

  static Uri? _shareUri(Object? value) {
    final raw = _shareOptionalString(
      value,
      maxLength: miniProgramShareMaxUrlLength,
    );
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'Shared URLs must be absolute HTTPS URLs.',
      );
    }
    return uri;
  }

  static List<String> _shareRefs(Object? value) {
    if (value == null) return const <String>[];
    if (value is! List || value.length > miniProgramShareMaxMediaItems) {
      throw MiniProgramShareException(
        errorCode: value is List
            ? MiniProgramErrorCodes.shareTooManyItems
            : MiniProgramErrorCodes.shareInvalidContent,
        message: 'Resolved mediaRefs must be a list of up to ten references.',
      );
    }
    final refs = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty || item.length > 512) {
        throw const MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareInvalidContent,
          message: 'A resolved share media reference is invalid.',
        );
      }
      final normalized = item.trim();
      if (!refs.contains(normalized)) refs.add(normalized);
    }
    return refs;
  }
}
