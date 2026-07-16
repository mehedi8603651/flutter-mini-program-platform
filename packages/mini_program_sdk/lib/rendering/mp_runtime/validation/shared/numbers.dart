part of '../../../mp_screen_renderer.dart';

int? _optionalPositiveInt(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value <= 0) {
    _fail('Mp numeric value must be a positive integer.', path: path);
  }
  return value;
}

int _boundedIntValue(
  Object? value, {
  required String path,
  required int minimum,
  required int maximum,
}) {
  if (value is! int || value < minimum || value > maximum) {
    _fail(
      'Mp integer value must be between $minimum and $maximum.',
      path: path,
    );
  }
  return value;
}

num _boundedNumber(
  Object? value, {
  required String path,
  required num minimum,
  required num maximum,
}) {
  if (value is! num || !value.isFinite || value < minimum || value > maximum) {
    _fail(
      'Mp numeric value must be between $minimum and $maximum.',
      path: path,
    );
  }
  return value;
}

int _requiredPositiveIntValue(Object? value, {required String path}) {
  if (value is! int || value <= 0) {
    _fail('Mp numeric value must be a positive integer.', path: path);
  }
  return value;
}

int _requiredNonNegativeIntValue(Object? value, {required String path}) {
  if (value is! int || value < 0) {
    _fail('Mp numeric value must be a non-negative integer.', path: path);
  }
  return value;
}

int? _optionalNonNegativeInt(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 0) {
    _fail('Mp numeric value must be a non-negative integer.', path: path);
  }
  return value;
}

bool? _optionalBool(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    _fail('Mp value must be a boolean.', path: path);
  }
  return value;
}

bool _requiredBoolValue(Object? value, {required String path}) {
  if (value is! bool) {
    _fail('Mp value must be a boolean.', path: path);
  }
  return value;
}

Object _requiredBooleanOrBindingValue(Object? value, {required String path}) {
  if (value is bool ||
      value is String && _MpBindingResolver.isSingleBindingExpression(value)) {
    return value as Object;
  }
  _fail('Mp value must be a boolean or full binding.', path: path);
}

Object _requiredCountdownRestartToken(Object? value, {required String path}) {
  if (value is bool || value is num && value.isFinite) {
    return value as Object;
  }
  if (value is String && value.trim().isNotEmpty) {
    if (value.length > MpScreenValidator.maxLiteralTextLength) {
      _fail('Mp countdown restartToken is too long.', path: path);
    }
    return value;
  }
  _fail(
    'Mp countdown restartToken must be a non-empty string, finite number, or boolean.',
    path: path,
  );
}

int? _optionalGridColumns(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value < 1 || value > 6) {
    _fail('Mp grid columns must be an integer from 1 to 6.', path: path);
  }
  return value;
}

num _requiredNonNegativeNumber(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = json[key];
  if (value is! num || value < 0 || !value.isFinite) {
    _fail(
      'Mp "$key" must be a finite non-negative number.',
      path: '$path.$key',
    );
  }
  return value;
}

num _requiredPositiveNumber(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = json[key];
  if (value is! num || value <= 0 || !value.isFinite) {
    _fail('Mp "$key" must be a finite positive number.', path: '$path.$key');
  }
  return value;
}

void _optionalNonNegativeNumber(Object? value, {required String path}) {
  if (value == null) {
    return;
  }
  if (value is! num || value < 0 || !value.isFinite) {
    _fail('Mp numeric value must be finite and non-negative.', path: path);
  }
}

num? _optionalNonNegativeNumberValue(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! num || value < 0 || !value.isFinite) {
    _fail('Mp numeric value must be finite and non-negative.', path: path);
  }
  return value;
}

num? _optionalPositiveNumberValue(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! num || value <= 0 || !value.isFinite) {
    _fail('Mp numeric value must be finite and positive.', path: path);
  }
  return value;
}

num? _optionalUnitIntervalNumberValue(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! num || value < 0 || value > 1 || !value.isFinite) {
    _fail('Mp numeric value must be finite and between 0 and 1.', path: path);
  }
  return value;
}
