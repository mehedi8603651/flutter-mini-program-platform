part of '../../../mp_screen_renderer.dart';

extension _MpFileActionValidation on MpScreenValidator {
  _MpAction _parseFileUploadAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'endpoint',
      'mimeTypes',
      'mediaRefs',
      'multiple',
      'fieldName',
      'metadata',
      'progressState',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final metadata = _optionalMap(
      props['metadata'],
      path: '$path.props.metadata',
    );
    _validateCacheValue(metadata, path: '$path.props.metadata');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'endpoint': _fileEndpoint(props, path),
        'mimeTypes': _fileMimeTypes(props['mimeTypes'], path),
        'mediaRefs': _fileMediaRefs(props['mediaRefs'], path),
        'multiple':
            _optionalBool(props['multiple'], path: '$path.props.multiple') ??
            false,
        'fieldName':
            _optionalFieldName(props, 'fieldName', path: '$path.props') ??
            'file',
        'metadata': metadata,
        ..._fileStateProps(props, path),
      },
    );
  }

  _MpAction _parseFileDownloadAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'endpoint',
      'method',
      'request',
      'destination',
      'suggestedName',
      'expectedMimeType',
      'progressState',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp file.download method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final request = _optionalMap(props['request'], path: '$path.props.request');
    _validateCacheValue(request, path: '$path.props.request');
    final destination =
        _optionalStableString(props, 'destination', path: '$path.props') ??
        'downloads';
    if (!const <String>{
      'downloads',
      'choose',
      'temporary',
    }.contains(destination)) {
      _fail(
        'Mp file.download destination is unsupported.',
        path: '$path.props.destination',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'endpoint': _fileEndpoint(props, path),
        'method': method,
        'request': request,
        'destination': destination,
        if (props.containsKey('suggestedName'))
          'suggestedName': _fileStringOrBinding(
            props['suggestedName'],
            path: '$path.props.suggestedName',
          ),
        if (props.containsKey('expectedMimeType'))
          'expectedMimeType': _fileMimeType(
            _requiredStableString(
              props,
              'expectedMimeType',
              path: '$path.props',
            ),
            '$path.props.expectedMimeType',
          ),
        ..._fileStateProps(props, path),
      },
    );
  }

  _MpAction _parseFileCancelAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'transferId',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'transferId': _fileStringOrBinding(
          props['transferId'],
          path: '$path.props.transferId',
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

  Map<String, dynamic> _fileStateProps(
    Map<String, dynamic> props,
    String path,
  ) => <String, dynamic>{
    'progressState': _requiredStateKey(
      props,
      'progressState',
      path: '$path.props',
    ),
    'targetState': _requiredStateKey(props, 'targetState', path: '$path.props'),
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

  String _fileEndpoint(Map<String, dynamic> props, String path) {
    final endpoint = _requiredStableString(
      props,
      'endpoint',
      path: '$path.props',
    );
    final uri = Uri.tryParse(endpoint);
    final normalized = endpoint.replaceFirst(RegExp(r'^/+'), '');
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        normalized.isEmpty ||
        Uri.parse(normalized).pathSegments.contains('..')) {
      _fail(
        'Mp file transfer endpoint must be a safe relative path.',
        path: '$path.props.endpoint',
      );
    }
    return normalized;
  }

  List<String> _fileMimeTypes(Object? value, String path) {
    if (value is! List || value.isEmpty || value.length > 32) {
      _fail(
        'Mp file.upload mimeTypes must contain 1-32 values.',
        path: '$path.props.mimeTypes',
      );
    }
    final result = <String>[];
    for (var index = 0; index < value.length; index++) {
      final item = value[index];
      if (item is! String) {
        _fail(
          'Mp file.upload MIME types must be strings.',
          path: '$path.props.mimeTypes[$index]',
        );
      }
      final normalized = _fileMimeType(item, '$path.props.mimeTypes[$index]');
      if (!result.contains(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  List<String> _fileMediaRefs(Object? value, String path) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List || value.length > 32) {
      _fail(
        'Mp file.upload mediaRefs must contain at most 32 values.',
        path: '$path.props.mediaRefs',
      );
    }
    final result = <String>[];
    for (var index = 0; index < value.length; index++) {
      final mediaRef = _fileStringOrBinding(
        value[index],
        path: '$path.props.mediaRefs[$index]',
      );
      if (!result.contains(mediaRef)) {
        result.add(mediaRef);
      }
    }
    return result;
  }

  String _fileMimeType(String value, String path) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '*/*') {
      return normalized;
    }
    final parts = normalized.split('/');
    final token = RegExp(r'^[a-z0-9!#$&^_.+-]+$');
    if (parts.length != 2 ||
        !token.hasMatch(parts.first) ||
        (parts.last != '*' && !token.hasMatch(parts.last))) {
      _fail('Mp file MIME type is invalid.', path: path);
    }
    return normalized;
  }

  String _fileStringOrBinding(Object? value, {required String path}) {
    if (value is! String || value.trim().isEmpty) {
      _fail('Mp field must be a non-empty string.', path: path);
    }
    if (value.length > MpScreenValidator.maxLiteralTextLength) {
      _fail(
        'Mp string literal exceeds the maximum length.',
        path: path,
        details: <String, dynamic>{
          'length': value.length,
          'MpScreenValidator.maxLiteralTextLength':
              MpScreenValidator.maxLiteralTextLength,
        },
      );
    }
    if (_MpBindingResolver.containsBinding(value) &&
        !_MpBindingResolver.isSingleBindingExpression(value)) {
      _fail(
        'Mp field must be a literal or full binding expression.',
        path: path,
      );
    }
    return value;
  }
}
