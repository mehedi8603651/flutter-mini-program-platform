part of '../../../mp_screen_renderer.dart';

extension _MpAuthBackendActionValidation on MpScreenValidator {
  _MpAction _parseShowEmailAuthAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'mode'}, path: '$path.props');
    final mode = _optionalStableString(props, 'mode', path: '$path.props');
    if (mode != null && mode != 'signIn' && mode != 'signUp') {
      _fail(
        'Mp auth.showEmailAuth mode must be signIn or signUp.',
        path: '$path.props.mode',
      );
    }
    return _MpAction(type: type, props: props);
  }

  _MpAction _parseBackendCallAction(
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
          _optionalStableString(props, 'method', path: '$path.props') ?? 'GET',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseBackendQueryAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'method',
      'body',
      'cacheTtlSeconds',
      'forceRefresh',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'GET',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      'forceRefresh':
          _optionalBool(
            props['forceRefresh'],
            path: '$path.props.forceRefresh',
          ) ??
          false,
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseBackendLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'limit',
      'initialCursor',
      'cursorParam',
      'limitParam',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'cacheTtlSeconds',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      if (props.containsKey('endpoint'))
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
      'limit':
          _optionalPositiveInt(props['limit'], path: '$path.props.limit') ?? 20,
      if (props.containsKey('initialCursor'))
        'initialCursor': _requiredStableString(
          props,
          'initialCursor',
          path: '$path.props',
        ),
      'cursorParam':
          _optionalStableString(props, 'cursorParam', path: '$path.props') ??
          'cursor',
      'limitParam':
          _optionalStableString(props, 'limitParam', path: '$path.props') ??
          'limit',
      'itemsPath':
          _optionalStableString(props, 'itemsPath', path: '$path.props') ??
          'items',
      'nextCursorPath':
          _optionalStableString(props, 'nextCursorPath', path: '$path.props') ??
          'nextCursor',
      'hasMorePath':
          _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
          'hasMore',
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseSearchLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'queryState',
      'targetState',
      'endpoint',
      'requestId',
      'queryParam',
      'cursorParam',
      'limitParam',
      'method',
      'body',
      'limit',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'statusState',
      'errorState',
      'cacheTtlSeconds',
      'skipWhenNoQuery',
    }, path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp search.loadMore method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final body = _optionalMap(props['body'], path: '$path.props.body');
    _validateCacheValue(body, path: '$path.props.body');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'queryState': _requiredStateKey(
          props,
          'queryState',
          path: '$path.props',
        ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'queryParam':
            _optionalFieldName(props, 'queryParam', path: '$path.props') ?? 'q',
        'cursorParam':
            _optionalFieldName(props, 'cursorParam', path: '$path.props') ??
            'cursor',
        'limitParam':
            _optionalFieldName(props, 'limitParam', path: '$path.props') ??
            'limit',
        'method': method,
        'body': body,
        'limit':
            _optionalSearchLimit(props['limit'], path: '$path.props.limit') ??
            20,
        'itemsPath':
            _optionalStableString(props, 'itemsPath', path: '$path.props') ??
            'items',
        'nextCursorPath':
            _optionalStableString(
              props,
              'nextCursorPath',
              path: '$path.props',
            ) ??
            'nextCursor',
        'hasMorePath':
            _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
            'hasMore',
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
        if (props.containsKey('cacheTtlSeconds'))
          'cacheTtlSeconds': _optionalPositiveInt(
            props['cacheTtlSeconds'],
            path: '$path.props.cacheTtlSeconds',
          ),
        'skipWhenNoQuery':
            _optionalBool(
              props['skipWhenNoQuery'],
              path: '$path.props.skipWhenNoQuery',
            ) ??
            true,
      },
    );
  }

  _MpAction _parseSearchClearAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'queryState',
      'targetState',
      'statusState',
      'errorState',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'queryState': _requiredStateKey(
          props,
          'queryState',
          path: '$path.props',
        ),
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
      },
    );
  }

  _MpAction _parseSearchRefreshAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'queryState',
      'targetState',
      'endpoint',
      'requestId',
      'queryParam',
      'limitParam',
      'method',
      'body',
      'limit',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'statusState',
      'errorState',
      'cacheTtlSeconds',
      'skipWhenNoQuery',
    }, path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp search.refresh method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final body = _optionalMap(props['body'], path: '$path.props.body');
    _validateCacheValue(body, path: '$path.props.body');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'queryState': _requiredStateKey(
          props,
          'queryState',
          path: '$path.props',
        ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'queryParam':
            _optionalFieldName(props, 'queryParam', path: '$path.props') ?? 'q',
        'limitParam':
            _optionalFieldName(props, 'limitParam', path: '$path.props') ??
            'limit',
        'method': method,
        'body': body,
        'limit':
            _optionalSearchLimit(props['limit'], path: '$path.props.limit') ??
            20,
        'itemsPath':
            _optionalStableString(props, 'itemsPath', path: '$path.props') ??
            'items',
        'nextCursorPath':
            _optionalStableString(
              props,
              'nextCursorPath',
              path: '$path.props',
            ) ??
            'nextCursor',
        'hasMorePath':
            _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
            'hasMore',
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
        if (props.containsKey('cacheTtlSeconds'))
          'cacheTtlSeconds': _optionalPositiveInt(
            props['cacheTtlSeconds'],
            path: '$path.props.cacheTtlSeconds',
          ),
        'skipWhenNoQuery':
            _optionalBool(
              props['skipWhenNoQuery'],
              path: '$path.props.skipWhenNoQuery',
            ) ??
            true,
      },
    );
  }
}
