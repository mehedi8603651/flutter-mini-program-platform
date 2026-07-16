part of '../../../mp_screen_renderer.dart';

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

int _requiredHeadingLevelValue(Object? value, {required String path}) {
  if (value is! int || value < 1 || value > 6) {
    _fail('Mp heading level must be an integer from 1 to 6.', path: path);
  }
  return value;
}
