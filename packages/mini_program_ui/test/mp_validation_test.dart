import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('MpProgram validation', () {
    test('rejects an empty screen registry', () {
      expect(
        () => MpProgram(screens: const <String, MpScreenBuilder>{}),
        throwsArgumentError,
      );
    });

    test('rejects invalid screen IDs', () {
      expect(
        () => MpProgram(
          screens: <String, MpScreenBuilder>{'CouponHome': () => Mp.text('Hi')},
        ),
        throwsArgumentError,
      );
      expect(
        () => MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon-home': () => Mp.text('Hi'),
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty action and node types', () {
      expect(() => MpAction(''), throwsArgumentError);
      expect(() => MpNode(''), throwsArgumentError);
    });

    test('requires sizedBox to define at least one dimension', () {
      expect(() => Mp.sizedBox(), throwsArgumentError);
    });

    test('runtime parity helpers reject invalid required fields', () {
      expect(
        () => Mp.backendBuilder(requestId: '', endpoint: 'home/bootstrap'),
        throwsArgumentError,
      );
      expect(() => Mp.backend.call(endpoint: ''), throwsArgumentError);
      expect(
        () => Mp.pagedBackendBuilder(
          requestId: 'coupons',
          endpoint: 'coupons/page',
          itemTemplate: Mp.text('{{item.title}}'),
          limit: 0,
        ),
        throwsArgumentError,
      );
      expect(() => Mp.navigation.openScreen(''), throwsArgumentError);
    });
  });
}
