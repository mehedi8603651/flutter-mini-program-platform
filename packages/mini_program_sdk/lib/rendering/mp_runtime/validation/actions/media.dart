part of '../../../mp_screen_renderer.dart';

extension _MpMediaActionValidation on MpScreenValidator {
  _MpAction _parseMediaReleaseAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'mediaRef',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'mediaRef': _fileStringOrBinding(
          props['mediaRef'],
          path: '$path.props.mediaRef',
        ),
        if (props.containsKey('targetState'))
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
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
      },
    );
  }
}
