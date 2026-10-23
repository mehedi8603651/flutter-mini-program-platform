part of '../../../mp_screen_renderer.dart';

extension _MpBluetoothActionValidation on MpScreenValidator {
  _MpAction _parseBluetoothAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    const stateKeys = ['targetState', 'statusState', 'errorState'];
    final values = <String, dynamic>{};
    try {
      values.addAll(
        MiniProgramBluetooth.arguments(type, {
          for (final entry in props.entries)
            if (!stateKeys.contains(entry.key)) entry.key: entry.value,
        }, allowBindings: true),
      );
    } on FormatException catch (error) {
      _fail(error.message, path: '$path.props');
    }
    for (final key in stateKeys) {
      if (props.containsKey(key)) {
        values[key] = _requiredStateKey(props, key, path: '$path.props');
      }
    }
    if (const {
          'bluetooth.scan',
          'bluetooth.discoverServices',
          'bluetooth.read',
          'bluetooth.subscribe',
        }.contains(type) &&
        !props.containsKey('targetState')) {
      _fail('BLE data actions require targetState.', path: '$path.props');
    }
    final keys = stateKeys
        .map((key) => values[key])
        .whereType<String>()
        .toList();
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        if (keys[i] == keys[j] ||
            keys[i].startsWith('${keys[j]}.') ||
            keys[j].startsWith('${keys[i]}.')) {
          _fail(
            'BLE result state paths must not overlap.',
            path: '$path.props',
          );
        }
      }
    }
    return _MpAction(type: type, props: values);
  }
}
