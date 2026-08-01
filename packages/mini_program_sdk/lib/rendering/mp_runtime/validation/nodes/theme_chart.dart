part of '../../../mp_screen_renderer.dart';

extension _MpThemeChartNodeValidation on MpScreenValidator {
  _MpNode _parseQrCodeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'value',
      'size',
      'padding',
      'errorCorrection',
      'foregroundColor',
      'backgroundColor',
      'semanticLabel',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final value = _requiredString(props, 'value', path: '$path.props');
    final size = _boundedNumber(
      props['size'],
      path: '$path.props.size',
      minimum: 96,
      maximum: 600,
    );
    final padding = _boundedNumber(
      props['padding'],
      path: '$path.props.padding',
      minimum: 0,
      maximum: 64,
    );
    if (padding * 2 >= size) {
      _fail(
        'Mp QR padding must leave space for the QR code.',
        path: '$path.props.padding',
      );
    }
    final errorCorrection = _requiredStableString(
      props,
      'errorCorrection',
      path: '$path.props',
    );
    if (!const <String>{
      'low',
      'medium',
      'quartile',
      'high',
    }.contains(errorCorrection)) {
      _fail(
        'Mp QR errorCorrection is unsupported.',
        path: '$path.props.errorCorrection',
      );
    }
    return _MpNode(
      type: 'qrCode',
      props: <String, dynamic>{
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
        'errorCorrection': errorCorrection,
        'foregroundColor': _requiredHexColor(
          props,
          'foregroundColor',
          path: '$path.props',
        ),
        'padding': padding,
        'semanticLabel': _requiredString(
          props,
          'semanticLabel',
          path: '$path.props',
        ),
        'size': size,
        'value': value,
      },
      children: const <_MpNode>[],
    );
  }

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
