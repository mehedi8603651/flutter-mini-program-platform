part of '../../../mp_screen_renderer.dart';

extension _MpShareActionValidation on MpScreenValidator {
  _MpAction _parseShareOpenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'title',
      'text',
      'url',
      'mediaRefs',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    if (!props.containsKey('text') &&
        !props.containsKey('url') &&
        !props.containsKey('mediaRefs')) {
      _fail(
        'Mp share.open requires text, url, or mediaRefs.',
        path: '$path.props',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('title'))
          'title': _shareString(
            props['title'],
            path: '$path.props.title',
            maxLength: miniProgramShareMaxTitleLength,
          ),
        if (props.containsKey('text'))
          'text': _shareString(
            props['text'],
            path: '$path.props.text',
            maxLength: miniProgramShareMaxTextLength,
          ),
        if (props.containsKey('url'))
          'url': _shareUrl(props['url'], path: '$path.props.url'),
        if (props.containsKey('mediaRefs'))
          'mediaRefs': _shareMediaRefs(
            props['mediaRefs'],
            path: '$path.props.mediaRefs',
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

  String _shareString(
    Object? value, {
    required String path,
    required int maxLength,
  }) {
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      _fail(
        'Mp share content must contain 1-$maxLength characters.',
        path: path,
      );
    }
    return value.trim();
  }

  String _shareUrl(Object? value, {required String path}) {
    final normalized = _shareString(
      value,
      path: path,
      maxLength: miniProgramShareMaxUrlLength,
    );
    if (_MpBindingResolver.containsBinding(normalized)) {
      if (!_MpBindingResolver.isSingleBindingExpression(normalized)) {
        _fail(
          'Mp share URL must be an HTTPS literal or one full binding.',
          path: path,
        );
      }
      return normalized;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _fail('Mp share URL must use HTTPS.', path: path);
    }
    return uri.toString();
  }

  Object _shareMediaRefs(Object? value, {required String path}) {
    if (value is String &&
        _MpBindingResolver.isSingleBindingExpression(value)) {
      return value;
    }
    if (value is! List ||
        value.isEmpty ||
        value.length > miniProgramShareMaxMediaItems) {
      _fail(
        'Mp share mediaRefs must contain 1-$miniProgramShareMaxMediaItems references or one full binding.',
        path: path,
      );
    }
    final refs = <String>[];
    for (var index = 0; index < value.length; index++) {
      final ref = _shareString(
        value[index],
        path: '$path[$index]',
        maxLength: 512,
      );
      if (_MpBindingResolver.containsBinding(ref) &&
          !_MpBindingResolver.isSingleBindingExpression(ref)) {
        _fail(
          'Mp share media references must be literals or full bindings.',
          path: '$path[$index]',
        );
      }
      if (!refs.contains(ref)) refs.add(ref);
    }
    return refs;
  }
}
