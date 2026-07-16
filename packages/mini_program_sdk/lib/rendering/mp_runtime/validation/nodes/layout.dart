part of '../../../mp_screen_renderer.dart';

extension _MpLayoutNodeValidation on MpScreenValidator {
  _MpNode _parseSimpleContainer({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateNoProps(props, path: '$path.props');
    return _MpNode(
      type: type,
      props: const <String, dynamic>{},
      children: children,
    );
  }

  _MpNode _parseSizedBoxNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'width',
      'height',
    }, path: '$path.props');
    final width = props['width'];
    final height = props['height'];
    if (width == null && height == null) {
      _fail(
        'Mp sizedBox requires width, height, or both.',
        path: '$path.props',
      );
    }
    _optionalNonNegativeNumber(width, path: '$path.props.width');
    _optionalNonNegativeNumber(height, path: '$path.props.height');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(type: 'sizedBox', props: props, children: const <_MpNode>[]);
  }

  _MpNode _parsePaddingNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'padding'}, path: '$path.props');
    _validateSingleChild(children, nodeType: 'padding', path: path);
    return _MpNode(
      type: 'padding',
      props: <String, dynamic>{
        'padding': _parseSpacing(props['padding'], path: '$path.props.padding'),
      },
      children: children,
    );
  }

  _MpNode _parseAlignNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'alignment',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'align', path: path);
    return _MpNode(
      type: 'align',
      props: <String, dynamic>{
        'alignment':
            _optionalAlignment(props, 'alignment', path: '$path.props') ??
            'center',
      },
      children: children,
    );
  }

  _MpNode _parseCenterNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateNoProps(props, path: '$path.props');
    _validateSingleChild(children, nodeType: 'center', path: path);
    return _MpNode(
      type: 'center',
      props: const <String, dynamic>{},
      children: children,
    );
  }

  _MpNode _parseSpacerNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'flex'}, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'spacer',
      props: <String, dynamic>{
        'flex':
            _optionalPositiveInt(props['flex'], path: '$path.props.flex') ?? 1,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseExpandedNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'flex'}, path: '$path.props');
    _validateSingleChild(children, nodeType: 'expanded', path: path);
    return _MpNode(
      type: 'expanded',
      props: <String, dynamic>{
        'flex':
            _optionalPositiveInt(props['flex'], path: '$path.props.flex') ?? 1,
      },
      children: children,
    );
  }

  _MpNode _parseFlexibleNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'flex',
      'fit',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'flexible', path: path);
    return _MpNode(
      type: 'flexible',
      props: <String, dynamic>{
        'fit': _optionalFlexFit(props, 'fit', path: '$path.props') ?? 'loose',
        'flex':
            _optionalPositiveInt(props['flex'], path: '$path.props.flex') ?? 1,
      },
      children: children,
    );
  }

  _MpNode _parseContainerNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'width',
      'height',
      'padding',
      'backgroundColor',
      'borderColor',
      'borderWidth',
      'borderRadius',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'container', path: path);
    final parsedProps = <String, dynamic>{
      if (props.containsKey('backgroundColor'))
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
      if (props.containsKey('borderColor'))
        'borderColor': _requiredHexColor(
          props,
          'borderColor',
          path: '$path.props',
        ),
      if (props.containsKey('borderRadius'))
        'borderRadius': _optionalNonNegativeNumberValue(
          props['borderRadius'],
          path: '$path.props.borderRadius',
        ),
      if (props.containsKey('borderWidth'))
        'borderWidth': _optionalNonNegativeNumberValue(
          props['borderWidth'],
          path: '$path.props.borderWidth',
        ),
      if (props.containsKey('height'))
        'height': _optionalNonNegativeNumberValue(
          props['height'],
          path: '$path.props.height',
        ),
      if (props.containsKey('padding'))
        'padding': _parseSpacing(props['padding'], path: '$path.props.padding'),
      if (props.containsKey('width'))
        'width': _optionalNonNegativeNumberValue(
          props['width'],
          path: '$path.props.width',
        ),
    };
    return _MpNode(type: 'container', props: parsedProps, children: children);
  }

  _MpNode _parseScrollViewNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'padding'}, path: '$path.props');
    _validateSingleChild(children, nodeType: 'scrollView', path: path);
    return _MpNode(
      type: 'scrollView',
      props: <String, dynamic>{
        if (props.containsKey('padding'))
          'padding': _parseSpacing(
            props['padding'],
            path: '$path.props.padding',
          ),
      },
      children: children,
    );
  }

  _MpNode _parseSafeAreaNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'left',
      'top',
      'right',
      'bottom',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'safeArea', path: path);
    return _MpNode(
      type: 'safeArea',
      props: <String, dynamic>{
        'bottom':
            _optionalBool(props['bottom'], path: '$path.props.bottom') ?? true,
        'left': _optionalBool(props['left'], path: '$path.props.left') ?? true,
        'right':
            _optionalBool(props['right'], path: '$path.props.right') ?? true,
        'top': _optionalBool(props['top'], path: '$path.props.top') ?? true,
      },
      children: children,
    );
  }

  _MpNode _parseVisibilityNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'visible',
      'maintainSize',
      'maintainState',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'visibility', path: path);
    return _MpNode(
      type: 'visibility',
      props: <String, dynamic>{
        'maintainSize':
            _optionalBool(
              props['maintainSize'],
              path: '$path.props.maintainSize',
            ) ??
            false,
        'maintainState':
            _optionalBool(
              props['maintainState'],
              path: '$path.props.maintainState',
            ) ??
            false,
        'visible':
            _optionalBool(props['visible'], path: '$path.props.visible') ??
            true,
      },
      children: children,
    );
  }

  _MpNode _parseOpacityNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'opacity',
      'alwaysIncludeSemantics',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'opacity', path: path);
    return _MpNode(
      type: 'opacity',
      props: <String, dynamic>{
        'alwaysIncludeSemantics':
            _optionalBool(
              props['alwaysIncludeSemantics'],
              path: '$path.props.alwaysIncludeSemantics',
            ) ??
            false,
        'opacity':
            _optionalUnitIntervalNumberValue(
              props['opacity'],
              path: '$path.props.opacity',
            ) ??
            1,
      },
      children: children,
    );
  }

  _MpNode _parseAspectRatioNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'aspectRatio',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'aspectRatio', path: path);
    if (!props.containsKey('aspectRatio')) {
      _fail(
        'Mp aspectRatio requires an aspectRatio prop.',
        path: '$path.props.aspectRatio',
      );
    }
    return _MpNode(
      type: 'aspectRatio',
      props: <String, dynamic>{
        'aspectRatio': _requiredPositiveNumber(
          props,
          'aspectRatio',
          path: '$path.props',
        ),
      },
      children: children,
    );
  }

  _MpNode _parseStackNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'alignment',
      'clip',
    }, path: '$path.props');
    _validateNonEmptyChildren(children, nodeType: 'stack', path: path);
    return _MpNode(
      type: 'stack',
      props: <String, dynamic>{
        'alignment':
            _optionalAlignment(props, 'alignment', path: '$path.props') ??
            'topLeft',
        'clip': _optionalBool(props['clip'], path: '$path.props.clip') ?? true,
      },
      children: children,
    );
  }

  _MpNode _parsePositionedNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'left',
      'top',
      'right',
      'bottom',
      'width',
      'height',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'positioned', path: path);
    return _MpNode(
      type: 'positioned',
      props: _parsePositionedConstraints(props, path: '$path.props'),
      children: children,
    );
  }
}
