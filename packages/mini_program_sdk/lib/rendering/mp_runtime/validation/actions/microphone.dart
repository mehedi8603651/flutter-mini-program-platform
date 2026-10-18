part of '../../../mp_screen_renderer.dart';

extension _MpMicrophoneActionValidation on MpScreenValidator {
  _MpAction _parseMicrophoneAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    if (type != ActionNames.microphoneRecord) {
      _validateObjectKeys(props, const <String>{}, path: '$path.props');
      return _MpAction(type: type, props: const {});
    }
    _validateObjectKeys(props, const {
      'maxDurationSeconds',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final normalized = <String, dynamic>{
      'maxDurationSeconds': _boundedIntValue(
        props['maxDurationSeconds'] ?? 60,
        path: '$path.props.maxDurationSeconds',
        minimum: 1,
        maximum: 600,
      ),
      'targetState': _requiredStateKey(
        props,
        'targetState',
        path: '$path.props',
      ),
      for (final name in const ['statusState', 'errorState'])
        if (props.containsKey(name))
          name: _requiredStateKey(props, name, path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredString(props, 'requestId', path: '$path.props'),
    };
    return _MpAction(type: type, props: normalized);
  }
}
