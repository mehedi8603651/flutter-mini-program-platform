import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Mini-program router action builders with route params/results.
final class MpRouterActions {
  /// Creates router action helpers.
  const MpRouterActions();

  /// Pushes [screenId] and exposes [params] under `{{route.*}}`.
  MpAction push(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.push',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Replaces the active screen.
  MpAction replace(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.replace',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Resets the stack to [screenId].
  MpAction reset(
    String screenId, {
    Map<String, Object?> params = const <String, Object?>{},
    String? requestId,
  }) => _screenAction(
    'router.reset',
    screenId,
    params: params,
    requestId: requestId,
  );

  /// Pops the current screen and returns [result] to the revealed screen.
  MpAction pop({
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => _resultAction('router.pop', result: result, requestId: requestId);

  /// Pops to the root screen and returns [result].
  MpAction popToRoot({
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => _resultAction('router.popToRoot', result: result, requestId: requestId);

  /// Pops to [screenId] and returns [result].
  MpAction popToScreen(
    String screenId, {
    Map<String, Object?> result = const <String, Object?>{},
    String? requestId,
  }) => MpAction(
    'router.popToScreen',
    props: <String, Object?>{
      'screenId': requiredAuthoringString(screenId, 'screenId'),
      if (result.isNotEmpty) 'result': result,
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
    },
  );

  MpAction _screenAction(
    String type,
    String screenId, {
    required Map<String, Object?> params,
    String? requestId,
  }) => MpAction(
    type,
    props: <String, Object?>{
      'screenId': requiredAuthoringString(screenId, 'screenId'),
      if (params.isNotEmpty) 'params': params,
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
    },
  );

  MpAction _resultAction(
    String type, {
    required Map<String, Object?> result,
    String? requestId,
  }) => MpAction(
    type,
    props: <String, Object?>{
      if (result.isNotEmpty) 'result': result,
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
    },
  );
}
