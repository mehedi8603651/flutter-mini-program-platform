part of '../../../mp_screen_renderer.dart';

extension _MpAppBarValidation on MpScreenValidator {
  _MpNode _parseAppBarNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'hasLeading',
      'actionCount',
      'centerTitle',
      'height',
      'leadingWidth',
      'paddingHorizontal',
      'spacing',
      'elevation',
      'backgroundColor',
      'foregroundColor',
      'shadowColor',
    }, path: '$path.props');
    final hasLeading = _requiredBoolValue(
      props['hasLeading'],
      path: '$path.props.hasLeading',
    );
    final actionCount = _boundedIntValue(
      props['actionCount'],
      path: '$path.props.actionCount',
      minimum: 0,
      maximum: 4,
    );
    if (children.length != 1 + (hasLeading ? 1 : 0) + actionCount) {
      _fail(
        'Mp appBar children do not match its leading/title/action metadata.',
        path: '$path.children',
      );
    }
    return _MpNode(
      type: 'appBar',
      props: <String, dynamic>{
        'hasLeading': hasLeading,
        'actionCount': actionCount,
        'centerTitle': _requiredBoolValue(
          props['centerTitle'],
          path: '$path.props.centerTitle',
        ),
        for (final entry in const <String, (num, num)>{
          'height': (48, 160),
          'leadingWidth': (0, 256),
          'paddingHorizontal': (0, 48),
          'spacing': (0, 24),
          'elevation': (0, 24),
        }.entries)
          entry.key: _boundedNumber(
            props[entry.key],
            path: '$path.props.${entry.key}',
            minimum: entry.value.$1,
            maximum: entry.value.$2,
          ),
        for (final key in ['backgroundColor', 'foregroundColor', 'shadowColor'])
          if (props.containsKey(key))
            key: _requiredHexColor(props, key, path: '$path.props'),
      },
      children: children,
    );
  }
}
