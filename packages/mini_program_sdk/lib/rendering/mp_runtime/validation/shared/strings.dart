part of '../../../mp_screen_renderer.dart';

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

String _dataFieldPath(
  Map<String, dynamic> props,
  String key, {
  required String path,
}) {
  final value = _requiredStableString(props, key, path: path);
  if (!MpScreenValidator._dataFieldPathPattern.hasMatch(value)) {
    _fail('Mp "$key" must be a dotted field path.', path: '$path.$key');
  }
  return value;
}
