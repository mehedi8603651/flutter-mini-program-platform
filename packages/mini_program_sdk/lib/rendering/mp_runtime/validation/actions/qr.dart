part of '../../../mp_screen_renderer.dart';

extension _MpQrActionValidation on MpScreenValidator {
  _MpAction _parseQrScanAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'allowTorch',
      'timeoutMs',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'allowTorch': _requiredBoolValue(
          props['allowTorch'],
          path: '$path.props.allowTorch',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'timeoutMs': _boundedIntValue(
          props['timeoutMs'],
          path: '$path.props.timeoutMs',
          minimum: 1000,
          maximum: 120000,
        ),
      },
    );
  }
}
