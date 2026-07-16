part of '../../../mp_screen_renderer.dart';

extension _MpLazyBackendNodeValidation on MpScreenValidator {
  _MpNode _parseLazyNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'actions',
      'bucket',
      'cacheKey',
      'error',
      'id',
      'once',
      'placeholder',
      'refreshIfCached',
      'retry',
      'retryDelayMs',
      'statusState',
      'targetState',
      'ttlMs',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'lazy', path: path);

    final cacheKey = props.containsKey('cacheKey')
        ? _requiredCacheKey(props, 'cacheKey', path: '$path.props')
        : null;
    final targetState = props.containsKey('targetState')
        ? _requiredStateKey(props, 'targetState', path: '$path.props')
        : null;
    if (cacheKey != null && targetState == null) {
      _fail(
        'Mp lazy requires targetState when cacheKey is provided.',
        path: '$path.props.targetState',
      );
    }

    return _MpNode(
      type: 'lazy',
      props: <String, dynamic>{
        'actions': _parseLazyActions(
          props['actions'],
          path: '$path.props.actions',
        ),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (cacheKey != null) 'cacheKey': cacheKey,
        'id': _requiredStableString(props, 'id', path: '$path.props'),
        'once': props.containsKey('once')
            ? _requiredBoolValue(props['once'], path: '$path.props.once')
            : true,
        'refreshIfCached': props.containsKey('refreshIfCached')
            ? _requiredBoolValue(
                props['refreshIfCached'],
                path: '$path.props.refreshIfCached',
              )
            : false,
        'retry':
            _optionalNonNegativeInt(
              props['retry'],
              path: '$path.props.retry',
            ) ??
            0,
        'retryDelayMs':
            _optionalNonNegativeInt(
              props['retryDelayMs'],
              path: '$path.props.retryDelayMs',
            ) ??
            300,
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (targetState != null) 'targetState': targetState,
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{'placeholder', 'error'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: children,
    );
  }

  _MpNode _parseLazyChunkNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'bucket',
      'cacheKeyPrefix',
      'cursorState',
      'empty',
      'end',
      'error',
      'hasMoreState',
      'id',
      'initialActions',
      'itemTemplate',
      'itemsState',
      'loadingMore',
      'loadMoreActions',
      'loadMore',
      'once',
      'placeholder',
      'refreshIfCached',
      'retry',
      'retryDelayMs',
      'statusState',
      'ttlMs',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    if (!props.containsKey('itemTemplate')) {
      _fail(
        'Mp lazyChunk requires an itemTemplate.',
        path: '$path.props.itemTemplate',
      );
    }

    return _MpNode(
      type: 'lazyChunk',
      props: <String, dynamic>{
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('cacheKeyPrefix'))
          'cacheKeyPrefix': _requiredCacheKey(
            props,
            'cacheKeyPrefix',
            path: '$path.props',
          ),
        if (props.containsKey('cursorState'))
          'cursorState': _requiredStateKey(
            props,
            'cursorState',
            path: '$path.props',
          ),
        if (props.containsKey('hasMoreState'))
          'hasMoreState': _requiredStateKey(
            props,
            'hasMoreState',
            path: '$path.props',
          ),
        'id': _requiredStableString(props, 'id', path: '$path.props'),
        'initialActions': _parseRequiredLazyActions(
          props['initialActions'],
          name: 'initialActions',
          path: '$path.props.initialActions',
        ),
        'itemsState': _requiredStateKey(
          props,
          'itemsState',
          path: '$path.props',
        ),
        'loadMoreActions': _parseRequiredLazyActions(
          props['loadMoreActions'],
          name: 'loadMoreActions',
          path: '$path.props.loadMoreActions',
        ),
        'once': props.containsKey('once')
            ? _requiredBoolValue(props['once'], path: '$path.props.once')
            : true,
        'refreshIfCached': props.containsKey('refreshIfCached')
            ? _requiredBoolValue(
                props['refreshIfCached'],
                path: '$path.props.refreshIfCached',
              )
            : false,
        'retry':
            _optionalNonNegativeInt(
              props['retry'],
              path: '$path.props.retry',
            ) ??
            0,
        'retryDelayMs':
            _optionalNonNegativeInt(
              props['retryDelayMs'],
              path: '$path.props.retryDelayMs',
            ) ??
            300,
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{
            'empty',
            'end',
            'error',
            'itemTemplate',
            'loadingMore',
            'loadMore',
            'placeholder',
          },
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseAuthBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'loading',
      'signedOut',
      'signedIn',
      'error',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'authBuilder',
      props: _parseTemplateProps(
        props,
        const <String>{'loading', 'signedOut', 'signedIn', 'error'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseBackendBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'method',
      'body',
      'cacheTtlSeconds',
      'forceRefresh',
      'loading',
      'error',
      'empty',
      'child',
      'itemTemplate',
      'itemsPath',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
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
      if (props.containsKey('itemsPath'))
        'itemsPath': _requiredStableString(
          props,
          'itemsPath',
          path: '$path.props',
        ),
    };
    parsedProps.addAll(
      _parseTemplateProps(
        props,
        const <String>{'loading', 'error', 'empty', 'child', 'itemTemplate'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    );
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'backendBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parsePagedBackendBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'itemTemplate',
      'limit',
      'initialCursor',
      'cursorParam',
      'limitParam',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'cacheTtlSeconds',
      'forceRefresh',
      'loading',
      'loadingMore',
      'error',
      'empty',
      'end',
      'loadMore',
    }, path: '$path.props');
    if (!props.containsKey('itemTemplate')) {
      _fail(
        'Mp pagedBackendBuilder requires an itemTemplate.',
        path: '$path.props.itemTemplate',
      );
    }
    final parsedProps = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
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
      'forceRefresh':
          _optionalBool(
            props['forceRefresh'],
            path: '$path.props.forceRefresh',
          ) ??
          false,
    };
    parsedProps.addAll(
      _parseTemplateProps(
        props,
        const <String>{
          'itemTemplate',
          'loading',
          'loadingMore',
          'error',
          'empty',
          'end',
          'loadMore',
        },
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    );
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'pagedBackendBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }
}
