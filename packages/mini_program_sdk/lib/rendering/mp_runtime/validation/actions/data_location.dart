part of '../../../mp_screen_renderer.dart';

extension _MpDataLocationActionValidation on MpScreenValidator {
  _MpAction _parseDataLoadJsonAssetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'id',
      'asset',
      'ttlMs',
      'forceRefresh',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final id = _requiredStableString(props, 'id', path: '$path.props');
    if (!MpScreenValidator._dataResourceIdPattern.hasMatch(id)) {
      _fail('Mp data resource ID is invalid.', path: '$path.props.id');
    }
    final asset = _requiredStableString(props, 'asset', path: '$path.props');
    if (asset.length > miniProgramJsonAssetPathMaxLength ||
        !MpScreenValidator._jsonAssetPathPattern.hasMatch(asset) ||
        asset.contains('..')) {
      _fail(
        'Mp JSON asset path is invalid or unsafe.',
        path: '$path.props.asset',
      );
    }
    final ttlMs = _requiredPositiveIntValue(
      props['ttlMs'],
      path: '$path.props.ttlMs',
    );
    if (ttlMs > const Duration(days: 3650).inMilliseconds) {
      _fail(
        'Mp JSON asset TTL cannot exceed 3650 days.',
        path: '$path.props.ttlMs',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'id': id,
        'asset': asset,
        'ttlMs': ttlMs,
        'forceRefresh': _requiredBoolValue(
          props['forceRefresh'],
          path: '$path.props.forceRefresh',
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

  _MpAction _parseDataSearchAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'resourceId',
      'query',
      'fields',
      'itemsPath',
      'minQueryLength',
      'limit',
      'targetState',
      'statusState',
      'errorState',
    }, path: '$path.props');
    final resourceId = _requiredStableString(
      props,
      'resourceId',
      path: '$path.props',
    );
    if (!MpScreenValidator._dataResourceIdPattern.hasMatch(resourceId)) {
      _fail('Mp data resource ID is invalid.', path: '$path.props.resourceId');
    }
    final queryValue = props['query'];
    if (queryValue is! String ||
        (!_MpBindingResolver.isSingleBindingExpression(queryValue) &&
            queryValue.length > 256)) {
      _fail(
        'Mp data search query must be a string or full binding up to 256 characters.',
        path: '$path.props.query',
      );
    }
    final rawFields = props['fields'];
    if (rawFields is! List || rawFields.isEmpty || rawFields.length > 8) {
      _fail(
        'Mp data search requires from 1 to 8 fields.',
        path: '$path.props.fields',
      );
    }
    final fields = <String>[];
    final seenFields = <String>{};
    for (var index = 0; index < rawFields.length; index += 1) {
      final field = rawFields[index];
      if (field is! String ||
          !MpScreenValidator._dataFieldPathPattern.hasMatch(field)) {
        _fail(
          'Mp data search field is invalid.',
          path: '$path.props.fields[$index]',
        );
      }
      if (!seenFields.add(field)) {
        _fail(
          'Mp data search fields must be unique.',
          path: '$path.props.fields[$index]',
        );
      }
      fields.add(field);
    }
    final minQueryLength = _boundedIntValue(
      props['minQueryLength'],
      path: '$path.props.minQueryLength',
      minimum: 0,
      maximum: 256,
    );
    final limit = _boundedIntValue(
      props['limit'],
      path: '$path.props.limit',
      minimum: 1,
      maximum: 100,
    );
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'resourceId': resourceId,
        'query': queryValue,
        'fields': fields,
        if (props.containsKey('itemsPath'))
          'itemsPath': _dataFieldPath(props, 'itemsPath', path: '$path.props'),
        'minQueryLength': minQueryLength,
        'limit': limit,
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

  _MpAction _parseLocationGetCurrentAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'accuracy',
      'timeoutMs',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final accuracy = _requiredStableString(
      props,
      'accuracy',
      path: '$path.props',
    );
    if (accuracy != 'approximate') {
      _fail(
        'Mp location accuracy must be "approximate".',
        path: '$path.props.accuracy',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'accuracy': accuracy,
        'timeoutMs': _boundedIntValue(
          props['timeoutMs'],
          path: '$path.props.timeoutMs',
          minimum: 1000,
          maximum: 60000,
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
