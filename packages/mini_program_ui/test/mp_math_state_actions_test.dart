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
