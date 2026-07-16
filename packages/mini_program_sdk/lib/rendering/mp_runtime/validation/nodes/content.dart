part of '../../../mp_screen_renderer.dart';

extension _MpContentNodeValidation on MpScreenValidator {
  _MpNode _parseTextNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    const textKeys = <String>{
      'data',
      'size',
      'color',
      'weight',
      'align',
      'maxLines',
      'overflow',
      'softWrap',
      'lineHeight',
      'textDirection',
      'locale',
      'variant',
    };
    _validateObjectKeys(
      props,
      type == 'heading' ? const <String>{...textKeys, 'level'} : textKeys,
      path: '$path.props',
    );
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: type,
      props: _parseTextProps(type: type, props: props, path: '$path.props'),
      children: const <_MpNode>[],
    );
  }

  Map<String, dynamic> _parseTextProps({
    required String type,
    required Map<String, dynamic> props,
    required String path,
  }) {
    final defaultWeight = type == 'heading' ? 'bold' : 'regular';
    final explicitTextProps = <String>[
      for (final key in const <String>{'size', 'color', 'weight', 'lineHeight'})
        if (props.containsKey(key)) key,
    ];
    final parsed = <String, dynamic>{
      'align': _optionalTextAlign(props, 'align', path: path) ?? 'start',
      if (props.containsKey('color'))
        'color': _requiredHexColor(props, 'color', path: path),
      'data': _requiredString(props, 'data', path: path),
      '_explicitTextProps': explicitTextProps,
      if (props.containsKey('lineHeight'))
        'lineHeight': _requiredPositiveNumber(props, 'lineHeight', path: path),
      if (props.containsKey('locale'))
        'locale': _requiredLocale(props, 'locale', path: path),
      if (props.containsKey('maxLines'))
        'maxLines': _requiredPositiveIntValue(
          props['maxLines'],
          path: '$path.maxLines',
        ),
      'overflow':
          _optionalTextOverflow(props, 'overflow', path: path) ?? 'clip',
      if (props.containsKey('size'))
        'size': _requiredPositiveNumber(props, 'size', path: path),
      'softWrap': props.containsKey('softWrap')
          ? _requiredBoolValue(props['softWrap'], path: '$path.softWrap')
          : true,
      'textDirection':
          _optionalTextDirection(props, 'textDirection', path: path) ?? 'auto',
      if (props.containsKey('variant'))
        'variant': _requiredStableString(props, 'variant', path: path),
      'weight':
          _optionalTextWeight(props, 'weight', path: path) ?? defaultWeight,
    };
    if (type == 'heading') {
      parsed['level'] = props.containsKey('level')
          ? _requiredHeadingLevelValue(props['level'], path: '$path.level')
          : 1;
    }
    return parsed;
  }

  _MpNode _parseImageNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'alt',
      'cache',
      'cacheKey',
      'error',
      'fadeInDurationMs',
      'fit',
      'headers',
      'height',
      'placeholder',
      'semanticLabel',
      'source',
      'src',
      'width',
    }, path: '$path.props');
    final src = _requiredImageSrc(props['src'], path: '$path.props.src');
    _validateNoChildren(children, path: '$path.children');
    final source =
        _optionalImageSource(props, 'source', path: '$path.props') ?? 'auto';
    if (!_MpBindingResolver.containsBinding(src)) {
      _validateImageSourceSrc(src, source: source, path: '$path.props.src');
    }
    return _MpNode(
      type: 'image',
      props: <String, dynamic>{
        if (props.containsKey('alt'))
          'alt': _requiredString(props, 'alt', path: '$path.props'),
        'cache': props.containsKey('cache')
            ? _requiredBoolValue(props['cache'], path: '$path.props.cache')
            : true,
        if (props.containsKey('cacheKey'))
          'cacheKey': _requiredStableString(
            props,
            'cacheKey',
            path: '$path.props',
          ),
        'fadeInDurationMs': props.containsKey('fadeInDurationMs')
            ? _requiredNonNegativeIntValue(
                props['fadeInDurationMs'],
                path: '$path.props.fadeInDurationMs',
              )
            : 200,
        'fit': _optionalImageFit(props, 'fit', path: '$path.props') ?? 'cover',
        if (props.containsKey('headers'))
          'headers': _parseImageHeaders(
            props['headers'],
            path: '$path.props.headers',
          ),
        if (props.containsKey('height'))
          'height': _requiredPositiveNumber(
            props,
            'height',
            path: '$path.props',
          ),
        if (props.containsKey('semanticLabel'))
          'semanticLabel': _requiredString(
            props,
            'semanticLabel',
            path: '$path.props',
          ),
        'source': source,
        'src': src,
        if (props.containsKey('width'))
          'width': _requiredPositiveNumber(props, 'width', path: '$path.props'),
        ..._parseTemplateProps(
          props,
          const <String>{'placeholder', 'error'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseSkeletonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    final variant = _requiredSkeletonVariant(props, 'variant', path: path);
    final allowedProps = switch (variant) {
      'box' => const <String>{
        'colorToken',
        'height',
        'radius',
        'variant',
        'width',
      },
      'text' => const <String>{
        'colorToken',
        'height',
        'radius',
        'variant',
        'width',
      },
      'circle' => const <String>{'colorToken', 'size', 'variant'},
      'card' => const <String>{
        'colorToken',
        'height',
        'radius',
        'variant',
        'width',
      },
      _ => const <String>{
        'colorToken',
        'count',
        'itemHeight',
        'radius',
        'spacing',
        'variant',
        'width',
      },
    };
    _validateObjectKeys(props, allowedProps, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final normalizedProps = <String, dynamic>{'variant': variant};
    if (props.containsKey('colorToken')) {
      normalizedProps['colorToken'] = _requiredThemeTokenNameValue(
        props['colorToken'],
        path: '$path.props.colorToken',
      );
    }
    switch (variant) {
      case 'box':
        normalizedProps['radius'] =
            _optionalNonNegativeNumberValue(
              props['radius'],
              path: '$path.props.radius',
            ) ??
            8;
        if (props.containsKey('height')) {
          normalizedProps['height'] = _requiredPositiveNumber(
            props,
            'height',
            path: '$path.props',
          );
        }
        if (props.containsKey('width')) {
          normalizedProps['width'] = _requiredPositiveNumber(
            props,
            'width',
            path: '$path.props',
          );
        }
        break;
      case 'text':
        normalizedProps['height'] =
            _optionalPositiveNumberValue(
              props['height'],
              path: '$path.props.height',
            ) ??
            14;
        normalizedProps['radius'] =
            _optionalNonNegativeNumberValue(
              props['radius'],
              path: '$path.props.radius',
            ) ??
            4;
        if (props.containsKey('width')) {
          normalizedProps['width'] = _requiredPositiveNumber(
            props,
            'width',
            path: '$path.props',
          );
        }
        break;
      case 'circle':
        normalizedProps['size'] = _requiredPositiveNumber(
          props,
          'size',
          path: '$path.props',
        );
        break;
      case 'card':
        normalizedProps['height'] =
            _optionalPositiveNumberValue(
              props['height'],
              path: '$path.props.height',
            ) ??
            160;
        normalizedProps['radius'] =
            _optionalNonNegativeNumberValue(
              props['radius'],
              path: '$path.props.radius',
            ) ??
            12;
        if (props.containsKey('width')) {
          normalizedProps['width'] = _requiredPositiveNumber(
            props,
            'width',
            path: '$path.props',
          );
        }
        break;
      case 'list':
        normalizedProps['count'] =
            _optionalPositiveInt(props['count'], path: '$path.props.count') ??
            3;
        normalizedProps['itemHeight'] =
            _optionalPositiveNumberValue(
              props['itemHeight'],
              path: '$path.props.itemHeight',
            ) ??
            72;
        normalizedProps['radius'] =
            _optionalNonNegativeNumberValue(
              props['radius'],
              path: '$path.props.radius',
            ) ??
            8;
        normalizedProps['spacing'] =
            _optionalNonNegativeNumberValue(
              props['spacing'],
              path: '$path.props.spacing',
            ) ??
            12;
        if (props.containsKey('width')) {
          normalizedProps['width'] = _requiredPositiveNumber(
            props,
            'width',
            path: '$path.props',
          );
        }
        break;
    }
    return _MpNode(
      type: 'skeleton',
      props: normalizedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseCardNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateNoProps(props, path: '$path.props');
    if (children.length != 1) {
      _fail('Mp card requires exactly one child.', path: '$path.children');
    }
    return _MpNode(
      type: 'card',
      props: const <String, dynamic>{},
      children: children,
    );
  }

  _MpNode _parseDividerNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'thickness',
      'spacing',
      'color',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'divider',
      props: <String, dynamic>{
        'color': props.containsKey('color')
            ? _requiredHexColor(props, 'color', path: '$path.props')
            : '#E5E7EB',
        'spacing':
            _optionalNonNegativeNumberValue(
              props['spacing'],
              path: '$path.props.spacing',
            ) ??
            12,
        'thickness':
            _optionalNonNegativeNumberValue(
              props['thickness'],
              path: '$path.props.thickness',
            ) ??
            1,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseIconNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'size',
      'color',
      'semanticLabel',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'icon',
      props: <String, dynamic>{
        if (props.containsKey('color'))
          'color': _requiredHexColor(props, 'color', path: '$path.props'),
        'name': _requiredIconName(props, 'name', path: '$path.props'),
        if (props.containsKey('semanticLabel'))
          'semanticLabel': _requiredString(
            props,
            'semanticLabel',
            path: '$path.props',
          ),
        'size':
            _optionalNonNegativeNumberValue(
              props['size'],
              path: '$path.props.size',
            ) ??
            20,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseListTileNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'title',
      'subtitle',
      'leadingIcon',
      'trailingIcon',
      'badge',
      'action',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'listTile',
      props: <String, dynamic>{
        if (props.containsKey('action'))
          'action': _parseAction(props['action'], path: '$path.props.action'),
        if (props.containsKey('badge'))
          'badge': _requiredString(props, 'badge', path: '$path.props'),
        if (props.containsKey('leadingIcon'))
          'leadingIcon': _requiredIconName(
            props,
            'leadingIcon',
            path: '$path.props',
          ),
        if (props.containsKey('subtitle'))
          'subtitle': _requiredString(props, 'subtitle', path: '$path.props'),
        'title': _requiredString(props, 'title', path: '$path.props'),
        if (props.containsKey('trailingIcon'))
          'trailingIcon': _requiredIconName(
            props,
            'trailingIcon',
            path: '$path.props',
          ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseChipNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'tone',
      'leadingIcon',
      'action',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'chip',
      props: <String, dynamic>{
        if (props.containsKey('action'))
          'action': _parseAction(props['action'], path: '$path.props.action'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('leadingIcon'))
          'leadingIcon': _requiredIconName(
            props,
            'leadingIcon',
            path: '$path.props',
          ),
        'tone': _optionalTone(props, 'tone', path: '$path.props') ?? 'neutral',
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseBadgeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'tone',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'badge',
      props: <String, dynamic>{
        'label': _requiredString(props, 'label', path: '$path.props'),
        'tone': _optionalTone(props, 'tone', path: '$path.props') ?? 'info',
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseAlertNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'title',
      'message',
      'tone',
      'icon',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final tone = _optionalTone(props, 'tone', path: '$path.props') ?? 'info';
    return _MpNode(
      type: 'alert',
      props: <String, dynamic>{
        'icon': props.containsKey('icon')
            ? _requiredIconName(props, 'icon', path: '$path.props')
            : _defaultAlertIcon(tone),
        if (props.containsKey('message'))
          'message': _requiredString(props, 'message', path: '$path.props'),
        'title': _requiredString(props, 'title', path: '$path.props'),
        'tone': tone,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseAvatarNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'imageUrl',
      'initials',
      'icon',
      'size',
      'semanticLabel',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    _validateAvatarSource(props, path: '$path.props');
    final parsedProps = <String, dynamic>{
      if (props.containsKey('icon'))
        'icon': _requiredIconName(props, 'icon', path: '$path.props'),
      if (props.containsKey('imageUrl'))
        'imageUrl': _requiredString(props, 'imageUrl', path: '$path.props'),
      if (props.containsKey('initials'))
        'initials': _requiredString(props, 'initials', path: '$path.props'),
      if (props.containsKey('semanticLabel'))
        'semanticLabel': _requiredString(
          props,
          'semanticLabel',
          path: '$path.props',
        ),
      'size':
          _optionalPositiveNumberValue(
            props['size'],
            path: '$path.props.size',
          ) ??
          40,
    };
    final imageUrl = parsedProps['imageUrl'] as String?;
    if (imageUrl != null && !_MpBindingResolver.containsBinding(imageUrl)) {
      _validateImageUrl(imageUrl, path: '$path.props.imageUrl');
    }
    return _MpNode(
      type: 'avatar',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseProgressNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'value',
      'max',
      'label',
      'tone',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final value = _requiredNonNegativeNumber(
      props,
      'value',
      path: '$path.props',
    );
    final max =
        _optionalPositiveNumberValue(props['max'], path: '$path.props.max') ??
        1;
    if (value > max) {
      _fail(
        'Mp progress value must be less than or equal to max.',
        path: '$path.props.value',
      );
    }
    return _MpNode(
      type: 'progress',
      props: <String, dynamic>{
        if (props.containsKey('label'))
          'label': _requiredString(props, 'label', path: '$path.props'),
        'max': max,
        'tone': _optionalTone(props, 'tone', path: '$path.props') ?? 'info',
        'value': value,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseEmptyStateNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'title',
      'message',
      'icon',
      'actionLabel',
      'action',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final actionProps = _parseActionLabelPair(props, path: '$path.props');
    return _MpNode(
      type: 'emptyState',
      props: <String, dynamic>{
        ...actionProps,
        'icon': props.containsKey('icon')
            ? _requiredIconName(props, 'icon', path: '$path.props')
            : 'info',
        if (props.containsKey('message'))
          'message': _requiredString(props, 'message', path: '$path.props'),
        'title': _requiredString(props, 'title', path: '$path.props'),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseSectionNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'title',
      'subtitle',
      'actionLabel',
      'action',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'section', path: path);
    final actionProps = _parseActionLabelPair(props, path: '$path.props');
    return _MpNode(
      type: 'section',
      props: <String, dynamic>{
        ...actionProps,
        if (props.containsKey('subtitle'))
          'subtitle': _requiredString(props, 'subtitle', path: '$path.props'),
        'title': _requiredString(props, 'title', path: '$path.props'),
      },
      children: children,
    );
  }

  Map<String, dynamic> _parseActionLabelPair(
    Map<String, dynamic> props, {
    required String path,
  }) {
    final hasAction = props.containsKey('action');
    final hasActionLabel = props.containsKey('actionLabel');
    if (!hasAction && !hasActionLabel) {
      return const <String, dynamic>{};
    }
    if (!hasAction || !hasActionLabel) {
      _fail('Mp action and actionLabel must be provided together.', path: path);
    }
    return <String, dynamic>{
      'action': _parseAction(props['action'], path: '$path.action'),
      'actionLabel': _requiredString(props, 'actionLabel', path: path),
    };
  }
}
