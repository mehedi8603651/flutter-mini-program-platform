import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('brightness scope serializes deterministic lifecycle ownership', () {
    expect(
      Mp.display
          .brightnessScope(
            level: 0.85,
            statusState: 'invite.brightness_status',
            errorState: 'invite.brightness_error',
            child: Mp.text('QR'),
          )
          .toJson(),
      <String, Object?>{
        'type': 'brightnessScope',
        'props': <String, Object?>{
          'level': 0.85,
          'statusState': 'invite.brightness_status',
          'errorState': 'invite.brightness_error',
        },
        'children': <Object?>[
          <String, Object?>{
            'type': 'text',
            'props': <String, Object?>{'data': 'QR'},
            'children': <Object?>[],
          },
        ],
      },
    );
  });

  test('brightness scope rejects unsafe levels and state keys', () {
    expect(
      () => Mp.display.brightnessScope(level: 0, child: Mp.text('QR')),
      throwsArgumentError,
    );
    expect(
      () => Mp.display.brightnessScope(level: 1.01, child: Mp.text('QR')),
      throwsArgumentError,
    );
    expect(
      () => Mp.display.brightnessScope(
        child: Mp.text('QR'),
        statusState: 'invite..brightness',
      ),
      throwsArgumentError,
    );
  });
}
