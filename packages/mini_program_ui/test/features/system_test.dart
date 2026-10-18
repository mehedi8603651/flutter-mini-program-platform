import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('clipboard preserves whitespace and defaults to sensitive preview', () {
    expect(Mp.clipboard.writeText(text: '  note\n').toJson(), {
      'type': 'clipboard.writeText',
      'props': {'text': '  note\n', 'sensitive': true},
    });
    expect(Mp.clipboard.readText(targetState: 'pasted').toJson()['props'], {
      'targetState': 'pasted',
    });
    expect(
      () => Mp.clipboard.writeText(text: 'a' * 32769),
      throwsArgumentError,
    );
    expect(() => Mp.clipboard.readText(targetState: ''), throwsArgumentError);
  });
  test('short haptics serialize to explicit effects', () {
    expect(Mp.vibration.trigger(effect: MpVibrationEffect.success).toJson(), {
      'type': 'vibration.trigger',
      'props': {'effect': 'success'},
    });
  });
  test('dialer accepts ordinary numbers or full bindings only', () {
    expect(Mp.phone.openDialer(number: '+1 (555) 010-1234').toJson()['props'], {
      'number': '+15550101234',
    });
    expect(Mp.phone.openDialer(number: '{{state.number}}').toJson()['props'], {
      'number': '{{state.number}}',
    });
    for (final number in ['tel:123', '*123#', '123;9', '123{{state.number}}']) {
      expect(() => Mp.phone.openDialer(number: number), throwsFormatException);
    }
  });
}
