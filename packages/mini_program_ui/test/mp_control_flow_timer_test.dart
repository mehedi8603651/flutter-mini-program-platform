import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('Mp control flow and timers', () {
    test('serializes condition deterministically', () {
      expect(
        Mp.condition(
          condition: '{{state.form.valid}}',
          whenTrue: Mp.text('Valid'),
          whenFalse: Mp.text('Invalid'),
        ).toJson(),
        <String, Object?>{
          'type': 'condition',
          'props': <String, Object?>{
            'condition': '{{state.form.valid}}',
            'whenFalse': <String, Object?>{
              'type': 'text',
              'props': <String, Object?>{'data': 'Invalid'},
              'children': <Object?>[],
            },
            'whenTrue': <String, Object?>{
              'type': 'text',
              'props': <String, Object?>{'data': 'Valid'},
              'children': <Object?>[],
            },
          },
          'children': <Object?>[],
        },
      );
    });

    test('serializes ifElse with nested actions deterministically', () {
      expect(
        Mp.action
            .ifElse(
              condition: '{{state.form.valid}}',
              thenAction: Mp.state.set('form.status', 'accepted'),
              elseAction: Mp.state.set('form.status', 'rejected'),
            )
            .toJson(),
        <String, Object?>{
          'type': 'action.ifElse',
          'props': <String, Object?>{
            'condition': '{{state.form.valid}}',
            'else': <String, Object?>{
              'type': 'state.set',
              'props': <String, Object?>{
                'key': 'form.status',
                'value': 'rejected',
              },
            },
            'then': <String, Object?>{
              'type': 'state.set',
              'props': <String, Object?>{
                'key': 'form.status',
                'value': 'accepted',
              },
            },
          },
        },
      );
    });

    test('serializes countdown options deterministically', () {
      expect(
        Mp.timer
            .countdown(
              duration: const Duration(seconds: 10),
              running: '{{state.screen.running}}',
              restartToken: '{{state.screen.content_id}}',
              remainingState: 'screen.remaining_seconds',
              onComplete: Mp.state.set('screen.expired', true),
              child: Mp.text('{{state.screen.remaining_seconds}}'),
            )
            .toJson(),
        <String, Object?>{
          'type': 'countdown',
          'props': <String, Object?>{
            'durationMs': 10000,
            'onComplete': <String, Object?>{
              'type': 'state.set',
              'props': <String, Object?>{
                'key': 'screen.expired',
                'value': true,
              },
            },
            'remainingState': 'screen.remaining_seconds',
            'restartToken': '{{state.screen.content_id}}',
            'running': '{{state.screen.running}}',
          },
          'children': <Object?>[
            <String, Object?>{
              'type': 'text',
              'props': <String, Object?>{
                'data': '{{state.screen.remaining_seconds}}',
              },
              'children': <Object?>[],
            },
          ],
        },
      );
    });

    test('rejects invalid conditions and countdown options', () {
      expect(
        () => Mp.condition(condition: 1, whenTrue: Mp.text('True')),
        throwsArgumentError,
      );
      expect(
        () => Mp.action.ifElse(
          condition: 'prefix {{state.valid}}',
          thenAction: Mp.state.set('status', 'yes'),
          elseAction: Mp.state.set('status', 'no'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.timer.countdown(
          duration: Duration.zero,
          remainingState: 'timer.remaining',
          child: Mp.text('Timer'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.timer.countdown(
          duration: const Duration(days: 8),
          remainingState: 'timer.remaining',
          child: Mp.text('Timer'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.timer.countdown(
          duration: const Duration(seconds: 1),
          child: Mp.text('Timer'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.timer.countdown(
          duration: const Duration(seconds: 1),
          running: 'yes',
          remainingState: 'timer.remaining',
          child: Mp.text('Timer'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.timer.countdown(
          duration: const Duration(seconds: 1),
          restartToken: const <String, Object?>{'id': 1},
          remainingState: 'timer.remaining',
          child: Mp.text('Timer'),
        ),
        throwsArgumentError,
      );
    });
  });
}
