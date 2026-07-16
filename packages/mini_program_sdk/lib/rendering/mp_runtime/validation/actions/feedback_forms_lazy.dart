part of '../../../mp_screen_renderer.dart';

extension _MpFeedbackFormLazyActionValidation on MpScreenValidator {
  _MpAction _parseLazyChunkLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'id'}, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'id': _requiredStableString(props, 'id', path: '$path.props'),
      },
    );
  }

  _MpAction _parseFormSubmitAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'endpoint',
      'requestId',
      'method',
      'body',
      'cacheTtlSeconds',
      'onSuccess',
      'onError',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'POST',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      if (props.containsKey('onSuccess'))
        'onSuccess': _parseAction(
          props['onSuccess'],
          path: '$path.props.onSuccess',
        ),
      if (props.containsKey('onError'))
        'onError': _parseAction(props['onError'], path: '$path.props.onError'),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseToastAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'message',
      'durationMs',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'message': _requiredString(props, 'message', path: '$path.props'),
        'durationMs':
            _optionalPositiveInt(
              props['durationMs'],
              path: '$path.props.durationMs',
            ) ??
            2400,
      },
    );
  }

  _MpAction _parseDialogAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'title',
      'message',
      'confirmLabel',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('title'))
          'title': _requiredString(props, 'title', path: '$path.props'),
        'message': _requiredString(props, 'message', path: '$path.props'),
        'confirmLabel': props.containsKey('confirmLabel')
            ? _requiredString(props, 'confirmLabel', path: '$path.props')
            : 'OK',
      },
    );
  }
}
