part of '../../../mp_screen_renderer.dart';

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

String _collectionDirection(
  Map<String, dynamic> props, {
  required String path,
}) {
  final direction =
      _optionalStableString(props, 'direction', path: path) ?? 'vertical';
  if (direction != 'vertical' && direction != 'horizontal') {
    _fail(
      'Mp collection direction must be vertical or horizontal.',
      path: '$path.direction',
    );
  }
  return direction;
}

num? _collectionHeight(
  Map<String, dynamic> props, {
  required String direction,
  required String path,
}) {
  final height = _optionalPositiveNumberValue(
    props['height'],
    path: '$path.height',
  );
  if (direction == 'horizontal' && height == null) {
    _fail('Mp horizontal collections require height.', path: '$path.height');
  }
  return height;
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
