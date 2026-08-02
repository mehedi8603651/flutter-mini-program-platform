part of '../../../mp_screen_renderer.dart';

extension _MpMediaPlaybackNodeValidation on MpScreenValidator {
  _MpNode _parseVideoViewNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'aspectRatio',
      'autoplay',
      'cacheMode',
      'controls',
      'errorState',
      'fit',
      'loop',
      'muted',
      'onEnded',
      'onError',
      'onReady',
      'playerId',
      'poster',
      'posterSource',
      'semanticLabel',
      'source',
      'speed',
      'statusState',
      'volume',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'videoView',
      props: <String, dynamic>{
        'aspectRatio': _boundedNumber(
          props['aspectRatio'],
          path: '$path.props.aspectRatio',
          minimum: 0.25,
          maximum: 4,
        ),
        'autoplay': _requiredBoolValue(
          props['autoplay'],
          path: '$path.props.autoplay',
        ),
        'cacheMode': _parseMediaCacheMode(props, path),
        'controls': _requiredBoolValue(
          props['controls'],
          path: '$path.props.controls',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        'fit': _optionalImageFit(props, 'fit', path: '$path.props') ?? 'cover',
        'loop': _requiredBoolValue(props['loop'], path: '$path.props.loop'),
        'muted': _requiredBoolValue(props['muted'], path: '$path.props.muted'),
        if (props.containsKey('onEnded'))
          'onEnded': _parseAction(
            props['onEnded'],
            path: '$path.props.onEnded',
          ),
        if (props.containsKey('onError'))
          'onError': _parseAction(
            props['onError'],
            path: '$path.props.onError',
          ),
        if (props.containsKey('onReady'))
          'onReady': _parseAction(
            props['onReady'],
            path: '$path.props.onReady',
          ),
        'playerId': _parseMediaPlayerId(props, path),
        if (props.containsKey('poster'))
          'poster': _requiredString(props, 'poster', path: '$path.props'),
        if (props.containsKey('poster'))
          'posterSource': _optionalImageSource(
            props,
            'posterSource',
            path: '$path.props',
          )!,
        'semanticLabel': _requiredString(
          props,
          'semanticLabel',
          path: '$path.props',
        ),
        'source': _parseMediaPlaybackSource(
          props['source'],
          path: '$path.props.source',
        ),
        'speed': _boundedNumber(
          props['speed'],
          path: '$path.props.speed',
          minimum: 0.25,
          maximum: 3,
        ),
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        'volume': _boundedNumber(
          props['volume'],
          path: '$path.props.volume',
          minimum: 0,
          maximum: 1,
        ),
      },
      children: const <_MpNode>[],
    );
  }
}
