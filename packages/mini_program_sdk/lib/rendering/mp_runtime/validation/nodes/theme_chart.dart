part of '../../../mp_screen_renderer.dart';

extension _MpThemeChartNodeValidation on MpScreenValidator {
  _MpNode _parseThemeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'colors',
      'typography',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'theme', path: path);
    return _MpNode(
      type: 'theme',
      props: <String, dynamic>{
        if (props.containsKey('colors'))
          'colors': _parseThemeColors(
            props['colors'],
            path: '$path.props.colors',
          ),
        if (props.containsKey('typography'))
          'typography': _parseThemeTypography(
            props['typography'],
            path: '$path.props.typography',
          ),
      },
      children: children,
    );
  }

  _MpNode _parseLineChartNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'source',
      'valueField',
      'labelField',
      'height',
      'minY',
      'maxY',
      'unit',
      'color',
      'strokeWidth',
      'curved',
      'showPoints',
      'showGrid',
      'showArea',
      'maxPoints',
      'semanticLabel',
      'empty',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final source = _requiredString(props, 'source', path: '$path.props');
    if (!_MpBindingResolver.isSingleBindingExpression(source)) {
      _fail(
        'Mp lineChart source must be a single full binding expression.',
        path: '$path.props.source',
      );
    }
    final height = _boundedNumber(
      props['height'],
      path: '$path.props.height',
      minimum: 80,
      maximum: 600,
    );
    final strokeWidth = _boundedNumber(
      props['strokeWidth'],
      path: '$path.props.strokeWidth',
      minimum: 1,
      maximum: 12,
    );
    final maxPoints = _boundedIntValue(
      props['maxPoints'],
      path: '$path.props.maxPoints',
      minimum: 2,
      maximum: 500,
    );
    final minY = _optionalFiniteNumber(props['minY'], path: '$path.props.minY');
    final maxY = _optionalFiniteNumber(props['maxY'], path: '$path.props.maxY');
    if (minY != null && maxY != null && minY >= maxY) {
      _fail('Mp lineChart minY must be less than maxY.', path: '$path.props');
    }
    return _MpNode(
      type: 'lineChart',
      props: <String, dynamic>{
        'source': source,
        'valueField': _dataFieldPath(props, 'valueField', path: '$path.props'),
        if (props.containsKey('labelField'))
          'labelField': _dataFieldPath(
            props,
            'labelField',
            path: '$path.props',
          ),
        'height': height,
        if (minY != null) 'minY': minY,
        if (maxY != null) 'maxY': maxY,
        'unit': _optionalStringLiteral(
          props['unit'] ?? '',
          path: '$path.props.unit',
        ),
        'color': _requiredHexColor(props, 'color', path: '$path.props'),
        'strokeWidth': strokeWidth,
        'curved': _requiredBoolValue(
          props['curved'],
          path: '$path.props.curved',
        ),
        'showPoints': _requiredBoolValue(
          props['showPoints'],
          path: '$path.props.showPoints',
        ),
        'showGrid': _requiredBoolValue(
          props['showGrid'],
          path: '$path.props.showGrid',
        ),
        'showArea': _requiredBoolValue(
          props['showArea'],
          path: '$path.props.showArea',
        ),
        'maxPoints': maxPoints,
        if (props.containsKey('semanticLabel'))
          'semanticLabel': _requiredString(
            props,
            'semanticLabel',
            path: '$path.props',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{'empty'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: const <_MpNode>[],
    );
  }
}
