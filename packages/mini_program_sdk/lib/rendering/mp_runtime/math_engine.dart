part of '../mp_screen_renderer.dart';

const int _maxMathExpressionLength = 512;
const int _maxMathTokens = 256;
const int _maxMathOperations = 256;
const int _maxMathNesting = 32;
const int _maxMathVariables = 32;
const int _maxMathAggregateItems = 1000;
const int _maxMathRandomIntegerSpan = 1000000000;
const int _maxStateTextLength = 65536;
const int _maxStateListItems = 1000;
const int _maxSafeInteger = 9007199254740991;

final RegExp _mathVariableNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');

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

class _MpMathFailure implements Exception {
  const _MpMathFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract final class _MpMathEngine {
  static num evaluate(
    Object? operand, {
    Map<String, dynamic> variables = const <String, dynamic>{},
    int precision = 12,
    String angleMode = 'radians',
  }) {
    if (precision < 1 || precision > 15) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathInvalidRange,
        'Math precision must be between 1 and 15.',
      );
    }
    final normalizedVariables = _variables(variables);
    final double value;
    if (operand is num) {
      value = operand.toDouble();
    } else if (operand is String) {
      final expression = operand.trim();
      if (expression.isEmpty) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidExpression,
          'Math expression cannot be empty.',
        );
      }
      if (expression.length > _maxMathExpressionLength) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathComplexityExceeded,
          'Math expression exceeds the 512 character limit.',
        );
      }
      final tokens = _MpMathTokenizer(expression).tokenize();
      value = _MpMathParser(
        tokens,
        variables: normalizedVariables,
        degrees: angleMode == 'degrees',
      ).parse();
    } else {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathInvalidOperand,
        'Math operand must be a finite number or expression string.',
      );
    }
    return normalize(value, precision: precision);
  }

  static num normalize(num value, {int precision = 12}) {
    final raw = value.toDouble();
    if (!raw.isFinite) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathResultNotFinite,
        'Math result must be finite.',
      );
    }
    if (raw == 0) {
      return 0;
    }
    final rounded = double.parse(raw.toStringAsPrecision(precision));
    if (!rounded.isFinite) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathResultNotFinite,
        'Math result must be finite.',
      );
    }
    if (rounded == 0) {
      return 0;
    }
    if (rounded.abs() <= _maxSafeInteger &&
        rounded == rounded.truncateToDouble()) {
      return rounded.toInt();
    }
    return rounded;
  }

  static Map<String, double> _variables(Map<String, dynamic> values) {
    if (values.length > _maxMathVariables) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathComplexityExceeded,
        'Math actions support at most 32 variables.',
      );
    }
    final result = <String, double>{};
    for (final entry in values.entries) {
      if (!_mathVariableNamePattern.hasMatch(entry.key) ||
          _reservedMathNames.contains(entry.key)) {
        throw _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidOperand,
          'Invalid or reserved math variable "${entry.key}".',
        );
      }
      final value = entry.value;
      if (value is! num || !value.isFinite) {
        throw _MpMathFailure(
          MiniProgramErrorCodes.mathInvalidOperand,
          'Math variable "${entry.key}" must be a finite number.',
        );
      }
      result[entry.key] = value.toDouble();
    }
    return result;
  }
}

enum _MpMathTokenType {
  number,
  identifier,
  plus,
  minus,
  multiply,
  divide,
  power,
  percent,
  leftParen,
  rightParen,
  comma,
  end,
}

class _MpMathToken {
  const _MpMathToken(this.type, this.lexeme, this.offset);

  final _MpMathTokenType type;
  final String lexeme;
  final int offset;
}

class _MpMathTokenizer {
  _MpMathTokenizer(this.source);

  final String source;
  int _offset = 0;

  List<_MpMathToken> tokenize() {
    final tokens = <_MpMathToken>[];
    while (_offset < source.length) {
      final code = source.codeUnitAt(_offset);
      if (_isWhitespace(code)) {
        _offset += 1;
        continue;
      }
      final start = _offset;
      if (_isDigit(code) || code == 46) {
        tokens.add(_number());
      } else if (_isIdentifierStart(code)) {
        tokens.add(_identifier());
      } else {
        _offset += 1;
        final type = switch (code) {
          43 => _MpMathTokenType.plus,
          45 => _MpMathTokenType.minus,
          42 => _MpMathTokenType.multiply,
          47 => _MpMathTokenType.divide,
          94 => _MpMathTokenType.power,
          37 => _MpMathTokenType.percent,
          40 => _MpMathTokenType.leftParen,
          41 => _MpMathTokenType.rightParen,
          44 => _MpMathTokenType.comma,
          _ => throw _invalid('Unsupported character.', start),
        };
        tokens.add(_MpMathToken(type, source[start], start));
      }
      if (tokens.length > _maxMathTokens) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathComplexityExceeded,
          'Math expression exceeds the 256 token limit.',
        );
      }
    }
    tokens.add(_MpMathToken(_MpMathTokenType.end, '', _offset));
    return tokens;
  }

  _MpMathToken _number() {
    final start = _offset;
    var hasDigits = false;
    while (_offset < source.length && _isDigit(source.codeUnitAt(_offset))) {
      hasDigits = true;
      _offset += 1;
    }
    if (_offset < source.length && source.codeUnitAt(_offset) == 46) {
      _offset += 1;
      while (_offset < source.length && _isDigit(source.codeUnitAt(_offset))) {
        hasDigits = true;
        _offset += 1;
      }
    }
    if (!hasDigits) {
      throw _invalid('Invalid numeric literal.', start);
    }
    if (_offset < source.length &&
        (source.codeUnitAt(_offset) == 69 ||
            source.codeUnitAt(_offset) == 101)) {
      _offset += 1;
      if (_offset < source.length &&
          (source.codeUnitAt(_offset) == 43 ||
              source.codeUnitAt(_offset) == 45)) {
        _offset += 1;
      }
      final exponentStart = _offset;
      while (_offset < source.length && _isDigit(source.codeUnitAt(_offset))) {
        _offset += 1;
      }
      if (_offset == exponentStart) {
        throw _invalid('Invalid numeric exponent.', start);
      }
    }
    final lexeme = source.substring(start, _offset);
    final value = double.tryParse(lexeme);
    if (value == null || !value.isFinite) {
      throw _invalid('Invalid or non-finite numeric literal.', start);
    }
    return _MpMathToken(_MpMathTokenType.number, lexeme, start);
  }

  _MpMathToken _identifier() {
    final start = _offset;
    _offset += 1;
    while (_offset < source.length &&
        _isIdentifierPart(source.codeUnitAt(_offset))) {
      _offset += 1;
    }
    return _MpMathToken(
      _MpMathTokenType.identifier,
      source.substring(start, _offset),
      start,
    );
  }

  _MpMathFailure _invalid(String message, int offset) => _MpMathFailure(
    MiniProgramErrorCodes.mathInvalidExpression,
    '$message At character $offset.',
  );

  static bool _isDigit(int code) => code >= 48 && code <= 57;
  static bool _isWhitespace(int code) =>
      code == 32 || code == 9 || code == 10 || code == 13;
  static bool _isIdentifierStart(int code) =>
      code >= 97 && code <= 122 || code == 95;
  static bool _isIdentifierPart(int code) =>
      _isIdentifierStart(code) || _isDigit(code);
}

class _MpMathParser {
  _MpMathParser(this.tokens, {required this.variables, required this.degrees});

  final List<_MpMathToken> tokens;
  final Map<String, double> variables;
  final bool degrees;
  int _current = 0;
  int _operations = 0;
  int _nesting = 0;

  double parse() {
    final result = _additive();
    if (!_check(_MpMathTokenType.end)) {
      throw _invalid('Expected an operator.', _peek.offset);
    }
    return _finite(result);
  }

  double _additive() {
    var value = _multiplicative();
    while (_match(_MpMathTokenType.plus, _MpMathTokenType.minus)) {
      final operator = _previous.type;
      _operation();
      final right = _multiplicative();
      value = operator == _MpMathTokenType.plus ? value + right : value - right;
      value = _finite(value);
    }
    return value;
  }

  double _multiplicative() {
    var value = _unary();
    while (_match(_MpMathTokenType.multiply, _MpMathTokenType.divide)) {
      final operator = _previous.type;
      _operation();
      final right = _unary();
      if (operator == _MpMathTokenType.divide && right == 0) {
        throw const _MpMathFailure(
          MiniProgramErrorCodes.mathDivisionByZero,
          'Division by zero is not allowed.',
        );
      }
      value = operator == _MpMathTokenType.multiply
          ? value * right
          : value / right;
      value = _finite(value);
    }
    return value;
  }

  double _unary() {
    if (_match(_MpMathTokenType.plus, _MpMathTokenType.minus)) {
      final operator = _previous.type;
      _operation();
      final value = _unary();
      return operator == _MpMathTokenType.minus ? -value : value;
    }
    return _power();
  }

  double _power() {
    var value = _postfix();
    if (_match(_MpMathTokenType.power)) {
      _operation();
      value = math.pow(value, _unary()).toDouble();
      value = _finite(value, domain: true);
    }
    return value;
  }

  double _postfix() {
    var value = _primary();
    while (_match(_MpMathTokenType.percent)) {
      _operation();
      value /= 100;
    }
    return value;
  }

  double _primary() {
    if (_match(_MpMathTokenType.number)) {
      return double.parse(_previous.lexeme);
    }
    if (_match(_MpMathTokenType.identifier)) {
      final identifier = _previous;
      if (_match(_MpMathTokenType.leftParen)) {
        return _function(identifier);
      }
      if (identifier.lexeme == 'pi') {
        return math.pi;
      }
      if (identifier.lexeme == 'e') {
        return math.e;
      }
      final variable = variables[identifier.lexeme];
      if (variable != null) {
        return variable;
      }
      throw _invalid(
        'Unknown math identifier "${identifier.lexeme}".',
        identifier.offset,
      );
    }
    if (_match(_MpMathTokenType.leftParen)) {
      _enterNesting();
      final value = _additive();
      _consume(_MpMathTokenType.rightParen, 'Expected closing parenthesis.');
      _nesting -= 1;
      return value;
    }
    throw _invalid(
      'Expected a number, variable, function, or parenthesis.',
      _peek.offset,
    );
  }

  double _function(_MpMathToken name) {
    _enterNesting();
    final arguments = <double>[];
    if (!_check(_MpMathTokenType.rightParen)) {
      do {
        arguments.add(_additive());
      } while (_match(_MpMathTokenType.comma));
    }
    _consume(_MpMathTokenType.rightParen, 'Expected closing parenthesis.');
    _nesting -= 1;
    _operation();
    return _call(name, arguments);
  }

  double _call(_MpMathToken name, List<double> arguments) {
    final value = switch (name.lexeme) {
      'sqrt' => _unaryFunction(name, arguments, (value) {
        if (value < 0) {
          throw const _MpMathFailure(
            MiniProgramErrorCodes.mathDomainError,
            'sqrt requires a non-negative value.',
          );
        }
        return math.sqrt(value);
      }),
      'abs' => _unaryFunction(name, arguments, (value) => value.abs()),
      'round' => _unaryFunction(
        name,
        arguments,
        (value) => value.roundToDouble(),
      ),
      'floor' => _unaryFunction(
        name,
        arguments,
        (value) => value.floorToDouble(),
      ),
      'ceil' => _unaryFunction(
        name,
        arguments,
        (value) => value.ceilToDouble(),
      ),
      'sin' => _unaryFunction(
        name,
        arguments,
        (value) => math.sin(_angle(value)),
      ),
      'cos' => _unaryFunction(
        name,
        arguments,
        (value) => math.cos(_angle(value)),
      ),
      'tan' => _unaryFunction(
        name,
        arguments,
        (value) => math.tan(_angle(value)),
      ),
      'log' => _positiveFunction(
        name,
        arguments,
        (value) => math.log(value) / math.ln10,
      ),
      'ln' => _positiveFunction(name, arguments, math.log),
      'exp' => _unaryFunction(name, arguments, math.exp),
      'pow' => _binaryFunction(
        name,
        arguments,
        (left, right) => math.pow(left, right).toDouble(),
      ),
      'mod' => _binaryFunction(name, arguments, (left, right) {
        if (right == 0) {
          throw const _MpMathFailure(
            MiniProgramErrorCodes.mathDivisionByZero,
            'Modulo by zero is not allowed.',
          );
        }
        return left.remainder(right);
      }),
      'min' => _variadicFunction(name, arguments, math.min),
      'max' => _variadicFunction(name, arguments, math.max),
      _ => throw _invalid(
        'Unknown math function "${name.lexeme}".',
        name.offset,
      ),
    };
    return _finite(value, domain: true);
  }

  double _unaryFunction(
    _MpMathToken name,
    List<double> arguments,
    double Function(double) callback,
  ) {
    _requireArity(name, arguments, 1);
    return callback(arguments.single);
  }

  double _positiveFunction(
    _MpMathToken name,
    List<double> arguments,
    double Function(double) callback,
  ) {
    _requireArity(name, arguments, 1);
    if (arguments.single <= 0) {
      throw _MpMathFailure(
        MiniProgramErrorCodes.mathDomainError,
        '${name.lexeme} requires a positive value.',
      );
    }
    return callback(arguments.single);
  }

  double _binaryFunction(
    _MpMathToken name,
    List<double> arguments,
    double Function(double, double) callback,
  ) {
    _requireArity(name, arguments, 2);
    return callback(arguments[0], arguments[1]);
  }

  double _variadicFunction(
    _MpMathToken name,
    List<double> arguments,
    double Function(double, double) callback,
  ) {
    if (arguments.length < 2) {
      throw _invalid(
        '${name.lexeme} requires at least two arguments.',
        name.offset,
      );
    }
    return arguments.skip(1).fold(arguments.first, callback);
  }

  void _requireArity(_MpMathToken name, List<double> arguments, int count) {
    if (arguments.length != count) {
      throw _invalid(
        '${name.lexeme} requires $count argument(s).',
        name.offset,
      );
    }
  }

  double _angle(double value) => degrees ? value * math.pi / 180 : value;

  double _finite(double value, {bool domain = false}) {
    if (value.isFinite) {
      return value;
    }
    throw _MpMathFailure(
      domain && value.isNaN
          ? MiniProgramErrorCodes.mathDomainError
          : MiniProgramErrorCodes.mathResultNotFinite,
      domain && value.isNaN
          ? 'Math operation is outside its domain.'
          : 'Math result must be finite.',
    );
  }

  void _operation() {
    _operations += 1;
    if (_operations > _maxMathOperations) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathComplexityExceeded,
        'Math expression exceeds the 256 operation limit.',
      );
    }
  }

  void _enterNesting() {
    _nesting += 1;
    if (_nesting > _maxMathNesting) {
      throw const _MpMathFailure(
        MiniProgramErrorCodes.mathComplexityExceeded,
        'Math expression exceeds the nesting limit.',
      );
    }
  }

  bool _match(_MpMathTokenType first, [_MpMathTokenType? second]) {
    if (_check(first) || second != null && _check(second)) {
      _current += 1;
      return true;
    }
    return false;
  }

  bool _check(_MpMathTokenType type) => _peek.type == type;

  void _consume(_MpMathTokenType type, String message) {
    if (!_match(type)) {
      throw _invalid(message, _peek.offset);
    }
  }

  _MpMathToken get _peek => tokens[_current];
  _MpMathToken get _previous => tokens[_current - 1];

  _MpMathFailure _invalid(String message, int offset) => _MpMathFailure(
    MiniProgramErrorCodes.mathInvalidExpression,
    '$message At character $offset.',
  );
}
