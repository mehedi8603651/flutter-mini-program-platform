part of '../../../mp_screen_renderer.dart';

extension _MpCacheActionValidation on MpScreenValidator {
  _MpAction _parseCacheSetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'value',
      'ttlMs',
      'priority',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp cache.set requires a value.', path: '$path.props.value');
    }
    _validateCacheValue(props['value'], path: '$path.props.value');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        'value': props['value'],
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        'priority':
            _optionalCachePriority(props, path: '$path.props') ?? 'normal',
      },
    );
  }

  _MpAction _parseCacheGetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'targetState',
      'skipMissing',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('targetState'))
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
        'skipMissing':
            _optionalBool(
              props['skipMissing'],
              path: '$path.props.skipMissing',
            ) ??
            false,
      },
    );
  }

  _MpAction _parseCacheHasAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'targetState',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('targetState'))
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseCacheRemoveAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
      },
    );
  }

  _MpAction _parseCacheClearAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'bucket',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        if (props.containsKey('bucket'))
          'bucket': _optionalCacheBucket(props, path: '$path.props'),
      },
    );
  }

  _MpAction _parseCacheInfoAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'targetState',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
      },
    );
  }
}
