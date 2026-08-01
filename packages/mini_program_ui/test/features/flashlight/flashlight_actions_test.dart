import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('flashlight actions serialize stable state targets', () {
    expect(
      Mp.flashlight
          .turnOn(
            targetState: 'torch.value',
            statusState: 'torch.status',
            errorState: 'torch.error',
          )
          .toJson(),
      <String, Object?>{
        'type': 'flashlight.turnOn',
        'props': <String, Object?>{
          'errorState': 'torch.error',
          'statusState': 'torch.status',
          'targetState': 'torch.value',
        },
      },
    );
    expect(
      Mp.flashlight.getStatus(targetState: 'torch.value').toJson(),
      <String, Object?>{
        'type': 'flashlight.getStatus',
        'props': <String, Object?>{'targetState': 'torch.value'},
      },
    );
    expect(Mp.flashlight.turnOff().type, 'flashlight.turnOff');
    expect(Mp.flashlight.toggle().type, 'flashlight.toggle');
  });

  test('flashlight actions reject invalid state keys', () {
    expect(
      () => Mp.flashlight.getStatus(targetState: 'torch..value'),
      throwsArgumentError,
    );
  });
}
