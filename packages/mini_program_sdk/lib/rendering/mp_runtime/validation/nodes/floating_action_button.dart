part of '../../../mp_screen_renderer.dart';

extension _MpFloatingActionButtonValidation on MpScreenValidator {
  _MpNode _parseFloatingActionButtonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'variant',
      'icon',
      'label',
      'semanticLabel',
      'action',
      'enabled',
      'backgroundColor',
      'foregroundColor',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final variant = _requiredStableString(
      props,
      'variant',
      path: '$path.props',
    );
    if (!const {'standard', 'small', 'large', 'extended'}.contains(variant)) {
      _fail(
        'Mp floatingActionButton has an invalid variant.',
        path: '$path.props.variant',
      );
    }
    final extended = variant == 'extended';
    if (!extended && props.containsKey('label')) {
      _fail(
        'Only extended floatingActionButton accepts a label.',
        path: '$path.props.label',
      );
    }
    String text(String key) {
      final value = _requiredString(props, key, path: '$path.props');
      if (value.length > 512) {
        _fail(
          'Mp floatingActionButton text cannot exceed 512 characters.',
          path: '$path.props.$key',
        );
      }
      return value;
    }

    if (props.containsKey('enabled') && props['enabled'] == null) {
      _fail(
        'Mp floatingActionButton enabled must be a boolean.',
        path: '$path.props.enabled',
      );
    }
    return _MpNode(
      type: 'floatingActionButton',
      props: <String, dynamic>{
        'variant': variant,
        if (!extended || props.containsKey('icon'))
          'icon': _requiredIconName(props, 'icon', path: '$path.props'),
        if (extended) 'label': text('label'),
        'semanticLabel': text('semanticLabel'),
        'action': _parseAction(props['action'], path: '$path.props.action'),
        'enabled':
            _optionalBool(props['enabled'], path: '$path.props.enabled') ??
            true,
        for (final color in ['backgroundColor', 'foregroundColor'])
          if (props.containsKey(color))
            color: _requiredHexColor(props, color, path: '$path.props'),
      },
      children: const <_MpNode>[],
    );
  }
}
