part of '../../../mp_screen_renderer.dart';

extension _MpMathActionValidation on MpScreenValidator {
  _MpAction _parseMathEvaluateAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'expression',
      'variables',
      'targetState',
      'errorState',
      'precision',
      'angleMode',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'expression': _requiredMathOperand(
          props['expression'],
          path: '$path.props.expression',
        ),
        ..._parsedMathCommon(props, path: '$path.props'),
        'precision': _mathPrecision(props, path: '$path.props'),
        'angleMode': _mathOption(
          props,
          'angleMode',
          const <String>{'radians', 'degrees'},
          fallback: 'radians',
          path: '$path.props',
        ),
      },
    );
  }

  _MpAction _parseMathCompareAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'left',
      'right',
      'comparison',
      'tolerance',
      'variables',
      'targetState',
      'errorState',
    }, path: '$path.props');
    final tolerance = props['tolerance'] ?? 1e-9;
    if (tolerance is! num || !tolerance.isFinite || tolerance < 0) {
      _fail(
        'Mp math.compare tolerance must be finite and non-negative.',
        path: '$path.props.tolerance',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'left': _requiredMathOperand(props['left'], path: '$path.props.left'),
        'right': _requiredMathOperand(
          props['right'],
          path: '$path.props.right',
        ),
        'comparison': _mathOption(
          props,
          'comparison',
          const <String>{
            'equal',
            'notEqual',
            'lessThan',
            'lessThanOrEqual',
            'greaterThan',
            'greaterThanOrEqual',
          },
          fallback: 'equal',
          path: '$path.props',
        ),
        'tolerance': tolerance,
        ..._parsedMathCommon(props, path: '$path.props'),
      },
    );
  }

  _MpAction _parseMathRandomIntAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) => _parseMathRandomAction(type, props, path, allowDecimalPlaces: false);

  _MpAction _parseMathRandomDoubleAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) => _parseMathRandomAction(type, props, path, allowDecimalPlaces: true);

  _MpAction _parseMathRandomAction(
    String type,
    Map<String, dynamic> props,
    String path, {
    required bool allowDecimalPlaces,
  }) {
    _validateObjectKeys(props, <String>{
      'min',
      'max',
      'targetState',
      'errorState',
      'seed',
      if (allowDecimalPlaces) 'decimalPlaces',
    }, path: '$path.props');
    final seed = props['seed'];
    if (seed != null && seed is! int) {
      _fail('Mp $type seed must be an integer.', path: '$path.props.seed');
    }
    final decimalPlaces = allowDecimalPlaces
        ? _optionalNonNegativeInt(
            props['decimalPlaces'],
            path: '$path.props.decimalPlaces',
          )
        : null;
    if (decimalPlaces != null && decimalPlaces > 15) {
      _fail(
        'Mp math.randomDouble decimalPlaces cannot exceed 15.',
        path: '$path.props.decimalPlaces',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'min': _requiredMathOperand(props['min'], path: '$path.props.min'),
        'max': _requiredMathOperand(props['max'], path: '$path.props.max'),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        if (seed != null) 'seed': seed,
        if (decimalPlaces != null) 'decimalPlaces': decimalPlaces,
      },
    );
  }

  _MpAction _parseMathAggregateAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'values',
      'operation',
      'targetState',
      'errorState',
      'precision',
    }, path: '$path.props');
    final operation = _mathOption(props, 'operation', const <String>{
      'sum',
      'average',
      'min',
      'max',
      'count',
      'median',
    }, path: '$path.props');
    final values = props['values'];
    if (values is List) {
      if (values.length > _maxMathAggregateItems) {
        _fail(
          'Mp math.aggregate cannot exceed $_maxMathAggregateItems values.',
          path: '$path.props.values',
        );
      }
      if (operation != 'count') {
        for (var index = 0; index < values.length; index += 1) {
          final value = values[index];
          if (value is num && value.isFinite) {
            continue;
          }
          if (value is String &&
              _MpBindingResolver.isSingleBindingExpression(value)) {
            continue;
          }
          _fail(
            'Mp math.aggregate numeric values must be finite numbers or bindings.',
            path: '$path.props.values[$index]',
          );
        }
      }
    } else if (values is! String ||
        !_MpBindingResolver.isSingleBindingExpression(values)) {
      _fail(
        'Mp math.aggregate values must be a list or single list binding.',
        path: '$path.props.values',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'values': values,
        'operation': operation,
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        'precision': _mathPrecision(props, path: '$path.props'),
      },
    );
  }

  Map<String, dynamic> _parsedMathCommon(
    Map<String, dynamic> props, {
    required String path,
  }) => <String, dynamic>{
    if (props.containsKey('variables'))
      'variables': _requiredMathVariables(
        props['variables'],
        path: '$path.variables',
      ),
    'targetState': _requiredStateKey(props, 'targetState', path: path),
    if (props.containsKey('errorState'))
      'errorState': _requiredStateKey(props, 'errorState', path: path),
  };

  Object _requiredMathOperand(Object? value, {required String path}) {
    if (value is num && value.isFinite) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      if (value.length > _maxMathExpressionLength) {
        _fail(
          'Mp math expression exceeds $_maxMathExpressionLength characters.',
          path: path,
        );
      }
      return value;
    }
    _fail(
      'Mp math operand must be a finite number or non-empty expression.',
      path: path,
    );
  }

  Map<String, dynamic> _requiredMathVariables(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp math variables must be an object.', path: path);
    }
    final variables = Map<String, dynamic>.from(value);
    if (variables.length > _maxMathVariables) {
      _fail(
        'Mp math actions support at most $_maxMathVariables variables.',
        path: path,
      );
    }
    for (final entry in variables.entries) {
      if (!_mathVariableNamePattern.hasMatch(entry.key) ||
          _reservedMathNames.contains(entry.key)) {
        _fail(
          'Invalid or reserved math variable name.',
          path: '$path.${entry.key}',
        );
      }
      final variable = entry.value;
      if (variable is num && variable.isFinite) {
        continue;
      }
      if (variable is String &&
          _MpBindingResolver.isSingleBindingExpression(variable)) {
        continue;
      }
      _fail(
        'Mp math variables must be finite numbers or single bindings.',
        path: '$path.${entry.key}',
      );
    }
    return variables;
  }

  int _mathPrecision(Map<String, dynamic> props, {required String path}) {
    final precision =
        _optionalPositiveInt(props['precision'], path: '$path.precision') ?? 12;
    if (precision > 15) {
      _fail('Mp math precision cannot exceed 15.', path: '$path.precision');
    }
    return precision;
  }

  String _mathOption(
    Map<String, dynamic> props,
    String key,
    Set<String> allowed, {
    String? fallback,
    required String path,
  }) {
    final value = props[key] ?? fallback;
    if (value is! String || !allowed.contains(value)) {
      _fail(
        'Mp math $key must be one of: ${allowed.join(', ')}.',
        path: '$path.$key',
      );
    }
    return value;
  }

  Object _requiredIntegerOrBinding(Object? value, {required String path}) {
    if (value is int ||
        value is String &&
            _MpBindingResolver.isSingleBindingExpression(value)) {
      return value!;
    }
    _fail('Mp state list index must be an integer or binding.', path: path);
  }
}
