part of '../../../mp_screen_renderer.dart';

extension _MpMapsActionValidation on MpScreenValidator {
  _MpAction _parseMapsAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, {
      'latitude',
      'longitude',
      'name',
      'address',
      'coordinateSystem',
      if (type == ActionNames.mapsOpenDirections) 'mode',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final values = <String, dynamic>{};
    for (final key in ['latitude', 'longitude', 'name', 'address']) {
      final raw = props[key] ?? (key == 'address' ? '' : null);
      if (raw is String &&
          raw.length <= 256 &&
          _MpBindingResolver.isSingleBindingExpression(raw)) {
        values[key] = raw;
        continue;
      }
      try {
        values[key] = switch (key) {
          'latitude' ||
          'longitude' => MiniProgramMapDestination.validateCoordinate(
            raw,
            latitude: key == 'latitude',
          ),
          _ => MiniProgramMapDestination.validateText(
            raw,
            address: key == 'address',
          ),
        };
      } on FormatException {
        _fail('Invalid map destination $key.', path: '$path.props.$key');
      }
    }
    final system = props['coordinateSystem'] ?? 'wgs84';
    if (!MiniProgramMapCoordinateSystem.values.any((v) => v.name == system)) {
      _fail(
        'Unknown map coordinate system.',
        path: '$path.props.coordinateSystem',
      );
    }
    values['coordinateSystem'] = system;
    if (type == ActionNames.mapsOpenDirections) {
      final mode = props['mode'] ?? 'driving';
      if (!MiniProgramMapTravelMode.values.any((v) => v.name == mode)) {
        _fail('Unknown map travel mode.', path: '$path.props.mode');
      }
      values['mode'] = mode;
    }
    for (final key in ['targetState', 'statusState', 'errorState']) {
      if (props.containsKey(key)) {
        values[key] = _requiredStateKey(props, key, path: '$path.props');
      }
    }
    if (props.containsKey('requestId')) {
      values['requestId'] = _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      );
    }
    return _MpAction(type: type, props: values);
  }
}
