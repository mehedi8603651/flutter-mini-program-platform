import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('share result reports chooser opening without completion claims', () {
    const result = MiniProgramShareResult(chooserOpened: true);

    expect(MiniProgramShareResult.fromJson(result.toJson()), result);
    expect(result.toJson(), <String, dynamic>{'chooserOpened': true});
    expect(
      () => MiniProgramShareResult.fromJson(const <String, dynamic>{
        'chooserOpened': false,
      }),
      throwsFormatException,
    );
  });

  test('share action, capability, and errors are stable', () {
    expect(ActionNames.shareOpen, 'share.open');
    expect(CapabilityIds.systemShare, 'share.system');
    expect(CapabilityIds.standardValues, contains(CapabilityIds.systemShare));
    expect(MiniProgramErrorCodes.shareNotAccepted, 'share_not_accepted');
    expect(
      MiniProgramErrorCodes.shareUserGestureRequired,
      'share_user_gesture_required',
    );
    expect(MiniProgramErrorCodes.shareMediaNotOwned, 'share_media_not_owned');
  });
}
