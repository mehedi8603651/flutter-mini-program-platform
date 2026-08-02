part of '../../../mp_screen_renderer.dart';

extension _MpMediaPlaybackActionValidation on MpScreenValidator {
  _MpAction _parseMediaPlaybackAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    final sourceAction =
        type == ActionNames.audioPlay || type == ActionNames.audioPreload;
    final seekAction =
        type == ActionNames.audioSeek || type == ActionNames.videoSeek;
    final getStatus =
        type == ActionNames.audioGetStatus ||
        type == ActionNames.videoGetStatus;
    final allowed = <String>{'playerId', 'requestId'};
    if (sourceAction) {
      allowed.addAll(<String>{
        'source',
        'cacheMode',
        'loop',
        'volume',
        'statusState',
        'errorState',
      });
    }
    if (seekAction) allowed.add('positionMs');
    if (getStatus) allowed.add('targetState');
    if (type == ActionNames.videoSetMuted) allowed.add('muted');
    if (type == ActionNames.videoSetVolume ||
        type == ActionNames.audioSetVolume) {
      allowed.add('volume');
    }
    if (type == ActionNames.videoSetSpeed ||
        type == ActionNames.audioSetSpeed) {
      allowed.add('speed');
    }
    _validateObjectKeys(props, allowed, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (sourceAction) 'cacheMode': _parseMediaCacheMode(props, path),
        if (sourceAction && props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        if (sourceAction)
          'loop': _requiredBoolValue(props['loop'], path: '$path.props.loop'),
        'playerId': _parseMediaPlayerId(props, path),
        if (seekAction)
          'positionMs': _boundedIntValue(
            props['positionMs'],
            path: '$path.props.positionMs',
            minimum: 0,
            maximum: 7 * 24 * 60 * 60 * 1000,
          ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        if (sourceAction)
          'source': _parseMediaPlaybackSource(
            props['source'],
            path: '$path.props.source',
          ),
        if (sourceAction && props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (getStatus)
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
        if (type == ActionNames.videoSetMuted)
          'muted': _requiredBoolValue(
            props['muted'],
            path: '$path.props.muted',
          ),
        if (sourceAction ||
            type == ActionNames.videoSetVolume ||
            type == ActionNames.audioSetVolume)
          'volume': _boundedNumber(
            props['volume'],
            path: '$path.props.volume',
            minimum: 0,
            maximum: 1,
          ),
        if (type == ActionNames.videoSetSpeed ||
            type == ActionNames.audioSetSpeed)
          'speed': _boundedNumber(
            props['speed'],
            path: '$path.props.speed',
            minimum: 0.25,
            maximum: 3,
          ),
      },
    );
  }
}

String _parseMediaPlayerId(Map<String, dynamic> props, String path) {
  final value = _requiredStableString(props, 'playerId', path: '$path.props');
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(value)) {
    _fail('Mp media playerId is invalid.', path: '$path.props.playerId');
  }
  return value;
}

String _parseMediaCacheMode(Map<String, dynamic> props, String path) {
  final value = _requiredStableString(props, 'cacheMode', path: '$path.props');
  if (value != 'streaming' && value != 'temporary') {
    _fail(
      'Mp "cacheMode" must be one of: streaming, temporary.',
      path: '$path.props.cacheMode',
    );
  }
  return value;
}

Map<String, dynamic> _parseMediaPlaybackSource(
  Object? raw, {
  required String path,
}) {
  if (raw is! Map) {
    _fail('Mp media source must be an object.', path: path);
  }
  final source = Map<String, dynamic>.from(raw);
  final kind = source['kind'];
  if (kind == 'asset') {
    _validateObjectKeys(source, const <String>{'kind', 'asset'}, path: path);
    final asset = _requiredStableString(source, 'asset', path: path);
    final parsed = Uri.tryParse(asset);
    if (asset.length > 256 ||
        parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        parsed.pathSegments.any((segment) => segment == '..') ||
        !RegExp(
          r'\.(?:mp3|m4a|aac|mp4|m3u8)$',
          caseSensitive: false,
        ).hasMatch(asset)) {
      _fail('Mp media asset path is invalid.', path: '$path.asset');
    }
    return <String, dynamic>{'kind': 'asset', 'asset': asset};
  }
  if (kind == 'publisher') {
    _validateObjectKeys(source, const <String>{
      'kind',
      'endpoint',
      'parameters',
    }, path: path);
    final endpoint = _requiredStableString(source, 'endpoint', path: path);
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.pathSegments.any((segment) => segment == '..')) {
      _fail('Mp media endpoint must be relative.', path: '$path.endpoint');
    }
    return <String, dynamic>{
      'kind': 'publisher',
      'endpoint': endpoint.replaceFirst(RegExp(r'^/+'), ''),
      if (source.containsKey('parameters'))
        'parameters': _optionalMap(
          source['parameters'],
          path: '$path.parameters',
        ),
    };
  }
  _fail('Mp media source kind is unsupported.', path: '$path.kind');
}
