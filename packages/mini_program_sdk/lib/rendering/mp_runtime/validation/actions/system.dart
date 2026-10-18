part of '../../../mp_screen_renderer.dart';

extension _MpSystemActionValidation on MpScreenValidator {
  _MpAction _parseSystemAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    final extra = switch (type) {
      ActionNames.clipboardWriteText => const {'text', 'sensitive'},
      ActionNames.vibrationTrigger => const {'effect'},
      ActionNames.phoneOpenDialer => const {'number'},
      _ => const <String>{},
    };
    _validateObjectKeys(props, {
      ...extra,
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final result = <String, dynamic>{
      for (final name in const ['targetState', 'statusState', 'errorState'])
        if (props.containsKey(name) ||
            name == 'targetState' && type == ActionNames.clipboardReadText)
          name: _requiredStateKey(props, name, path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
    };
    if (type == ActionNames.clipboardWriteText) {
      final text = props['text'];
      if (text is! String || text.length > miniProgramClipboardMaxTextLength) {
        _fail(
          'Clipboard text must be a bounded string.',
          path: '$path.props.text',
        );
      }
      final sensitive = props['sensitive'] ?? true;
      if (sensitive is! bool) {
        _fail('sensitive must be a boolean.', path: '$path.props.sensitive');
      }
      result.addAll({'text': text, 'sensitive': sensitive});
    } else if (type == ActionNames.vibrationTrigger) {
      final effect = props['effect'] ?? 'light';
      if (!MiniProgramVibrationEffect.values.any((e) => e.name == effect)) {
        _fail('Unknown system haptic effect.', path: '$path.props.effect');
      }
      result['effect'] = effect;
    } else if (type == ActionNames.phoneOpenDialer) {
      final number = props['number'];
      if (number is! String || number.length > 256) {
        _fail(
          'Dialer number must be a phone number or full binding.',
          path: '$path.props.number',
        );
      }
      if (_MpBindingResolver.isSingleBindingExpression(number)) {
        result['number'] = number;
      } else {
        try {
          result['number'] = normalizeMiniProgramPhoneNumber(number);
        } on FormatException {
          _fail('Invalid ordinary phone number.', path: '$path.props.number');
        }
      }
    }
    return _MpAction(type: type, props: result);
  }
}
