part of '../../../mp_screen_renderer.dart';

extension _MpCameraFlashlightActionValidation on MpScreenValidator {
  _MpAction _parseCameraCapturePhotoAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'maxWidth',
      'maxHeight',
      'quality',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('maxWidth'))
          'maxWidth': _boundedIntValue(
            props['maxWidth'],
            path: '$path.props.maxWidth',
            minimum: 64,
            maximum: 8192,
          ),
        if (props.containsKey('maxHeight'))
          'maxHeight': _boundedIntValue(
            props['maxHeight'],
            path: '$path.props.maxHeight',
            minimum: 64,
            maximum: 8192,
          ),
        'quality': _boundedIntValue(
          props['quality'],
          path: '$path.props.quality',
          minimum: 1,
          maximum: 100,
        ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        ..._cameraOptionalStateProps(props, path, includeTarget: false),
      },
    );
  }

  _MpAction _parseCameraCancelAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    return _MpAction(type: type, props: _cameraOptionalStateProps(props, path));
  }

  _MpAction _parseFlashlightAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    if (type == ActionNames.flashlightGetStatus &&
        !props.containsKey('targetState')) {
      _fail(
        'Mp flashlight.getStatus requires targetState.',
        path: '$path.props.targetState',
      );
    }
    return _MpAction(type: type, props: _cameraOptionalStateProps(props, path));
  }

  Map<String, dynamic> _cameraOptionalStateProps(
    Map<String, dynamic> props,
    String path, {
    bool includeTarget = true,
  }) => <String, dynamic>{
    if (includeTarget && props.containsKey('targetState'))
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
      'errorState': _requiredStateKey(props, 'errorState', path: '$path.props'),
    if (props.containsKey('requestId'))
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
  };
}
