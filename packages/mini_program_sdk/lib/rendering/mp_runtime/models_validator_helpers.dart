part of '../mp_screen_renderer.dart';

void _validateObjectKeys(
  Map<String, dynamic> json,
  Set<String> allowedKeys, {
  required String path,
}) {
  final unknownKeys = json.keys.where((key) => !allowedKeys.contains(key));
  if (unknownKeys.isNotEmpty) {
    _fail(
      'Mp JSON contains unsupported field(s): ${unknownKeys.join(', ')}.',
      path: path,
      details: <String, dynamic>{'unsupportedFields': unknownKeys.toList()},
    );
  }
}

void _validateNoProps(Map<String, dynamic> props, {required String path}) {
  if (props.isNotEmpty) {
    _fail('This Mp node or action does not support props.', path: path);
  }
}

void _validateNoChildren(List<_MpNode> children, {required String path}) {
  if (children.isNotEmpty) {
    _fail('This Mp node does not support children.', path: path);
  }
}

void _validateSingleChild(
  List<_MpNode> children, {
  required String nodeType,
  required String path,
}) {
  if (children.length != 1) {
    _fail('Mp $nodeType requires exactly one child.', path: '$path.children');
  }
}

void _validateNonEmptyChildren(
  List<_MpNode> children, {
  required String nodeType,
  required String path,
}) {
  if (children.isEmpty) {
    _fail('Mp $nodeType requires at least one child.', path: '$path.children');
  }
}

void _validateAvatarSource(Map<String, dynamic> props, {required String path}) {
  final sourceCount = <String>[
    'imageUrl',
    'initials',
    'icon',
  ].where(props.containsKey).length;
  if (sourceCount != 1) {
    _fail(
      'Mp avatar requires exactly one of imageUrl, initials, or icon.',
      path: path,
    );
  }
}

Map<String, dynamic> _parseSpacing(Object? value, {required String path}) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is! Map) {
    _fail('Mp spacing must be an object.', path: path);
  }
  final spacing = Map<String, dynamic>.from(value);
  _validateObjectKeys(spacing, const <String>{
    'left',
    'top',
    'right',
    'bottom',
  }, path: path);
  return <String, dynamic>{
    if (spacing.containsKey('bottom'))
      'bottom': _optionalNonNegativeNumberValue(
        spacing['bottom'],
        path: '$path.bottom',
      ),
    if (spacing.containsKey('left'))
      'left': _optionalNonNegativeNumberValue(
        spacing['left'],
        path: '$path.left',
      ),
    if (spacing.containsKey('right'))
      'right': _optionalNonNegativeNumberValue(
        spacing['right'],
        path: '$path.right',
      ),
    if (spacing.containsKey('top'))
      'top': _optionalNonNegativeNumberValue(spacing['top'], path: '$path.top'),
  };
}

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

Map<String, dynamic> _parseImageHeaders(Object? value, {required String path}) {
  if (value is! Map) {
    _fail('Mp image headers must be an object.', path: path);
  }
  final parsed = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      _fail('Mp image header names must be strings.', path: path);
    }
    parsed[_imageHeaderName(key, path: '$path.$key')] = _imageHeaderValue(
      entry.value,
      path: '$path.$key',
    );
  }
  return parsed;
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

String _requiredSkeletonVariant(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._skeletonVariantNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._skeletonVariantNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'variant': value},
    );
  }
  return value;
}

Map<String, dynamic> _parsePositionedConstraints(
  Map<String, dynamic> props, {
  required String path,
}) {
  const constraintKeys = <String>{
    'left',
    'top',
    'right',
    'bottom',
    'width',
    'height',
  };
  if (!props.keys.any(constraintKeys.contains)) {
    _fail('Mp positioned requires at least one constraint.', path: path);
  }
  if (props.containsKey('left') &&
      props.containsKey('right') &&
      props.containsKey('width')) {
    _fail('Mp positioned cannot combine left, right, and width.', path: path);
  }
  if (props.containsKey('top') &&
      props.containsKey('bottom') &&
      props.containsKey('height')) {
    _fail('Mp positioned cannot combine top, bottom, and height.', path: path);
  }
  return <String, dynamic>{
    if (props.containsKey('bottom'))
      'bottom': _requiredNonNegativeNumber(props, 'bottom', path: path),
    if (props.containsKey('height'))
      'height': _requiredNonNegativeNumber(props, 'height', path: path),
    if (props.containsKey('left'))
      'left': _requiredNonNegativeNumber(props, 'left', path: path),
    if (props.containsKey('right'))
      'right': _requiredNonNegativeNumber(props, 'right', path: path),
    if (props.containsKey('top'))
      'top': _requiredNonNegativeNumber(props, 'top', path: path),
    if (props.containsKey('width'))
      'width': _requiredNonNegativeNumber(props, 'width', path: path),
  };
}

String _defaultAlertIcon(String tone) {
  return switch (tone) {
    'success' => 'check',
    'warning' || 'danger' => 'warning',
    _ => 'info',
  };
}

String _requiredHexColor(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._hexColorPattern.hasMatch(value)) {
    _fail(
      'Mp "$key" must be a hex color in #RRGGBB or #AARRGGBB format.',
      path: '$path.$key',
    );
  }
  return value;
}

String _requiredIconName(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._iconNames.contains(value)) {
    _fail(
      'Mp "$key" is not an allowed icon name.',
      path: '$path.$key',
      details: <String, dynamic>{'iconName': value},
    );
  }
  return value;
}

String? _optionalTone(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._toneNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._toneNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'tone': value},
    );
  }
  return value;
}

String? _optionalAlignment(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._alignmentNames.contains(value)) {
    _fail(
      'Mp "$key" is not an allowed alignment.',
      path: '$path.$key',
      details: <String, dynamic>{'alignment': value},
    );
  }
  return value;
}

String? _optionalFlexFit(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._flexFitNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._flexFitNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'fit': value},
    );
  }
  return value;
}

String? _optionalImageSource(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._imageSourceNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._imageSourceNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'source': value},
    );
  }
  return value;
}

String? _optionalImageFit(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._imageFitNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._imageFitNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'fit': value},
    );
  }
  return value;
}

String? _optionalTextWeight(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _optionalTextChoice(
    json,
    key,
    path: path,
    allowedValues: MpScreenValidator._textWeightNames,
    label: 'text weight',
  );
}

String? _optionalTextAlign(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _optionalTextChoice(
    json,
    key,
    path: path,
    allowedValues: MpScreenValidator._textAlignNames,
    label: 'text align',
  );
}

String? _optionalTextOverflow(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _optionalTextChoice(
    json,
    key,
    path: path,
    allowedValues: MpScreenValidator._textOverflowNames,
    label: 'text overflow',
  );
}

String? _optionalTextDirection(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _optionalTextChoice(
    json,
    key,
    path: path,
    allowedValues: MpScreenValidator._textDirectionNames,
    label: 'text direction',
  );
}

String? _optionalTextChoice(
  Map<String, dynamic> json,
  String key, {
  required String path,
  required Set<String> allowedValues,
  required String label,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!allowedValues.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${allowedValues.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{label: value},
    );
  }
  return value;
}

String _requiredLocale(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._localePattern.hasMatch(value)) {
    _fail(
      'Mp "$key" must be a simple locale tag.',
      path: '$path.$key',
      details: <String, dynamic>{'locale': value},
    );
  }
  return value;
}

String _requiredImageSrc(Object? value, {required String path}) {
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp image src must be a non-empty string.', path: path);
  }
  return value.trim();
}

String _imageHeaderName(String value, {required String path}) {
  if (value.trim().isEmpty || _MpBindingResolver.containsBinding(value)) {
    _fail(
      'Mp image header name must be a non-empty static string.',
      path: path,
    );
  }
  return value.trim();
}

String _imageHeaderValue(Object? value, {required String path}) {
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp image header value must be a non-empty string.', path: path);
  }
  return value;
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

int _requiredHeadingLevelValue(Object? value, {required String path}) {
  if (value is! int || value < 1 || value > 6) {
    _fail('Mp heading level must be an integer from 1 to 6.', path: path);
  }
  return value;
}

String _requiredStableString(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredString(json, key, path: path);
  if (_MpBindingResolver.containsBinding(value)) {
    _fail('Mp "$key" cannot contain bindings.', path: '$path.$key');
  }
  return value;
}

String _requiredFieldName(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._fieldNamePattern.hasMatch(value)) {
    _fail(
      'Mp "$key" must match ^[a-z][a-z0-9_]*\$.',
      path: '$path.$key',
      details: <String, dynamic>{key: value},
    );
  }
  return value;
}

String? _optionalFieldName(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._fieldNamePattern.hasMatch(value)) {
    _fail(
      'Mp "$key" must match ^[a-z][a-z0-9_]*\$.',
      path: '$path.$key',
      details: <String, dynamic>{key: value},
    );
  }
  return value;
}

String? _optionalStableString(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  return _requiredStableString(json, key, path: path);
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp "$key" must be a non-empty string.', path: '$path.$key');
  }
  if (value.length > MpScreenValidator.maxLiteralTextLength) {
    _fail(
      'Mp string literal exceeds the maximum length.',
      path: '$path.$key',
      details: <String, dynamic>{
        'length': value.length,
        'MpScreenValidator.maxLiteralTextLength':
            MpScreenValidator.maxLiteralTextLength,
      },
    );
  }
  return value;
}

String _optionalStringLiteral(Object? value, {required String path}) {
  if (value is! String) {
    _fail('Mp field must be a string.', path: path);
  }
  if (value.length > MpScreenValidator.maxLiteralTextLength) {
    _fail(
      'Mp string literal exceeds the maximum length.',
      path: path,
      details: <String, dynamic>{
        'length': value.length,
        'MpScreenValidator.maxLiteralTextLength':
            MpScreenValidator.maxLiteralTextLength,
      },
    );
  }
  return value;
}

Map<String, dynamic> _optionalMap(Object? value, {required String path}) {
  if (value == null) {
    return <String, dynamic>{};
  }
  if (value is! Map) {
    _fail('Mp field must be an object.', path: path);
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _optionalChildren(
  Object? value, {
  required String path,
}) {
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }
  if (value is! List) {
    _fail('Mp children must be an array.', path: path);
  }
  return <Map<String, dynamic>>[
    for (final child in value)
      if (child is Map)
        Map<String, dynamic>.from(child)
      else
        throw MiniProgramRenderException(
          message: 'Invalid Mp screen JSON: child nodes must be objects.',
          details: <String, dynamic>{'path': path},
        ),
  ];
}

int? _optionalPositiveInt(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value <= 0) {
    _fail('Mp numeric value must be a positive integer.', path: path);
  }
  return value;
}

int _optionalRepeatLimit(Object? value, {required String path}) {
  if (value == null) {
    return 100;
  }
  if (value is! int || value <= 0 || value > 500) {
    _fail('Mp repeat limit must be an integer from 1 to 500.', path: path);
  }
  return value;
}

int? _optionalSearchLimit(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }
  if (value is! int || value <= 0 || value > 100) {
    _fail('Mp search limit must be an integer from 1 to 100.', path: path);
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

void _validateImageUrl(String src, {required String path}) {
  if (src.length > MpScreenValidator.maxUrlLength) {
    _fail(
      'Mp image URL exceeds the maximum length.',
      path: path,
      details: <String, dynamic>{
        'length': src.length,
        'MpScreenValidator.maxUrlLength': MpScreenValidator.maxUrlLength,
      },
    );
  }
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    _fail('Mp image src must be an absolute URL.', path: path);
  }
  if (uri.scheme == 'https') {
    return;
  }
  if (uri.scheme == 'http' && _isLocalPreviewHost(uri.host)) {
    return;
  }
  _fail(
    'Mp image src must use https, except local preview loopback URLs.',
    path: path,
    details: <String, dynamic>{'scheme': uri.scheme, 'host': uri.host},
  );
}

void _validateImageSourceSrc(
  String src, {
  required String source,
  required String path,
}) {
  switch (source) {
    case 'network':
      _validateAsyncImageNetworkUrl(src, path: path);
    case 'base64':
      _validateBase64Image(src, path: path);
    case 'asset' || 'auto':
      return;
  }
}

void _validateAsyncImageNetworkUrl(String src, {required String path}) {
  if (src.length > MpScreenValidator.maxUrlLength) {
    _fail(
      'Mp image URL exceeds the maximum length.',
      path: path,
      details: <String, dynamic>{
        'length': src.length,
        'MpScreenValidator.maxUrlLength': MpScreenValidator.maxUrlLength,
      },
    );
  }
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    _fail('Mp network image src must be an absolute URL.', path: path);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    _fail(
      'Mp network image src must use http or https.',
      path: path,
      details: <String, dynamic>{'scheme': uri.scheme},
    );
  }
}

void _validateBase64Image(String src, {required String path}) {
  final payload = _base64ImagePayload(src);
  if (payload.replaceAll(RegExp(r'\s+'), '').isEmpty) {
    _fail('Mp base64 image src must be valid base64 data.', path: path);
  }
  try {
    base64Decode(_paddedBase64(payload));
  } on FormatException {
    _fail('Mp base64 image src must be valid base64 data.', path: path);
  }
}

String _base64ImagePayload(String value) {
  final trimmed = value.trim();
  final match = RegExp(
    r'^data:image\/[-+.\w]+;base64,',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match == null ? trimmed : trimmed.substring(match.end);
}

String _paddedBase64(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  final remainder = compact.length % 4;
  return remainder == 0
      ? compact
      : compact.padRight(compact.length + 4 - remainder, '=');
}

bool _isLocalPreviewHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized.startsWith('127.') ||
      normalized == '::1' ||
      normalized == '0.0.0.0' ||
      normalized == '10.0.2.2';
}

List<Map<String, dynamic>> _parseOptions(
  Object? value, {
  required String path,
}) {
  if (value is! List || value.isEmpty) {
    _fail('Mp options must be a non-empty array.', path: path);
  }
  final seenValues = <String>{};
  return <Map<String, dynamic>>[
    for (var index = 0; index < value.length; index += 1)
      _parseOption(value[index], path: '$path[$index]', seenValues: seenValues),
  ];
}

Map<String, dynamic> _parseOption(
  Object? value, {
  required String path,
  required Set<String> seenValues,
}) {
  if (value is! Map) {
    _fail('Mp option must be an object.', path: path);
  }
  final json = Map<String, dynamic>.from(value);
  _validateObjectKeys(json, const <String>{'label', 'value'}, path: path);
  final optionValue = _requiredStableString(json, 'value', path: path);
  if (!seenValues.add(optionValue)) {
    _fail(
      'Mp option values must be unique.',
      path: '$path.value',
      details: <String, dynamic>{'value': optionValue},
    );
  }
  return <String, dynamic>{
    'label': _requiredString(json, 'label', path: path),
    'value': optionValue,
  };
}

List<String> _parseStateKeys(Object? value, {required String path}) {
  if (value is! List || value.isEmpty) {
    _fail('Mp state keys must be a non-empty array.', path: path);
  }
  final keys = <String>[];
  for (var index = 0; index < value.length; index += 1) {
    final rawKey = value[index];
    if (rawKey is! String) {
      _fail('Mp state key must be a string.', path: '$path[$index]');
    }
    keys.add(_validateStateKey(rawKey, path: '$path[$index]'));
  }
  return List<String>.unmodifiable(keys);
}

String _requiredStateKey(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  return _validateStateKey(
    _requiredStableString(json, key, path: path),
    path: '$path.$key',
  );
}

String _validateStateKey(String value, {required String path}) {
  try {
    return validateStateKey(value);
  } on ArgumentError {
    _fail(
      'Mp state key must be a safe lowercase dot path.',
      path: path,
      details: <String, dynamic>{'stateKey': value},
    );
  }
}

String _requiredCacheKey(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(json, key, path: path).trim();
  if (_unsafeCacheKeyPattern.hasMatch(value)) {
    _fail(
      'Mp cache key cannot contain path traversal, separators, or file path markers.',
      path: '$path.$key',
      details: <String, dynamic>{key: value},
    );
  }
  return value;
}

String? _optionalCacheBucket(
  Map<String, dynamic> json, {
  required String path,
}) {
  final bucket = _optionalStableString(json, 'bucket', path: path);
  if (bucket == null) {
    return null;
  }
  if (!_allowedMiniProgramCacheBuckets.contains(bucket)) {
    _fail(
      'Mp cache bucket is not allowed for mini-program actions.',
      path: '$path.bucket',
      details: <String, dynamic>{'bucket': bucket},
    );
  }
  return bucket;
}

String? _optionalCachePriority(
  Map<String, dynamic> json, {
  required String path,
}) {
  final priority = _optionalStableString(json, 'priority', path: path);
  if (priority == null) {
    return null;
  }
  if (!_allowedMiniProgramCachePriorities.contains(priority)) {
    _fail(
      'Mp cache priority is not allowed for mini-program actions.',
      path: '$path.priority',
      details: <String, dynamic>{'priority': priority},
    );
  }
  return priority;
}

void _validateCacheValue(Object? value, {required String path}) {
  if (value == null || value is String || value is bool) {
    return;
  }
  if (value is num) {
    if (!value.isFinite) {
      _fail('Mp cache value numbers must be finite.', path: path);
    }
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _validateCacheValue(value[index], path: '$path[$index]');
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String || entry.key.toString().trim().isEmpty) {
        _fail('Mp cache value map keys must be non-empty strings.', path: path);
      }
      _validateCacheValue(entry.value, path: '$path.${entry.key}');
    }
    return;
  }
  _fail('Mp cache value must be JSON-safe.', path: path);
}

Never _unsupportedNode(String type, {required String path}) {
  _fail(
    'Unsupported Mp node type "$type".',
    path: '$path.type',
    details: <String, dynamic>{'nodeType': type},
  );
}

Never _unsupportedAction(String type, {required String path}) {
  _fail(
    'Unsupported Mp action type "$type".',
    path: '$path.type',
    details: <String, dynamic>{'actionType': type},
  );
}

Never _fail(
  String message, {
  required String path,
  Map<String, dynamic> details = const <String, dynamic>{},
}) {
  throw MiniProgramRenderException(
    message: 'Invalid Mp screen JSON: $message',
    details: <String, dynamic>{'path': path, ...details},
  );
}
