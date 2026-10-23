part of '../../../mp_screen_renderer.dart';

extension _MpNfcActionValidation on MpScreenValidator {
  _MpAction _parseNfcAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    const stateKeys = ['targetState', 'statusState', 'errorState'];
    final values = <String, dynamic>{};
    if (type == 'nfc.cancel' && props.isNotEmpty) {
      _fail('NFC cancellation takes no properties.', path: '$path.props');
    }
    try {
      values.addAll(
        MiniProgramNfc.arguments(type, {
          for (final entry in props.entries)
            if (!stateKeys.contains(entry.key)) entry.key: entry.value,
        }),
      );
    } on FormatException catch (error) {
      _fail(error.message, path: '$path.props');
    }
    for (final key in stateKeys) {
      if (props.containsKey(key)) {
        values[key] = _requiredStateKey(props, key, path: '$path.props');
      }
    }
    if (type == 'nfc.read' && !props.containsKey('targetState')) {
      _fail('NFC reading requires targetState.', path: '$path.props');
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
            'NFC result state paths must not overlap.',
            path: '$path.props',
          );
        }
      }
    }
    return _MpAction(type: type, props: values);
  }
}
