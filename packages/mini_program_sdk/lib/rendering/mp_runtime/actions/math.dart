part of '../../mp_screen_renderer.dart';

class _MpMathActionOutcome {
  const _MpMathActionOutcome(
    this.value, {
    this.data = const <String, dynamic>{},
  });

  final Object? value;
  final Map<String, dynamic> data;
}

abstract final class _MpMathActionHandler {
  static Future<HostActionResult> _evaluateMath(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    return _runMathAction(scope, 'math.evaluate', props, () {
      final value = _MpMathEngine.evaluate(
        props['expression'],
        variables: _mapProp(props, 'variables'),
        precision: _intProp(props, 'precision', fallback: 12),
        angleMode: _optionalStringProp(props, 'angleMode') ?? 'radians',
      );
      return _MpMathActionOutcome(value);
    });
  }

  static Future<HostActionResult> _compareMath(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    return _runMathAction(scope, 'math.compare', props, () {
      final variables = _mapProp(props, 'variables');
      final left = _MpMathEngine.evaluate(
        props['left'],
        variables: variables,
        precision: 15,
      ).toDouble();
      final right = _MpMathEngine.evaluate(
        props['right'],
        variables: variables,
        precision: 15,
      ).toDouble();
      final tolerance = _numProp(props, 'tolerance', fallback: 1e-9).toDouble();
      final scale = math.max(1.0, math.max(left.abs(), right.abs()));
      final equal = (left - right).abs() <= tolerance * scale;
      final comparison = _stringProp(props, 'comparison');
      final matches = switch (comparison) {
        'equal' => equal,
        'notEqual' => !equal,
        'lessThan' => left < right,
        'lessThanOrEqual' => left < right || equal,
        'greaterThan' => left > right,
        'greaterThanOrEqual' => left > right || equal,
        _ => throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidOperand,
          'Unsupported math comparison.',
        ),
      };
      return _MpMathActionOutcome(
        matches,
        data: <String, dynamic>{'left': left, 'right': right},
      );
    });
  }

  static Future<HostActionResult> _randomMathInt(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    return _runMathAction(scope, 'math.randomInt', props, () {
      final minValue = _MpMathEngine.evaluate(props['min']);
      final maxValue = _MpMathEngine.evaluate(props['max']);
      if (minValue is! int || maxValue is! int) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidRange,
          'Random integer bounds must evaluate to integers.',
        );
      }
      final difference = maxValue - minValue;
      if (difference < 0 || difference > _maxMathRandomIntegerSpan) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidRange,
          'Random integer range is invalid or too large.',
        );
      }
      final seed = _optionalIntProp(props, 'seed');
      final random = seed == null ? math.Random() : math.Random(seed);
      final value = minValue + random.nextInt(difference + 1);
      return _MpMathActionOutcome(value);
    });
  }

  static Future<HostActionResult> _randomMathDouble(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    return _runMathAction(scope, 'math.randomDouble', props, () {
      final minValue = _MpMathEngine.evaluate(props['min']).toDouble();
      final maxValue = _MpMathEngine.evaluate(props['max']).toDouble();
      if (maxValue < minValue || !(maxValue - minValue).isFinite) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidRange,
          'Random double maximum must be greater than or equal to minimum.',
        );
      }
      final seed = _optionalIntProp(props, 'seed');
      final random = seed == null ? math.Random() : math.Random(seed);
      var value = minValue == maxValue
          ? minValue
          : minValue + random.nextDouble() * (maxValue - minValue);
      final decimalPlaces = _optionalIntProp(props, 'decimalPlaces');
      if (decimalPlaces != null) {
        value = double.parse(value.toStringAsFixed(decimalPlaces));
      }
      return _MpMathActionOutcome(
        _MpMathEngine.normalize(value, precision: 15),
      );
    });
  }

  static Future<HostActionResult> _aggregateMath(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    return _runMathAction(scope, 'math.aggregate', props, () {
      final rawValues = props['values'];
      if (rawValues is! List) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidOperand,
          'Math aggregate values must be a list.',
        );
      }
      if (rawValues.length > _maxMathAggregateItems) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathComplexityExceeded,
          'Math aggregate exceeds the 1000 item limit.',
        );
      }
      final operation = _stringProp(props, 'operation');
      if (operation == 'count') {
        return _MpMathActionOutcome(rawValues.length);
      }
      if (rawValues.isEmpty) {
        if (operation == 'sum') {
          return const _MpMathActionOutcome(0);
        }
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathEmptyValues,
          'Math aggregate requires at least one value.',
        );
      }
      final values = <double>[];
      for (final value in rawValues) {
        if (value is! num || !value.isFinite) {
          throw const _MpMathFailure(
            MiniProgramErrorCodes.mathInvalidOperand,
            'Math aggregate values must be finite numbers.',
          );
        }
        values.add(value.toDouble());
      }
      final double result = switch (operation) {
        'sum' => values.fold(0.0, (total, value) => total + value),
        'average' =>
          values.fold(0.0, (total, value) => total + value) / values.length,
        'min' => values.reduce(math.min),
        'max' => values.reduce(math.max),
        'median' => _median(values),
        _ => throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidOperand,
          'Unsupported math aggregate operation.',
        ),
      };
      final value = _MpMathEngine.normalize(
        result,
        precision: _intProp(props, 'precision', fallback: 12),
      );
      return _MpMathActionOutcome(
        value,
        data: <String, dynamic>{'operation': operation, 'count': values.length},
      );
    });
  }

  static Future<HostActionResult> _runMathAction(
    MiniProgramSdkScope scope,
    String actionName,
    Map<String, dynamic> props,
    _MpMathActionOutcome Function() callback,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(actionName);
    }
    try {
      final outcome = callback();
      state.set(_stringProp(props, 'targetState'), outcome.value);
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        state.remove(errorState);
      }
      return HostActionResult.success(
        actionName: actionName,
        data: <String, dynamic>{'value': outcome.value, ...outcome.data},
      );
    } on _MpMathFailure catch (failure) {
      final errorState = _optionalStringProp(props, 'errorState');
      if (errorState != null) {
        state.set(errorState, <String, dynamic>{
          'action': actionName,
          'code': failure.code,
          'message': failure.message,
        });
      }
      return HostActionResult.failed(
        actionName: actionName,
        message: failure.message,
        errorCode: failure.code,
      );
    }
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
