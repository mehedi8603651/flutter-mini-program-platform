part of '../../../mp_screen_renderer.dart';

Map<String, dynamic> _parseThemeColors(Object? value, {required String path}) {
  if (value is! Map) {
    _fail('Mp theme colors must be an object.', path: path);
  }
  final colors = Map<String, dynamic>.from(value);
  return <String, dynamic>{
    for (final entry in colors.entries)
      _themeTokenName(entry.key, path: '$path.${entry.key}'): _themeHexColor(
        entry.value,
        path: '$path.${entry.key}',
      ),
  };
}

Map<String, dynamic> _parseThemeTypography(
  Object? value, {
  required String path,
}) {
  if (value is! Map) {
    _fail('Mp theme typography must be an object.', path: path);
  }
  final typography = Map<String, dynamic>.from(value);
  return <String, dynamic>{
    for (final entry in typography.entries)
      _themeTokenName(entry.key, path: '$path.${entry.key}'):
          _parseThemeTypographyStyle(entry.value, path: '$path.${entry.key}'),
  };
}

Map<String, dynamic> _parseThemeTypographyStyle(
  Object? value, {
  required String path,
}) {
  if (value is! Map) {
    _fail('Mp theme typography style must be an object.', path: path);
  }
  final style = Map<String, dynamic>.from(value);
  _validateObjectKeys(style, const <String>{
    'size',
    'weight',
    'lineHeight',
    'color',
  }, path: path);
  return <String, dynamic>{
    if (style.containsKey('color'))
      'color': _themeTypographyColor(style['color'], path: '$path.color'),
    if (style.containsKey('lineHeight'))
      'lineHeight': _themePositiveNumber(
        style['lineHeight'],
        path: '$path.lineHeight',
      ),
    if (style.containsKey('size'))
      'size': _themePositiveNumber(style['size'], path: '$path.size'),
    if (style.containsKey('weight'))
      'weight': _themeTextWeight(style['weight'], path: '$path.weight'),
  };
}

String _themeTokenName(String value, {required String path}) {
  if (value.trim().isEmpty ||
      !MpScreenValidator._themeTokenPattern.hasMatch(value)) {
    _fail(
      'Mp theme token name must match ^[a-zA-Z][a-zA-Z0-9_]*\$.',
      path: path,
      details: <String, dynamic>{'token': value},
    );
  }
  return value;
}

String _requiredThemeTokenNameValue(Object? value, {required String path}) {
  if (value is! String) {
    _fail('Mp theme token name must be a string.', path: path);
  }
  return _themeTokenName(value, path: path);
}

String _themeHexColor(Object? value, {required String path}) {
  if (value is! String || !MpScreenValidator._hexColorPattern.hasMatch(value)) {
    _fail(
      'Mp theme color must be a hex color in #RRGGBB or #AARRGGBB format.',
      path: path,
    );
  }
  return value;
}

String _themeTypographyColor(Object? value, {required String path}) {
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp theme typography color must be a string.', path: path);
  }
  if (MpScreenValidator._hexColorPattern.hasMatch(value)) {
    return value;
  }
  return _themeTokenName(value, path: path);
}

num _themePositiveNumber(Object? value, {required String path}) {
  if (value is! num || value <= 0 || !value.isFinite) {
    _fail('Mp theme numeric value must be finite and positive.', path: path);
  }
  return value;
}

String _themeTextWeight(Object? value, {required String path}) {
  if (value is! String || !MpScreenValidator._textWeightNames.contains(value)) {
    _fail(
      'Mp theme text weight must be one of: ${MpScreenValidator._textWeightNames.join(', ')}.',
      path: path,
    );
  }
  return value;
}
