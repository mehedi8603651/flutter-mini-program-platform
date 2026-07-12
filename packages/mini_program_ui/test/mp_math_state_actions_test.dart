import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('state transformation actions', () {
    test('serialize deterministic text and list actions', () {
      expect(Mp.state.appendText('calc.expression', '7').toJson(), {
        'type': 'state.appendText',
        'props': {'key': 'calc.expression', 'text': '7', 'maxLength': 4096},
      });
      expect(Mp.state.backspace('calc.expression', count: 2).toJson(), {
        'type': 'state.backspace',
        'props': {'key': 'calc.expression', 'count': 2},
      });
      expect(
        Mp.state
            .listPrepend('calc.history', '{{state.calc.entry}}', maxItems: 50)
            .toJson(),
        {
          'type': 'state.listPrepend',
          'props': {
            'key': 'calc.history',
            'value': '{{state.calc.entry}}',
            'maxItems': 50,
          },
        },
      );
      expect(
        Mp.state.listAppend('items', 1).toJson()['type'],
        'state.listAppend',
      );
      expect(
        Mp.state.listInsert('items', '{{index}}', 2).toJson()['type'],
        'state.listInsert',
      );
      expect(
        Mp.state.listRemoveAt('items', 0).toJson()['type'],
        'state.listRemoveAt',
      );
      expect(Mp.state.listRemoveValue('items', 2, all: true).toJson(), {
        'type': 'state.listRemoveValue',
        'props': {'key': 'items', 'value': 2, 'all': true},
      });
    });

    test('serialize default numeric copy and toggle actions', () {
      expect(Mp.state.setDefault('cart.quantity', 0).toJson(), {
        'type': 'state.setDefault',
        'props': {'key': 'cart.quantity', 'value': 0},
      });
      expect(
        Mp.state
            .increment(
              'cart.quantity',
              by: '{{state.cart.step}}',
              defaultValue: 1,
              min: 0,
              max: 99,
            )
            .toJson(),
        {
          'type': 'state.increment',
          'props': {
            'key': 'cart.quantity',
            'by': '{{state.cart.step}}',
            'defaultValue': 1,
            'min': 0,
            'max': 99,
          },
        },
      );
      expect(Mp.state.decrement('player.health', by: 5, min: 0).toJson(), {
        'type': 'state.decrement',
        'props': {'key': 'player.health', 'by': 5, 'min': 0},
      });
      expect(
        Mp.state
            .copy(
              from: 'calculator.memory',
              to: 'calculator.expression',
              convertTo: 'text',
            )
            .toJson(),
        {
          'type': 'state.copy',
          'props': {
            'from': 'calculator.memory',
            'to': 'calculator.expression',
            'convertTo': 'text',
          },
        },
      );
      expect(Mp.state.toggle('settings.enabled').toJson(), {
        'type': 'state.toggle',
        'props': {'key': 'settings.enabled'},
      });
      expect(Mp.state.toggle('settings.enabled', defaultValue: true).toJson(), {
        'type': 'state.toggle',
        'props': {'key': 'settings.enabled', 'defaultValue': true},
      });
    });

    test('serializes atomic patch, lifecycle nodes, and cache info', () {
      expect(
        Mp.state
            .patch(
              const <String, Object?>{
                'checkout.total': 120,
                'checkout.ready': true,
              },
              remove: const <String>['checkout.error'],
            )
            .toJson(),
        <String, Object?>{
          'type': 'state.patch',
          'props': <String, Object?>{
            'values': <String, Object?>{
              'checkout.ready': true,
              'checkout.total': 120,
            },
            'remove': <String>['checkout.error'],
          },
        },
      );
      expect(
        Mp.cache
            .info(targetState: 'settings.cache_info', requestId: 'cache-info')
            .toJson(),
        <String, Object?>{
          'type': 'cache.info',
          'props': <String, Object?>{
            'requestId': 'cache-info',
            'targetState': 'settings.cache_info',
          },
        },
      );
      expect(
        Mp.initialize(
          actions: <MpAction>[Mp.state.set('screen.ready', true)],
          child: Mp.text('Ready'),
          loading: Mp.text('Loading'),
          error: Mp.text('Error'),
          statusState: 'screen.status',
          errorState: 'screen.error',
          retry: 1,
        ).toJson(),
        <String, Object?>{
          'type': 'initialize',
          'props': <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'state.set',
                'props': <String, Object?>{
                  'key': 'screen.ready',
                  'value': true,
                },
              },
            ],
            'error': Mp.text('Error').toJson(),
            'errorState': 'screen.error',
            'loading': Mp.text('Loading').toJson(),
            'retry': 1,
            'statusState': 'screen.status',
          },
          'children': <Object?>[Mp.text('Ready').toJson()],
        },
      );
      expect(
        Mp.stateScope(prefix: 'checkout', child: Mp.text('Checkout')).toJson(),
        <String, Object?>{
          'type': 'stateScope',
          'props': <String, Object?>{'prefix': 'checkout'},
          'children': <Object?>[Mp.text('Checkout').toJson()],
        },
      );
    });

    test('rejects unsafe author values', () {
      expect(
        () => Mp.state.appendText('calc.expression', '1', maxLength: 65537),
        throwsArgumentError,
      );
      expect(
        () => Mp.state.listAppend('items', 1, maxItems: 1001),
        throwsArgumentError,
      );
      expect(() => Mp.state.listRemoveAt('items', 1.5), throwsArgumentError);
      expect(
        () => Mp.state.listRemoveAt('items', 'first'),
        throwsArgumentError,
      );
      expect(
        () => Mp.state.increment('count', by: 'not-a-binding'),
        throwsArgumentError,
      );
      expect(
        () => Mp.state.increment('count', min: 10, max: 1),
        throwsArgumentError,
      );
      expect(
        () => Mp.state.copy(from: 'source', to: 'target', convertTo: 'json'),
        throwsArgumentError,
      );
      expect(
        () => Mp.state.patch(
          const <String, Object?>{'profile': <String, Object?>{}},
          remove: const <String>['profile.name'],
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.initialize(actions: const <MpAction>[], child: Mp.text('x')),
        throwsArgumentError,
      );
    });
  });

  group('math actions', () {
    test('serialize deterministic math actions', () {
      expect(
        Mp.math
            .evaluate(
              expression: '{{state.calc.expression}}',
              variables: const {'x': '{{state.inputs.x}}'},
              targetState: 'calc.result',
              errorState: 'calc.error',
            )
            .toJson(),
        {
          'type': 'math.evaluate',
          'props': {
            'expression': '{{state.calc.expression}}',
            'variables': {'x': '{{state.inputs.x}}'},
            'targetState': 'calc.result',
            'errorState': 'calc.error',
            'precision': 12,
            'angleMode': 'radians',
          },
        },
      );
      expect(
        Mp.math
            .compare(left: '0.1 + 0.2', right: 0.3, targetState: 'quiz.correct')
            .toJson()['type'],
        'math.compare',
      );
      expect(
        Mp.math
            .randomInt(min: 1, max: 10, targetState: 'quiz.number')
            .toJson()['type'],
        'math.randomInt',
      );
      expect(
        Mp.math
            .randomDouble(
              min: 0,
              max: 1,
              targetState: 'quiz.number',
              decimalPlaces: 2,
            )
            .toJson()['type'],
        'math.randomDouble',
      );
      expect(
        Mp.math
            .aggregate(
              values: '{{state.scores}}',
              operation: 'average',
              targetState: 'scores.average',
            )
            .toJson()['type'],
        'math.aggregate',
      );
    });

    test('rejects invalid options and variables', () {
      expect(
        () => Mp.math.evaluate(
          expression: '1 + 1',
          targetState: 'result',
          precision: 16,
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.math.evaluate(
          expression: 'x',
          variables: const {'pi': 2},
          targetState: 'result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.math.compare(
          left: 1,
          right: 1,
          comparison: 'symbolic',
          targetState: 'result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.math.randomDouble(
          min: 0,
          max: 1,
          targetState: 'result',
          decimalPlaces: 16,
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.math.evaluate(
          expression: 'x',
          variables: const {'x': 'not-a-binding'},
          targetState: 'result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.math.aggregate(
          values: const <Object?>[1, 'two'],
          operation: 'sum',
          targetState: 'result',
        ),
        throwsArgumentError,
      );
    });
  });
}
