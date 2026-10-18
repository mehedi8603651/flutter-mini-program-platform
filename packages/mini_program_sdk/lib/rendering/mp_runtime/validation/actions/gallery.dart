part of '../../../mp_screen_renderer.dart';

extension _MpGalleryActionValidation on MpScreenValidator {
  _MpAction _parseGalleryPickImagesAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const {
      'maxImages',
      'maxWidth',
      'maxHeight',
      'quality',
      'targetState',
      'statusState',
      'errorState',
      'requestId',
    }, path: '$path.props');
    final normalized = <String, dynamic>{};
    for (final (name, fallback, minimum, maximum) in const [
      ('maxImages', 1, 1, 30),
      ('maxWidth', 2048, 64, 8192),
      ('maxHeight', 2048, 64, 8192),
      ('quality', 90, 1, 100),
    ]) {
      normalized[name] = _boundedIntValue(
        props.containsKey(name) ? props[name] : fallback,
        path: '$path.props.$name',
        minimum: minimum,
        maximum: maximum,
      );
    }
    normalized['targetState'] = _requiredStateKey(
      props,
      'targetState',
      path: '$path.props',
    );
    for (final name in const ['statusState', 'errorState']) {
      if (props.containsKey(name)) {
        normalized[name] = _requiredStateKey(props, name, path: '$path.props');
      }
    }
    if (props.containsKey('requestId')) {
      normalized['requestId'] = _requiredString(
        props,
        'requestId',
        path: '$path.props',
      );
    }
    return _MpAction(type: type, props: normalized);
  }

  _MpAction _parseGalleryCancelAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{}, path: '$path.props');
    return _MpAction(type: type, props: const {});
  }
}
