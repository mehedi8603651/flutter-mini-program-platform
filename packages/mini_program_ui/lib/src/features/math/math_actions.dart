import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

final RegExp _mathVariablePattern = RegExp(r'^[a-z][a-z0-9_]*$');

const Set<String> _reservedMathNames = <String>{
  'pi',
  'e',
  'sqrt',
  'abs',
  'pow',
  'mod',
  'min',
  'max',
  'round',
  'floor',
  'ceil',
  'sin',
  'cos',
  'tan',
  'log',
  'ln',
  'exp',
};

/// Safe, offline mathematical action builders.
final class MpMathActions {
  /// Creates mathematical action helpers.
  const MpMathActions();

  /// Evaluates a restricted mathematical [expression].
  MpAction evaluate({
    required Object expression,
    Map<String, Object?> variables = const <String, Object?>{},
    required String targetState,
    String? errorState,
    int precision = 12,
    String angleMode = 'radians',
  }) => MpAction(
    'math.evaluate',
    props: <String, Object?>{
      'expression': _mathOperand(expression, 'expression'),
      if (variables.isNotEmpty) 'variables': _mathVariables(variables),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      'precision': _mathPrecision(precision),
      'angleMode': allowedValue(angleMode, 'angleMode', const <String>{
        'radians',
        'degrees',
      }),
    },
  );

  /// Compares two numeric values or restricted mathematical expressions.
  MpAction compare({
    required Object left,
    required Object right,
    String comparison = 'equal',
    double tolerance = 1e-9,
    Map<String, Object?> variables = const <String, Object?>{},
    required String targetState,
    String? errorState,
  }) => MpAction(
    'math.compare',
    props: <String, Object?>{
      'left': _mathOperand(left, 'left'),
      'right': _mathOperand(right, 'right'),
      'comparison': allowedValue(comparison, 'comparison', const <String>{
        'equal',
        'notEqual',
        'lessThan',
        'lessThanOrEqual',
        'greaterThan',
        'greaterThanOrEqual',
      }),
      'tolerance': finiteNonNegative(tolerance, 'tolerance'),
      if (variables.isNotEmpty) 'variables': _mathVariables(variables),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
    },
  );

  /// Generates an inclusive, non-cryptographic random integer.
  MpAction randomInt({
    required Object min,
    required Object max,
    required String targetState,
    String? errorState,
    int? seed,
  }) => MpAction(
    'math.randomInt',
    props: <String, Object?>{
      'min': _mathOperand(min, 'min'),
      'max': _mathOperand(max, 'max'),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (seed != null) 'seed': seed,
    },
  );

  /// Generates a non-cryptographic random double in the selected range.
  MpAction randomDouble({
    required Object min,
    required Object max,
    required String targetState,
    String? errorState,
    int? decimalPlaces,
    int? seed,
  }) => MpAction(
    'math.randomDouble',
    props: <String, Object?>{
      'min': _mathOperand(min, 'min'),
      'max': _mathOperand(max, 'max'),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (decimalPlaces != null)
        'decimalPlaces': boundedInt(
          decimalPlaces,
          'decimalPlaces',
          minimum: 0,
          maximum: 15,
        ),
      if (seed != null) 'seed': seed,
    },
  );

  /// Aggregates a list of values with a supported mathematical operation.
  MpAction aggregate({
    required Object values,
    required String operation,
    required String targetState,
    String? errorState,
    int precision = 12,
  }) {
    final normalizedOperation = allowedValue(
      operation,
      'operation',
      const <String>{'sum', 'average', 'min', 'max', 'count', 'median'},
    );
    return MpAction(
      'math.aggregate',
      props: <String, Object?>{
        'values': _mathAggregateValues(values, normalizedOperation),
        'operation': normalizedOperation,
        'targetState': requiredStateKey(targetState, 'targetState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        'precision': _mathPrecision(precision),
      },
    );
  }
}

Object _mathOperand(Object value, String name) {
  if (value is num && value.isFinite ||
      value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw ArgumentError.value(
    value,
    name,
    'Value must be a finite number or non-empty expression.',
  );
}

Map<String, Object?> _mathVariables(Map<String, Object?> variables) {
  if (variables.length > 32) {
    throw ArgumentError.value(
      variables,
      'variables',
      'Math actions support at most 32 variables.',
    );
  }
  final normalized = <String, Object?>{};
  for (final entry in variables.entries) {
    if (!_mathVariablePattern.hasMatch(entry.key) ||
        _reservedMathNames.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'variables',
        'Math variable names must be lowercase identifiers and cannot be reserved.',
      );
    }
    final value = entry.value;
    if (value is num && value.isFinite || isFullBinding(value)) {
      normalized[entry.key] = value;
      continue;
    }
    throw ArgumentError.value(
      value,
      'variables.${entry.key}',
      'Math variables must be finite numbers or full bindings.',
    );
  }
  return normalized;
}

Object _mathAggregateValues(Object values, String operation) {
  if (isFullBinding(values)) {
    return values;
  }
  if (values is! List) {
    throw ArgumentError.value(
      values,
      'values',
      'Math aggregate values must be a list or full binding.',
    );
  }
  if (values.length > 1000) {
    throw ArgumentError.value(
      values,
      'values',
      'Math aggregate supports at most 1000 values.',
    );
  }
  if (operation != 'count') {
    for (final value in values) {
      if (value is num && value.isFinite || isFullBinding(value)) {
        continue;
      }
      throw ArgumentError.value(
        value,
        'values',
        'Numeric math aggregates require finite numbers or full bindings.',
      );
    }
  }
  return values;
}

int _mathPrecision(int value) =>
    boundedInt(value, 'precision', minimum: 1, maximum: 15);
