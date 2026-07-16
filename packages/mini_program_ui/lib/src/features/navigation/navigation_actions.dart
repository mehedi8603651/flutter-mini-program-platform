import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Mini-program navigation action builders.
final class MpNavigationActions {
  /// Creates mini-program navigation action helpers.
  const MpNavigationActions();

  /// Opens another mini-program screen.
  MpAction openScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.openScreen', screenId, requestId: requestId);

  /// Replaces the current mini-program screen.
  MpAction replaceScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.replaceScreen', screenId, requestId: requestId);

  /// Resets the mini-program stack to [screenId].
  MpAction resetStack(String screenId, {String? requestId}) =>
      _screenAction('navigation.resetStack', screenId, requestId: requestId);

  /// Pops one mini-program screen.
  MpAction popScreen({String? requestId}) =>
      _emptyAction('navigation.popScreen', requestId: requestId);

  /// Pops to the mini-program root screen.
  MpAction popToRoot({String? requestId}) =>
      _emptyAction('navigation.popToRoot', requestId: requestId);

  /// Pops to a specific mini-program screen.
  MpAction popToScreen(String screenId, {String? requestId}) =>
      _screenAction('navigation.popToScreen', screenId, requestId: requestId);

  MpAction _screenAction(String type, String screenId, {String? requestId}) =>
      MpAction(
        type,
        props: <String, Object?>{
          'screenId': requiredAuthoringString(screenId, 'screenId'),
          if (requestId != null)
            'requestId': requiredAuthoringString(requestId, 'requestId'),
        },
      );

  MpAction _emptyAction(String type, {String? requestId}) => MpAction(
    type,
    props: <String, Object?>{
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
    },
  );
}
