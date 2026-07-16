part of '../../../mp_screen_renderer.dart';

extension _MpCollectionNodeValidation on MpScreenValidator {
  _MpNode _parseListViewNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'spacing',
      'padding',
      'direction',
      'height',
    }, path: '$path.props');
    _validateNonEmptyChildren(children, nodeType: 'listView', path: path);
    final direction = _collectionDirection(props, path: '$path.props');
    final height = _collectionHeight(
      props,
      direction: direction,
      path: '$path.props',
    );
    return _MpNode(
      type: 'listView',
      props: <String, dynamic>{
        if (props.containsKey('padding'))
          'padding': _parseSpacing(
            props['padding'],
            path: '$path.props.padding',
          ),
        'spacing':
            _optionalNonNegativeNumberValue(
              props['spacing'],
              path: '$path.props.spacing',
            ) ??
            0,
        'direction': direction,
        if (height != null) 'height': height,
      },
      children: children,
    );
  }

  _MpNode _parseRepeatNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'empty',
      'itemTemplate',
      'limit',
      'separator',
      'source',
      'spacing',
      'direction',
      'height',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final source = _requiredString(props, 'source', path: '$path.props').trim();
    if (!_MpBindingResolver.isSingleBindingExpression(source)) {
      _fail(
        'Mp repeat source must be a single full binding expression.',
        path: '$path.props.source',
      );
    }
    final direction = _collectionDirection(props, path: '$path.props');
    final height = _collectionHeight(
      props,
      direction: direction,
      path: '$path.props',
    );
    final parsedProps = <String, dynamic>{
      'limit': _optionalRepeatLimit(props['limit'], path: '$path.props.limit'),
      'source': source,
      'spacing':
          _optionalNonNegativeNumberValue(
            props['spacing'],
            path: '$path.props.spacing',
          ) ??
          0,
      'direction': direction,
      if (height != null) 'height': height,
      ..._parseTemplateProps(
        props,
        const <String>{'itemTemplate', 'empty', 'separator'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    };
    if (!parsedProps.containsKey('itemTemplate')) {
      _fail('Mp repeat requires an itemTemplate.', path: '$path.props');
    }
    return _MpNode(
      type: 'repeat',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseGridNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'columns',
      'spacing',
    }, path: '$path.props');
    _validateNonEmptyChildren(children, nodeType: 'grid', path: path);
    return _MpNode(
      type: 'grid',
      props: <String, dynamic>{
        'columns':
            _optionalGridColumns(
              props['columns'],
              path: '$path.props.columns',
            ) ??
            2,
        'spacing':
            _optionalNonNegativeNumberValue(
              props['spacing'],
              path: '$path.props.spacing',
            ) ??
            8,
      },
      children: children,
    );
  }

  _MpNode _parseWrapNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'spacing',
      'runSpacing',
    }, path: '$path.props');
    _validateNonEmptyChildren(children, nodeType: 'wrap', path: path);
    return _MpNode(
      type: 'wrap',
      props: <String, dynamic>{
        'runSpacing':
            _optionalNonNegativeNumberValue(
              props['runSpacing'],
              path: '$path.props.runSpacing',
            ) ??
            8,
        'spacing':
            _optionalNonNegativeNumberValue(
              props['spacing'],
              path: '$path.props.spacing',
            ) ??
            8,
      },
      children: children,
    );
  }
}
