import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Email authentication action builders.
final class MpAuthActions {
  /// Creates email authentication action helpers.
  const MpAuthActions();

  /// Shows the SDK-owned email/password auth sheet.
  MpAction showEmailAuth({String? mode}) => MpAction(
    'auth.showEmailAuth',
    props: <String, Object?>{
      if (mode != null) 'mode': requiredAuthoringString(mode, 'mode'),
    },
  );

  /// Signs out the current mini-program auth session.
  MpAction signOut() => MpAction('auth.signOut');

  /// Restores the cached mini-program auth session.
  MpAction restore() => MpAction('auth.restore');

  /// Refreshes the current mini-program auth session.
  MpAction refresh() => MpAction('auth.refresh');
}
