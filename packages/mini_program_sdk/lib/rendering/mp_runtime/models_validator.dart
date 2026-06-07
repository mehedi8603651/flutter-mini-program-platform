part of '../mp_screen_renderer.dart';

/// Renderer for versioned Mp JSON screen documents.
class MpScreenRenderer extends MiniProgramScreenRenderer {
  /// Creates the Mp renderer.
  const MpScreenRenderer();

  static const MpScreenValidator _validator = MpScreenValidator();

  @override
  MiniProgramScreenFormat get screenFormat => MiniProgramScreenFormats.mp;

  @override
  Set<int> get supportedSchemaVersions => const <int>{1};

  @override
  Widget render(MiniProgramRenderRequest request) {
    final screen = _validator._parse(
      request.screenJson,
      expectedScreenId: request.screenId,
    );
    return _MpScreenView(screen: screen);
  }
}

/// Validates Mp screen documents against the SDK-supported schema.
class MpScreenValidator {
  /// Creates an Mp validator.
  const MpScreenValidator();

  /// Maximum encoded screen payload accepted by the SDK.
  static const int maxPayloadBytes = 1024 * 1024;

  /// Maximum number of nodes in one screen.
  static const int maxNodes = 2000;

  /// Maximum node nesting depth.
  static const int maxDepth = 64;

  /// Maximum direct children for one node.
  static const int maxDirectChildren = 500;

  /// Maximum text/string literal length.
  static const int maxLiteralTextLength = 32 * 1024;

  /// Maximum accepted URL string length.
  static const int maxUrlLength = 2048;

  static final RegExp _screenIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');
  static final RegExp _fieldNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
  static final RegExp _localePattern = RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$');
  static final RegExp _themeTokenPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');
  static final RegExp _hexColorPattern = RegExp(
    r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  );
  static const Set<String> _toneNames = <String>{
    'neutral',
    'info',
    'success',
    'warning',
    'danger',
  };
  static const Set<String> _iconNames = <String>{
    'person',
    'settings',
    'chevronRight',
    'star',
    'gift',
    'check',
    'warning',
    'info',
    'lock',
    'mail',
    'home',
    'search',
  };
  static const Set<String> _alignmentNames = <String>{
    'topLeft',
    'topCenter',
    'topRight',
    'centerLeft',
    'center',
    'centerRight',
    'bottomLeft',
    'bottomCenter',
    'bottomRight',
  };
  static const Set<String> _flexFitNames = <String>{'loose', 'tight'};
  static const Set<String> _imageSourceNames = <String>{
    'auto',
    'network',
    'asset',
    'base64',
  };
  static const Set<String> _imageFitNames = <String>{
    'cover',
    'contain',
    'fill',
    'fitWidth',
    'fitHeight',
    'none',
  };
  static const Set<String> _skeletonVariantNames = <String>{
    'box',
    'text',
    'circle',
    'card',
    'list',
  };
  static const Set<String> _textWeightNames = <String>{
    'regular',
    'medium',
    'semibold',
    'bold',
  };
  static const Set<String> _textAlignNames = <String>{
    'left',
    'center',
    'right',
    'start',
    'end',
    'justify',
  };
  static const Set<String> _textOverflowNames = <String>{
    'clip',
    'ellipsis',
    'fade',
    'visible',
  };
  static const Set<String> _textDirectionNames = <String>{'auto', 'ltr', 'rtl'};

  /// Validates an Mp screen document without rendering it.
  void validate(Map<String, dynamic> json, {required String expectedScreenId}) {
    _parse(json, expectedScreenId: expectedScreenId);
  }

  /// Parses and validates [json] into an internal Mp screen model.
  _MpScreen _parse(
    Map<String, dynamic> json, {
    required String expectedScreenId,
  }) {
    final int payloadBytes;
    try {
      payloadBytes = utf8.encode(jsonEncode(json)).length;
    } catch (error) {
      _fail(
        'Mp screen payload must be JSON-safe.',
        path: r'$',
        details: <String, dynamic>{'error': error.toString()},
      );
    }
    if (payloadBytes > maxPayloadBytes) {
      _fail(
        'Mp screen payload exceeds the $maxPayloadBytes byte limit.',
        path: r'$',
        details: <String, dynamic>{'payloadBytes': payloadBytes},
      );
    }

    _validateObjectKeys(json, const <String>{
      'schemaVersion',
      'screenId',
      'root',
    }, path: r'$');

    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      _fail(
        'Mp screen schemaVersion must be 1.',
        path: r'$.schemaVersion',
        details: <String, dynamic>{'schemaVersion': schemaVersion},
      );
    }

    final screenId = _requiredString(json, 'screenId', path: r'$');
    if (!_screenIdPattern.hasMatch(screenId)) {
      _fail(
        'Mp screenId must match ^[a-z][a-z0-9_]*\$.',
        path: r'$.screenId',
        details: <String, dynamic>{'screenId': screenId},
      );
    }
    if (screenId != expectedScreenId) {
      _fail(
        'Mp screenId does not match the loaded screen ID.',
        path: r'$.screenId',
        details: <String, dynamic>{
          'screenId': screenId,
          'expectedScreenId': expectedScreenId,
        },
      );
    }

    final rawRoot = json['root'];
    if (rawRoot is! Map) {
      _fail('Mp screen root must be an object.', path: r'$.root');
    }

    final state = _MpValidationState();
    final root = _parseNode(
      Map<String, dynamic>.from(rawRoot),
      path: r'$.root',
      depth: 1,
      state: state,
    );
    return _MpScreen(screenId: screenId, root: root);
  }

  _MpNode _parseNode(
    Map<String, dynamic> json, {
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    if (depth > maxDepth) {
      _fail(
        'Mp screen exceeds the maximum node depth.',
        path: path,
        details: <String, dynamic>{'maxDepth': maxDepth},
      );
    }
    state.nodeCount += 1;
    if (state.nodeCount > maxNodes) {
      _fail(
        'Mp screen exceeds the maximum node count.',
        path: path,
        details: <String, dynamic>{'maxNodes': maxNodes},
      );
    }

    _validateObjectKeys(json, const <String>{
      'type',
      'props',
      'children',
    }, path: path);

    final type = _requiredStableString(json, 'type', path: path);
    final props = _optionalMap(json['props'], path: '$path.props');
    _MpBindingResolver.validateSafeBindings(props, path: '$path.props');
    final children = _optionalChildren(
      json['children'],
      path: '$path.children',
    );

    if (children.length > maxDirectChildren) {
      _fail(
        'Mp node exceeds the maximum direct child count.',
        path: '$path.children',
        details: <String, dynamic>{'maxDirectChildren': maxDirectChildren},
      );
    }

    final parsedChildren = <_MpNode>[
      for (var index = 0; index < children.length; index += 1)
        _parseNode(
          children[index],
          path: '$path.children[$index]',
          depth: depth + 1,
          state: state,
        ),
    ];

    return switch (type) {
      'column' || 'row' => _parseSimpleContainer(
        type: type,
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'text' || 'heading' => _parseTextNode(
        type: type,
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'sizedBox' => _parseSizedBoxNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'image' => _parseImageNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'lazy' => _parseLazyNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'skeleton' => _parseSkeletonNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'card' => _parseCardNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'theme' => _parseThemeNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'padding' => _parsePaddingNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'align' => _parseAlignNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'center' => _parseCenterNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'spacer' => _parseSpacerNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'expanded' => _parseExpandedNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'flexible' => _parseFlexibleNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'container' => _parseContainerNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'scrollView' => _parseScrollViewNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'listView' => _parseListViewNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'repeat' => _parseRepeatNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'safeArea' => _parseSafeAreaNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'visibility' => _parseVisibilityNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'opacity' => _parseOpacityNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'aspectRatio' => _parseAspectRatioNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'stack' => _parseStackNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'positioned' => _parsePositionedNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'divider' => _parseDividerNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'icon' => _parseIconNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'listTile' => _parseListTileNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'chip' => _parseChipNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'badge' => _parseBadgeNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'alert' => _parseAlertNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'avatar' => _parseAvatarNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'grid' => _parseGridNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'wrap' => _parseWrapNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'progress' => _parseProgressNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'emptyState' => _parseEmptyStateNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'section' => _parseSectionNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'primaryButton' || 'secondaryButton' => _parseButtonNode(
        type: type,
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'textInput' => _parseTextInputNode(
        type: type,
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'searchInput' => _parseSearchInputNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'textArea' => _parseTextAreaNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'dropdown' || 'radioGroup' => _parseChoiceNode(
        type: type,
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'checkbox' => _parseCheckboxNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'form' => _parseFormNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'formSubmit' => _parseFormSubmitNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'authBuilder' => _parseAuthBuilderNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'backendBuilder' => _parseBackendBuilderNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'pagedBackendBuilder' => _parsePagedBackendBuilderNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'stateBuilder' => _parseStateBuilderNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      _ => _unsupportedNode(type, path: path),
    };
  }

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

  _MpNode _parseLazyNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'actions',
      'bucket',
      'cacheKey',
      'error',
      'id',
      'once',
      'placeholder',
      'refreshIfCached',
      'retry',
      'retryDelayMs',
      'statusState',
      'targetState',
      'ttlMs',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'lazy', path: path);

    final cacheKey = props.containsKey('cacheKey')
        ? _requiredCacheKey(props, 'cacheKey', path: '$path.props')
        : null;
    final targetState = props.containsKey('targetState')
        ? _requiredStateKey(props, 'targetState', path: '$path.props')
        : null;
    if (cacheKey != null && targetState == null) {
      _fail(
        'Mp lazy requires targetState when cacheKey is provided.',
        path: '$path.props.targetState',
      );
    }

    return _MpNode(
      type: 'lazy',
      props: <String, dynamic>{
        'actions': _parseLazyActions(
          props['actions'],
          path: '$path.props.actions',
        ),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (cacheKey != null) 'cacheKey': cacheKey,
        'id': _requiredStableString(props, 'id', path: '$path.props'),
        'once': props.containsKey('once')
            ? _requiredBoolValue(props['once'], path: '$path.props.once')
            : true,
        'refreshIfCached': props.containsKey('refreshIfCached')
            ? _requiredBoolValue(
                props['refreshIfCached'],
                path: '$path.props.refreshIfCached',
              )
            : false,
        'retry':
            _optionalNonNegativeInt(
              props['retry'],
              path: '$path.props.retry',
            ) ??
            0,
        'retryDelayMs':
            _optionalNonNegativeInt(
              props['retryDelayMs'],
              path: '$path.props.retryDelayMs',
            ) ??
            300,
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (targetState != null) 'targetState': targetState,
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{'placeholder', 'error'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: children,
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

  _MpNode _parseListViewNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'spacing',
      'padding',
    }, path: '$path.props');
    _validateNonEmptyChildren(children, nodeType: 'listView', path: path);
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
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final source = _requiredString(props, 'source', path: '$path.props').trim();
    if (!_MpBindingResolver.isSingleBindingExpression(source)) {
      _fail(
        'Mp repeat source must be a single full binding expression.',
        path: '$path.props.source',
      );
    }
    final parsedProps = <String, dynamic>{
      'limit': _optionalRepeatLimit(props['limit'], path: '$path.props.limit'),
      'source': source,
      'spacing':
          _optionalNonNegativeNumberValue(
            props['spacing'],
            path: '$path.props.spacing',
          ) ??
          0,
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

  _MpNode _parseButtonNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'action',
    }, path: '$path.props');
    _requiredString(props, 'label', path: '$path.props');
    final action = _parseAction(props['action'], path: '$path.props.action');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: type,
      props: <String, dynamic>{'label': props['label'], 'action': action},
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseTextInputNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'initialValue',
      'required',
      'minLength',
      'maxLength',
      'obscureText',
      'keyboardType',
    }, path: '$path.props');
    final parsedProps = _parseTextInputProps(props, path: path);
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(type: type, props: parsedProps, children: const <_MpNode>[]);
  }

  _MpNode _parseSearchInputNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'stateKey',
      'targetState',
      'endpoint',
      'requestId',
      'queryParam',
      'limitParam',
      'method',
      'body',
      'label',
      'hint',
      'initialValue',
      'minLength',
      'limit',
      'debounceMs',
      'statusState',
      'errorState',
      'clearResultsBelowMinLength',
      'cacheTtlSeconds',
    }, path: '$path.props');
    final stateKey = _requiredStateKey(props, 'stateKey', path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp searchInput method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final body = _optionalMap(props['body'], path: '$path.props.body');
    _validateCacheValue(body, path: '$path.props.body');
    final minLength =
        _optionalNonNegativeInt(
          props['minLength'],
          path: '$path.props.minLength',
        ) ??
        2;
    final limit =
        _optionalSearchLimit(props['limit'], path: '$path.props.limit') ?? 20;
    final debounceMs =
        _optionalNonNegativeInt(
          props['debounceMs'],
          path: '$path.props.debounceMs',
        ) ??
        300;
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'searchInput',
      props: <String, dynamic>{
        'stateKey': stateKey,
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
        'requestId':
            _optionalStableString(props, 'requestId', path: '$path.props') ??
            'search_${stateKey.replaceAll('.', '_')}',
        'queryParam':
            _optionalFieldName(props, 'queryParam', path: '$path.props') ?? 'q',
        'limitParam':
            _optionalFieldName(props, 'limitParam', path: '$path.props') ??
            'limit',
        'method': method,
        'body': body,
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('hint'))
          'hint': _requiredString(props, 'hint', path: '$path.props'),
        if (props.containsKey('initialValue'))
          'initialValue': _optionalStringLiteral(
            props['initialValue'],
            path: '$path.props.initialValue',
          ),
        'minLength': minLength,
        'limit': limit,
        'debounceMs': debounceMs,
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        'clearResultsBelowMinLength':
            _optionalBool(
              props['clearResultsBelowMinLength'],
              path: '$path.props.clearResultsBelowMinLength',
            ) ??
            true,
        if (props.containsKey('cacheTtlSeconds'))
          'cacheTtlSeconds': _optionalPositiveInt(
            props['cacheTtlSeconds'],
            path: '$path.props.cacheTtlSeconds',
          ),
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseTextAreaNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'initialValue',
      'required',
      'minLength',
      'maxLength',
      'minLines',
      'maxLines',
    }, path: '$path.props');
    final minLines =
        _optionalPositiveInt(props['minLines'], path: '$path.props.minLines') ??
        3;
    final maxLines =
        _optionalPositiveInt(props['maxLines'], path: '$path.props.maxLines') ??
        6;
    if (maxLines < minLines) {
      _fail(
        'Mp textArea maxLines must be greater than or equal to minLines.',
        path: '$path.props.maxLines',
      );
    }
    final parsedProps = <String, dynamic>{
      ..._parseTextInputProps(props, path: path, includeKeyboardType: false),
      'minLines': minLines,
      'maxLines': maxLines,
    };
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'textArea',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  Map<String, dynamic> _parseTextInputProps(
    Map<String, dynamic> props, {
    required String path,
    bool includeKeyboardType = true,
  }) {
    final minLength = _optionalNonNegativeInt(
      props['minLength'],
      path: '$path.props.minLength',
    );
    final maxLength = _optionalPositiveInt(
      props['maxLength'],
      path: '$path.props.maxLength',
    );
    if (minLength != null && maxLength != null && minLength > maxLength) {
      _fail(
        'Mp minLength must be less than or equal to maxLength.',
        path: '$path.props.minLength',
      );
    }
    String? initialValue;
    if (props.containsKey('initialValue')) {
      final rawInitialValue = props['initialValue'];
      if (rawInitialValue is! String) {
        _fail(
          'Mp "initialValue" must be a string.',
          path: '$path.props.initialValue',
        );
      }
      if (rawInitialValue.length > maxLiteralTextLength) {
        _fail(
          'Mp string literal exceeds the maximum length.',
          path: '$path.props.initialValue',
          details: <String, dynamic>{
            'length': rawInitialValue.length,
            'maxLiteralTextLength': maxLiteralTextLength,
          },
        );
      }
      initialValue = rawInitialValue;
    }
    final parsed = <String, dynamic>{
      'name': _requiredFieldName(props, 'name', path: '$path.props'),
      'label': _requiredString(props, 'label', path: '$path.props'),
      if (props.containsKey('hint'))
        'hint': _requiredString(props, 'hint', path: '$path.props'),
      if (props.containsKey('initialValue')) 'initialValue': initialValue,
      'required':
          _optionalBool(props['required'], path: '$path.props.required') ??
          false,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
    };
    if (includeKeyboardType) {
      final keyboardType =
          _optionalStableString(props, 'keyboardType', path: '$path.props') ??
          'text';
      if (!const <String>{
        'text',
        'email',
        'number',
        'phone',
        'url',
      }.contains(keyboardType)) {
        _fail(
          'Mp textInput keyboardType is unsupported.',
          path: '$path.props.keyboardType',
        );
      }
      parsed['keyboardType'] = keyboardType;
      parsed['obscureText'] =
          _optionalBool(
            props['obscureText'],
            path: '$path.props.obscureText',
          ) ??
          false;
    }
    return parsed;
  }

  _MpNode _parseChoiceNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'hint',
      'options',
      'initialValue',
      'required',
    }, path: '$path.props');
    final options = _parseOptions(
      props['options'],
      path: '$path.props.options',
    );
    final initialValue = props.containsKey('initialValue')
        ? _requiredStableString(props, 'initialValue', path: '$path.props')
        : null;
    if (initialValue != null &&
        !options.any((option) => option['value'] == initialValue)) {
      _fail(
        'Mp $type initialValue must match one option value.',
        path: '$path.props.initialValue',
      );
    }
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: type,
      props: <String, dynamic>{
        'name': _requiredFieldName(props, 'name', path: '$path.props'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        if (props.containsKey('hint'))
          'hint': _requiredString(props, 'hint', path: '$path.props'),
        'options': options,
        if (initialValue != null) 'initialValue': initialValue,
        'required':
            _optionalBool(props['required'], path: '$path.props.required') ??
            false,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseCheckboxNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'label',
      'initialValue',
      'requiredTrue',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'checkbox',
      props: <String, dynamic>{
        'name': _requiredFieldName(props, 'name', path: '$path.props'),
        'label': _requiredString(props, 'label', path: '$path.props'),
        'initialValue':
            _optionalBool(
              props['initialValue'],
              path: '$path.props.initialValue',
            ) ??
            false,
        'requiredTrue':
            _optionalBool(
              props['requiredTrue'],
              path: '$path.props.requiredTrue',
            ) ??
            false,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseFormNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{'id'}, path: '$path.props');
    if (children.isEmpty) {
      _fail('Mp form must contain at least one child.', path: '$path.children');
    }
    return _MpNode(
      type: 'form',
      props: <String, dynamic>{
        'id': props.containsKey('id')
            ? _requiredFieldName(props, 'id', path: '$path.props')
            : 'form',
      },
      children: children,
    );
  }

  _MpNode _parseFormSubmitNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'endpoint',
      'requestId',
      'method',
      'body',
      'cacheTtlSeconds',
      'onSuccess',
      'onError',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
      'label': _requiredString(props, 'label', path: '$path.props'),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'POST',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      if (props.containsKey('onSuccess'))
        'onSuccess': _parseAction(
          props['onSuccess'],
          path: '$path.props.onSuccess',
        ),
      if (props.containsKey('onError'))
        'onError': _parseAction(props['onError'], path: '$path.props.onError'),
    };
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'formSubmit',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseAuthBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'loading',
      'signedOut',
      'signedIn',
      'error',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'authBuilder',
      props: _parseTemplateProps(
        props,
        const <String>{'loading', 'signedOut', 'signedIn', 'error'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseBackendBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'method',
      'body',
      'cacheTtlSeconds',
      'forceRefresh',
      'loading',
      'error',
      'empty',
      'child',
      'itemTemplate',
      'itemsPath',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'GET',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      'forceRefresh':
          _optionalBool(
            props['forceRefresh'],
            path: '$path.props.forceRefresh',
          ) ??
          false,
      if (props.containsKey('itemsPath'))
        'itemsPath': _requiredStableString(
          props,
          'itemsPath',
          path: '$path.props',
        ),
    };
    parsedProps.addAll(
      _parseTemplateProps(
        props,
        const <String>{'loading', 'error', 'empty', 'child', 'itemTemplate'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    );
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'backendBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parsePagedBackendBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'itemTemplate',
      'limit',
      'initialCursor',
      'cursorParam',
      'limitParam',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'cacheTtlSeconds',
      'forceRefresh',
      'loading',
      'loadingMore',
      'error',
      'empty',
      'end',
      'loadMore',
    }, path: '$path.props');
    if (!props.containsKey('itemTemplate')) {
      _fail(
        'Mp pagedBackendBuilder requires an itemTemplate.',
        path: '$path.props.itemTemplate',
      );
    }
    final parsedProps = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      'limit':
          _optionalPositiveInt(props['limit'], path: '$path.props.limit') ?? 20,
      if (props.containsKey('initialCursor'))
        'initialCursor': _requiredStableString(
          props,
          'initialCursor',
          path: '$path.props',
        ),
      'cursorParam':
          _optionalStableString(props, 'cursorParam', path: '$path.props') ??
          'cursor',
      'limitParam':
          _optionalStableString(props, 'limitParam', path: '$path.props') ??
          'limit',
      'itemsPath':
          _optionalStableString(props, 'itemsPath', path: '$path.props') ??
          'items',
      'nextCursorPath':
          _optionalStableString(props, 'nextCursorPath', path: '$path.props') ??
          'nextCursor',
      'hasMorePath':
          _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
          'hasMore',
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      'forceRefresh':
          _optionalBool(
            props['forceRefresh'],
            path: '$path.props.forceRefresh',
          ) ??
          false,
    };
    parsedProps.addAll(
      _parseTemplateProps(
        props,
        const <String>{
          'itemTemplate',
          'loading',
          'loadingMore',
          'error',
          'empty',
          'end',
          'loadMore',
        },
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    );
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'pagedBackendBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseStateBuilderNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'keys',
      'child',
    }, path: '$path.props');
    final parsedProps = <String, dynamic>{
      'keys': _parseStateKeys(props['keys'], path: '$path.props.keys'),
      ..._parseTemplateProps(
        props,
        const <String>{'child'},
        path: '$path.props',
        depth: depth,
        state: state,
      ),
    };
    if (!parsedProps.containsKey('child')) {
      _fail('Mp stateBuilder requires a child template.', path: '$path.props');
    }
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'stateBuilder',
      props: parsedProps,
      children: const <_MpNode>[],
    );
  }

  _MpAction _parseAction(Object? value, {required String path}) {
    if (value is! Map) {
      _fail('Mp action must be an object.', path: path);
    }
    final json = Map<String, dynamic>.from(value);
    _validateObjectKeys(json, const <String>{'type', 'props'}, path: path);
    final type = _requiredStableString(json, 'type', path: path);
    final props = _optionalMap(json['props'], path: '$path.props');
    _MpBindingResolver.validateSafeBindings(props, path: '$path.props');
    return switch (type) {
      'auth.showEmailAuth' => _parseShowEmailAuthAction(type, props, path),
      'auth.signOut' ||
      'auth.restore' ||
      'auth.refresh' => _parseNoPropsAction(type, props, path),
      'backend.call' => _parseBackendCallAction(type, props, path),
      'backend.query' => _parseBackendQueryAction(type, props, path),
      'backend.loadMore' => _parseBackendLoadMoreAction(type, props, path),
      'search.loadMore' => _parseSearchLoadMoreAction(type, props, path),
      'form.submit' => _parseFormSubmitAction(type, props, path),
      'ui.toast' => _parseToastAction(type, props, path),
      'ui.dialog' => _parseDialogAction(type, props, path),
      'state.set' || 'state.put' => _parseStateSetAction(type, props, path),
      'state.increment' => _parseStateIncrementAction(type, props, path),
      'state.remove' => _parseStateRemoveAction(type, props, path),
      'state.clear' => _parseNoPropsAction(type, props, path),
      'cache.set' => _parseCacheSetAction(type, props, path),
      'cache.get' => _parseCacheGetAction(type, props, path),
      'cache.has' => _parseCacheHasAction(type, props, path),
      'cache.remove' => _parseCacheRemoveAction(type, props, path),
      'cache.clear' => _parseCacheClearAction(type, props, path),
      'sequence' => _parseSequenceAction(type, props, path),
      'router.push' ||
      'router.replace' ||
      'router.reset' => _parseRouterScreenAction(type, props, path),
      'router.pop' ||
      'router.popToRoot' => _parseRouterResultAction(type, props, path),
      'router.popToScreen' => _parseRouterPopToScreenAction(type, props, path),
      'navigation.openScreen' ||
      'navigation.replaceScreen' ||
      'navigation.resetStack' ||
      'navigation.popToScreen' => _parseScreenNavigationAction(
        type,
        props,
        path,
      ),
      'navigation.popScreen' ||
      'navigation.popToRoot' => _parseEmptyNavigationAction(type, props, path),
      _ => _unsupportedAction(type, path: path),
    };
  }

  List<_MpAction> _parseLazyActions(Object? value, {required String path}) {
    if (value == null) {
      return const <_MpAction>[];
    }
    if (value is! List) {
      _fail('Mp lazy actions must be an array.', path: path);
    }
    return <_MpAction>[
      for (var index = 0; index < value.length; index += 1)
        _parseAction(value[index], path: '$path[$index]'),
    ];
  }

  _MpAction _parseShowEmailAuthAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'mode'}, path: '$path.props');
    final mode = _optionalStableString(props, 'mode', path: '$path.props');
    if (mode != null && mode != 'signIn' && mode != 'signUp') {
      _fail(
        'Mp auth.showEmailAuth mode must be signIn or signUp.',
        path: '$path.props.mode',
      );
    }
    return _MpAction(type: type, props: props);
  }

  _MpAction _parseNoPropsAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateNoProps(props, path: '$path.props');
    return _MpAction(type: type, props: const <String, dynamic>{});
  }

  _MpAction _parseBackendCallAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'endpoint',
      'requestId',
      'method',
      'body',
      'cacheTtlSeconds',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'GET',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseBackendQueryAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'method',
      'body',
      'cacheTtlSeconds',
      'forceRefresh',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'GET',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      'forceRefresh':
          _optionalBool(
            props['forceRefresh'],
            path: '$path.props.forceRefresh',
          ) ??
          false,
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseBackendLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'endpoint',
      'limit',
      'initialCursor',
      'cursorParam',
      'limitParam',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'cacheTtlSeconds',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'requestId': _requiredStableString(
        props,
        'requestId',
        path: '$path.props',
      ),
      if (props.containsKey('endpoint'))
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
      'limit':
          _optionalPositiveInt(props['limit'], path: '$path.props.limit') ?? 20,
      if (props.containsKey('initialCursor'))
        'initialCursor': _requiredStableString(
          props,
          'initialCursor',
          path: '$path.props',
        ),
      'cursorParam':
          _optionalStableString(props, 'cursorParam', path: '$path.props') ??
          'cursor',
      'limitParam':
          _optionalStableString(props, 'limitParam', path: '$path.props') ??
          'limit',
      'itemsPath':
          _optionalStableString(props, 'itemsPath', path: '$path.props') ??
          'items',
      'nextCursorPath':
          _optionalStableString(props, 'nextCursorPath', path: '$path.props') ??
          'nextCursor',
      'hasMorePath':
          _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
          'hasMore',
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseSearchLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'queryState',
      'targetState',
      'endpoint',
      'requestId',
      'queryParam',
      'cursorParam',
      'limitParam',
      'method',
      'body',
      'limit',
      'itemsPath',
      'nextCursorPath',
      'hasMorePath',
      'statusState',
      'errorState',
      'cacheTtlSeconds',
      'skipWhenNoQuery',
    }, path: '$path.props');
    final method =
        _optionalStableString(props, 'method', path: '$path.props') ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      _fail(
        'Mp search.loadMore method must be GET or POST.',
        path: '$path.props.method',
      );
    }
    final body = _optionalMap(props['body'], path: '$path.props.body');
    _validateCacheValue(body, path: '$path.props.body');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'queryState': _requiredStateKey(
          props,
          'queryState',
          path: '$path.props',
        ),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        'endpoint': _requiredStableString(
          props,
          'endpoint',
          path: '$path.props',
        ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'queryParam':
            _optionalFieldName(props, 'queryParam', path: '$path.props') ?? 'q',
        'cursorParam':
            _optionalFieldName(props, 'cursorParam', path: '$path.props') ??
            'cursor',
        'limitParam':
            _optionalFieldName(props, 'limitParam', path: '$path.props') ??
            'limit',
        'method': method,
        'body': body,
        'limit':
            _optionalSearchLimit(props['limit'], path: '$path.props.limit') ??
            20,
        'itemsPath':
            _optionalStableString(props, 'itemsPath', path: '$path.props') ??
            'items',
        'nextCursorPath':
            _optionalStableString(
              props,
              'nextCursorPath',
              path: '$path.props',
            ) ??
            'nextCursor',
        'hasMorePath':
            _optionalStableString(props, 'hasMorePath', path: '$path.props') ??
            'hasMore',
        if (props.containsKey('statusState'))
          'statusState': _requiredStateKey(
            props,
            'statusState',
            path: '$path.props',
          ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        if (props.containsKey('cacheTtlSeconds'))
          'cacheTtlSeconds': _optionalPositiveInt(
            props['cacheTtlSeconds'],
            path: '$path.props.cacheTtlSeconds',
          ),
        'skipWhenNoQuery':
            _optionalBool(
              props['skipWhenNoQuery'],
              path: '$path.props.skipWhenNoQuery',
            ) ??
            true,
      },
    );
  }

  _MpAction _parseFormSubmitAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'endpoint',
      'requestId',
      'method',
      'body',
      'cacheTtlSeconds',
      'onSuccess',
      'onError',
    }, path: '$path.props');
    final parsed = <String, dynamic>{
      'endpoint': _requiredStableString(props, 'endpoint', path: '$path.props'),
      if (props.containsKey('requestId'))
        'requestId': _requiredStableString(
          props,
          'requestId',
          path: '$path.props',
        ),
      'method':
          _optionalStableString(props, 'method', path: '$path.props') ?? 'POST',
      'body': _optionalMap(props['body'], path: '$path.props.body'),
      'cacheTtlSeconds': _optionalPositiveInt(
        props['cacheTtlSeconds'],
        path: '$path.props.cacheTtlSeconds',
      ),
      if (props.containsKey('onSuccess'))
        'onSuccess': _parseAction(
          props['onSuccess'],
          path: '$path.props.onSuccess',
        ),
      if (props.containsKey('onError'))
        'onError': _parseAction(props['onError'], path: '$path.props.onError'),
    };
    return _MpAction(type: type, props: parsed);
  }

  _MpAction _parseToastAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'message',
      'durationMs',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'message': _requiredString(props, 'message', path: '$path.props'),
        'durationMs':
            _optionalPositiveInt(
              props['durationMs'],
              path: '$path.props.durationMs',
            ) ??
            2400,
      },
    );
  }

  _MpAction _parseDialogAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'title',
      'message',
      'confirmLabel',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('title'))
          'title': _requiredString(props, 'title', path: '$path.props'),
        'message': _requiredString(props, 'message', path: '$path.props'),
        'confirmLabel': props.containsKey('confirmLabel')
            ? _requiredString(props, 'confirmLabel', path: '$path.props')
            : 'OK',
      },
    );
  }

  _MpAction _parseStateSetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp $type requires a value.', path: '$path.props.value');
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
      },
    );
  }

  _MpAction _parseStateIncrementAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'by',
    }, path: '$path.props');
    final by = props['by'];
    if (by != null && by is! num) {
      _fail('Mp state.increment by must be numeric.', path: '$path.props.by');
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'by': by ?? 1,
      },
    );
  }

  _MpAction _parseStateRemoveAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'key'}, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
      },
    );
  }

  _MpAction _parseCacheSetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'value',
      'ttlMs',
      'priority',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp cache.set requires a value.', path: '$path.props.value');
    }
    _validateCacheValue(props['value'], path: '$path.props.value');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        'value': props['value'],
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        'priority':
            _optionalCachePriority(props, path: '$path.props') ?? 'normal',
      },
    );
  }

  _MpAction _parseCacheGetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'targetState',
      'skipMissing',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('targetState'))
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
        'skipMissing':
            _optionalBool(
              props['skipMissing'],
              path: '$path.props.skipMissing',
            ) ??
            false,
      },
    );
  }

  _MpAction _parseCacheHasAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
      'targetState',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('targetState'))
          'targetState': _requiredStateKey(
            props,
            'targetState',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseCacheRemoveAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'key',
      'bucket',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        'key': _requiredCacheKey(props, 'key', path: '$path.props'),
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
      },
    );
  }

  _MpAction _parseCacheClearAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
      'bucket',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
        if (props.containsKey('bucket'))
          'bucket': _optionalCacheBucket(props, path: '$path.props'),
      },
    );
  }

  _MpAction _parseSequenceAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'steps'}, path: '$path.props');
    final steps = props['steps'];
    if (steps is! List || steps.isEmpty) {
      _fail(
        'Mp sequence requires a non-empty steps array.',
        path: '$path.props.steps',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'steps': <_MpAction>[
          for (var index = 0; index < steps.length; index += 1)
            _parseAction(steps[index], path: '$path.props.steps[$index]'),
        ],
      },
    );
  }

  _MpAction _parseRouterScreenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'params',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        'params': _optionalMap(props['params'], path: '$path.props.params'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseRouterResultAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'result',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'result': _optionalMap(props['result'], path: '$path.props.result'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseRouterPopToScreenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'result',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        'result': _optionalMap(props['result'], path: '$path.props.result'),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseScreenNavigationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'screenId',
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'screenId': _requiredStableString(
          props,
          'screenId',
          path: '$path.props',
        ),
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  _MpAction _parseEmptyNavigationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (props.containsKey('requestId'))
          'requestId': _requiredStableString(
            props,
            'requestId',
            path: '$path.props',
          ),
      },
    );
  }

  Map<String, dynamic> _parseTemplateProps(
    Map<String, dynamic> props,
    Set<String> names, {
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    final parsed = <String, dynamic>{};
    for (final name in names) {
      if (!props.containsKey(name)) {
        continue;
      }
      final value = props[name];
      if (value is! Map) {
        _fail(
          'Mp "$name" template must be a node object.',
          path: '$path.$name',
        );
      }
      parsed[name] = _parseNode(
        Map<String, dynamic>.from(value),
        path: '$path.$name',
        depth: depth + 1,
        state: state,
      );
    }
    return parsed;
  }

  static void _validateObjectKeys(
    Map<String, dynamic> json,
    Set<String> allowedKeys, {
    required String path,
  }) {
    final unknownKeys = json.keys.where((key) => !allowedKeys.contains(key));
    if (unknownKeys.isNotEmpty) {
      _fail(
        'Mp JSON contains unsupported field(s): ${unknownKeys.join(', ')}.',
        path: path,
        details: <String, dynamic>{'unsupportedFields': unknownKeys.toList()},
      );
    }
  }

  static void _validateNoProps(
    Map<String, dynamic> props, {
    required String path,
  }) {
    if (props.isNotEmpty) {
      _fail('This Mp node or action does not support props.', path: path);
    }
  }

  static void _validateNoChildren(
    List<_MpNode> children, {
    required String path,
  }) {
    if (children.isNotEmpty) {
      _fail('This Mp node does not support children.', path: path);
    }
  }

  static void _validateSingleChild(
    List<_MpNode> children, {
    required String nodeType,
    required String path,
  }) {
    if (children.length != 1) {
      _fail('Mp $nodeType requires exactly one child.', path: '$path.children');
    }
  }

  static void _validateNonEmptyChildren(
    List<_MpNode> children, {
    required String nodeType,
    required String path,
  }) {
    if (children.isEmpty) {
      _fail(
        'Mp $nodeType requires at least one child.',
        path: '$path.children',
      );
    }
  }

  static void _validateAvatarSource(
    Map<String, dynamic> props, {
    required String path,
  }) {
    final sourceCount = <String>[
      'imageUrl',
      'initials',
      'icon',
    ].where(props.containsKey).length;
    if (sourceCount != 1) {
      _fail(
        'Mp avatar requires exactly one of imageUrl, initials, or icon.',
        path: path,
      );
    }
  }

  static Map<String, dynamic> _parseSpacing(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return const <String, dynamic>{};
    }
    if (value is! Map) {
      _fail('Mp spacing must be an object.', path: path);
    }
    final spacing = Map<String, dynamic>.from(value);
    _validateObjectKeys(spacing, const <String>{
      'left',
      'top',
      'right',
      'bottom',
    }, path: path);
    return <String, dynamic>{
      if (spacing.containsKey('bottom'))
        'bottom': _optionalNonNegativeNumberValue(
          spacing['bottom'],
          path: '$path.bottom',
        ),
      if (spacing.containsKey('left'))
        'left': _optionalNonNegativeNumberValue(
          spacing['left'],
          path: '$path.left',
        ),
      if (spacing.containsKey('right'))
        'right': _optionalNonNegativeNumberValue(
          spacing['right'],
          path: '$path.right',
        ),
      if (spacing.containsKey('top'))
        'top': _optionalNonNegativeNumberValue(
          spacing['top'],
          path: '$path.top',
        ),
    };
  }

  static Map<String, dynamic> _parseThemeColors(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp theme colors must be an object.', path: path);
    }
    final colors = Map<String, dynamic>.from(value);
    return <String, dynamic>{
      for (final entry in colors.entries)
        _themeTokenName(entry.key, path: '$path.${entry.key}'): _themeHexColor(
          entry.value,
          path: '$path.${entry.key}',
        ),
    };
  }

  static Map<String, dynamic> _parseImageHeaders(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp image headers must be an object.', path: path);
    }
    final parsed = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        _fail('Mp image header names must be strings.', path: path);
      }
      parsed[_imageHeaderName(key, path: '$path.$key')] = _imageHeaderValue(
        entry.value,
        path: '$path.$key',
      );
    }
    return parsed;
  }

  static Map<String, dynamic> _parseThemeTypography(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp theme typography must be an object.', path: path);
    }
    final typography = Map<String, dynamic>.from(value);
    return <String, dynamic>{
      for (final entry in typography.entries)
        _themeTokenName(entry.key, path: '$path.${entry.key}'):
            _parseThemeTypographyStyle(entry.value, path: '$path.${entry.key}'),
    };
  }

  static Map<String, dynamic> _parseThemeTypographyStyle(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp theme typography style must be an object.', path: path);
    }
    final style = Map<String, dynamic>.from(value);
    _validateObjectKeys(style, const <String>{
      'size',
      'weight',
      'lineHeight',
      'color',
    }, path: path);
    return <String, dynamic>{
      if (style.containsKey('color'))
        'color': _themeTypographyColor(style['color'], path: '$path.color'),
      if (style.containsKey('lineHeight'))
        'lineHeight': _themePositiveNumber(
          style['lineHeight'],
          path: '$path.lineHeight',
        ),
      if (style.containsKey('size'))
        'size': _themePositiveNumber(style['size'], path: '$path.size'),
      if (style.containsKey('weight'))
        'weight': _themeTextWeight(style['weight'], path: '$path.weight'),
    };
  }

  static String _requiredSkeletonVariant(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path);
    if (!_skeletonVariantNames.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${_skeletonVariantNames.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{'variant': value},
      );
    }
    return value;
  }

  static Map<String, dynamic> _parsePositionedConstraints(
    Map<String, dynamic> props, {
    required String path,
  }) {
    const constraintKeys = <String>{
      'left',
      'top',
      'right',
      'bottom',
      'width',
      'height',
    };
    if (!props.keys.any(constraintKeys.contains)) {
      _fail('Mp positioned requires at least one constraint.', path: path);
    }
    if (props.containsKey('left') &&
        props.containsKey('right') &&
        props.containsKey('width')) {
      _fail('Mp positioned cannot combine left, right, and width.', path: path);
    }
    if (props.containsKey('top') &&
        props.containsKey('bottom') &&
        props.containsKey('height')) {
      _fail(
        'Mp positioned cannot combine top, bottom, and height.',
        path: path,
      );
    }
    return <String, dynamic>{
      if (props.containsKey('bottom'))
        'bottom': _requiredNonNegativeNumber(props, 'bottom', path: path),
      if (props.containsKey('height'))
        'height': _requiredNonNegativeNumber(props, 'height', path: path),
      if (props.containsKey('left'))
        'left': _requiredNonNegativeNumber(props, 'left', path: path),
      if (props.containsKey('right'))
        'right': _requiredNonNegativeNumber(props, 'right', path: path),
      if (props.containsKey('top'))
        'top': _requiredNonNegativeNumber(props, 'top', path: path),
      if (props.containsKey('width'))
        'width': _requiredNonNegativeNumber(props, 'width', path: path),
    };
  }

  static String _defaultAlertIcon(String tone) {
    return switch (tone) {
      'success' => 'check',
      'warning' || 'danger' => 'warning',
      _ => 'info',
    };
  }

  static String _requiredHexColor(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path);
    if (!_hexColorPattern.hasMatch(value)) {
      _fail(
        'Mp "$key" must be a hex color in #RRGGBB or #AARRGGBB format.',
        path: '$path.$key',
      );
    }
    return value;
  }

  static String _requiredIconName(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path);
    if (!_iconNames.contains(value)) {
      _fail(
        'Mp "$key" is not an allowed icon name.',
        path: '$path.$key',
        details: <String, dynamic>{'iconName': value},
      );
    }
    return value;
  }

  static String? _optionalTone(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_toneNames.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${_toneNames.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{'tone': value},
      );
    }
    return value;
  }

  static String? _optionalAlignment(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_alignmentNames.contains(value)) {
      _fail(
        'Mp "$key" is not an allowed alignment.',
        path: '$path.$key',
        details: <String, dynamic>{'alignment': value},
      );
    }
    return value;
  }

  static String? _optionalFlexFit(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_flexFitNames.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${_flexFitNames.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{'fit': value},
      );
    }
    return value;
  }

  static String? _optionalImageSource(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_imageSourceNames.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${_imageSourceNames.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{'source': value},
      );
    }
    return value;
  }

  static String? _optionalImageFit(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_imageFitNames.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${_imageFitNames.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{'fit': value},
      );
    }
    return value;
  }

  static String? _optionalTextWeight(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    return _optionalTextChoice(
      json,
      key,
      path: path,
      allowedValues: _textWeightNames,
      label: 'text weight',
    );
  }

  static String? _optionalTextAlign(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    return _optionalTextChoice(
      json,
      key,
      path: path,
      allowedValues: _textAlignNames,
      label: 'text align',
    );
  }

  static String? _optionalTextOverflow(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    return _optionalTextChoice(
      json,
      key,
      path: path,
      allowedValues: _textOverflowNames,
      label: 'text overflow',
    );
  }

  static String? _optionalTextDirection(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    return _optionalTextChoice(
      json,
      key,
      path: path,
      allowedValues: _textDirectionNames,
      label: 'text direction',
    );
  }

  static String? _optionalTextChoice(
    Map<String, dynamic> json,
    String key, {
    required String path,
    required Set<String> allowedValues,
    required String label,
  }) {
    if (!json.containsKey(key)) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!allowedValues.contains(value)) {
      _fail(
        'Mp "$key" must be one of: ${allowedValues.join(', ')}.',
        path: '$path.$key',
        details: <String, dynamic>{label: value},
      );
    }
    return value;
  }

  static String _requiredLocale(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path);
    if (!_localePattern.hasMatch(value)) {
      _fail(
        'Mp "$key" must be a simple locale tag.',
        path: '$path.$key',
        details: <String, dynamic>{'locale': value},
      );
    }
    return value;
  }

  static String _requiredImageSrc(Object? value, {required String path}) {
    if (value is! String || value.trim().isEmpty) {
      _fail('Mp image src must be a non-empty string.', path: path);
    }
    return value.trim();
  }

  static String _imageHeaderName(String value, {required String path}) {
    if (value.trim().isEmpty || _MpBindingResolver.containsBinding(value)) {
      _fail(
        'Mp image header name must be a non-empty static string.',
        path: path,
      );
    }
    return value.trim();
  }

  static String _imageHeaderValue(Object? value, {required String path}) {
    if (value is! String || value.trim().isEmpty) {
      _fail('Mp image header value must be a non-empty string.', path: path);
    }
    return value;
  }

  static String _themeTokenName(String value, {required String path}) {
    if (value.trim().isEmpty || !_themeTokenPattern.hasMatch(value)) {
      _fail(
        'Mp theme token name must match ^[a-zA-Z][a-zA-Z0-9_]*\$.',
        path: path,
        details: <String, dynamic>{'token': value},
      );
    }
    return value;
  }

  static String _requiredThemeTokenNameValue(
    Object? value, {
    required String path,
  }) {
    if (value is! String) {
      _fail('Mp theme token name must be a string.', path: path);
    }
    return _themeTokenName(value, path: path);
  }

  static String _themeHexColor(Object? value, {required String path}) {
    if (value is! String || !_hexColorPattern.hasMatch(value)) {
      _fail(
        'Mp theme color must be a hex color in #RRGGBB or #AARRGGBB format.',
        path: path,
      );
    }
    return value;
  }

  static String _themeTypographyColor(Object? value, {required String path}) {
    if (value is! String || value.trim().isEmpty) {
      _fail('Mp theme typography color must be a string.', path: path);
    }
    if (_hexColorPattern.hasMatch(value)) {
      return value;
    }
    return _themeTokenName(value, path: path);
  }

  static num _themePositiveNumber(Object? value, {required String path}) {
    if (value is! num || value <= 0 || !value.isFinite) {
      _fail('Mp theme numeric value must be finite and positive.', path: path);
    }
    return value;
  }

  static String _themeTextWeight(Object? value, {required String path}) {
    if (value is! String || !_textWeightNames.contains(value)) {
      _fail(
        'Mp theme text weight must be one of: ${_textWeightNames.join(', ')}.',
        path: path,
      );
    }
    return value;
  }

  static int _requiredHeadingLevelValue(Object? value, {required String path}) {
    if (value is! int || value < 1 || value > 6) {
      _fail('Mp heading level must be an integer from 1 to 6.', path: path);
    }
    return value;
  }

  static String _requiredStableString(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredString(json, key, path: path);
    if (_MpBindingResolver.containsBinding(value)) {
      _fail('Mp "$key" cannot contain bindings.', path: '$path.$key');
    }
    return value;
  }

  static String _requiredFieldName(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path);
    if (!_fieldNamePattern.hasMatch(value)) {
      _fail(
        'Mp "$key" must match ^[a-z][a-z0-9_]*\$.',
        path: '$path.$key',
        details: <String, dynamic>{key: value},
      );
    }
    return value;
  }

  static String? _optionalFieldName(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    final value = _requiredStableString(json, key, path: path);
    if (!_fieldNamePattern.hasMatch(value)) {
      _fail(
        'Mp "$key" must match ^[a-z][a-z0-9_]*\$.',
        path: '$path.$key',
        details: <String, dynamic>{key: value},
      );
    }
    return value;
  }

  static String? _optionalStableString(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      return null;
    }
    return _requiredStableString(json, key, path: path);
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      _fail('Mp "$key" must be a non-empty string.', path: '$path.$key');
    }
    if (value.length > maxLiteralTextLength) {
      _fail(
        'Mp string literal exceeds the maximum length.',
        path: '$path.$key',
        details: <String, dynamic>{
          'length': value.length,
          'maxLiteralTextLength': maxLiteralTextLength,
        },
      );
    }
    return value;
  }

  static String _optionalStringLiteral(Object? value, {required String path}) {
    if (value is! String) {
      _fail('Mp field must be a string.', path: path);
    }
    if (value.length > maxLiteralTextLength) {
      _fail(
        'Mp string literal exceeds the maximum length.',
        path: path,
        details: <String, dynamic>{
          'length': value.length,
          'maxLiteralTextLength': maxLiteralTextLength,
        },
      );
    }
    return value;
  }

  static Map<String, dynamic> _optionalMap(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is! Map) {
      _fail('Mp field must be an object.', path: path);
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _optionalChildren(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    if (value is! List) {
      _fail('Mp children must be an array.', path: path);
    }
    return <Map<String, dynamic>>[
      for (final child in value)
        if (child is Map)
          Map<String, dynamic>.from(child)
        else
          throw MiniProgramRenderException(
            message: 'Invalid Mp screen JSON: child nodes must be objects.',
            details: <String, dynamic>{'path': path},
          ),
    ];
  }

  static int? _optionalPositiveInt(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! int || value <= 0) {
      _fail('Mp numeric value must be a positive integer.', path: path);
    }
    return value;
  }

  static int _optionalRepeatLimit(Object? value, {required String path}) {
    if (value == null) {
      return 100;
    }
    if (value is! int || value <= 0 || value > 500) {
      _fail('Mp repeat limit must be an integer from 1 to 500.', path: path);
    }
    return value;
  }

  static int? _optionalSearchLimit(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! int || value <= 0 || value > 100) {
      _fail('Mp search limit must be an integer from 1 to 100.', path: path);
    }
    return value;
  }

  static int _requiredPositiveIntValue(Object? value, {required String path}) {
    if (value is! int || value <= 0) {
      _fail('Mp numeric value must be a positive integer.', path: path);
    }
    return value;
  }

  static int _requiredNonNegativeIntValue(
    Object? value, {
    required String path,
  }) {
    if (value is! int || value < 0) {
      _fail('Mp numeric value must be a non-negative integer.', path: path);
    }
    return value;
  }

  static int? _optionalNonNegativeInt(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! int || value < 0) {
      _fail('Mp numeric value must be a non-negative integer.', path: path);
    }
    return value;
  }

  static bool? _optionalBool(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! bool) {
      _fail('Mp value must be a boolean.', path: path);
    }
    return value;
  }

  static bool _requiredBoolValue(Object? value, {required String path}) {
    if (value is! bool) {
      _fail('Mp value must be a boolean.', path: path);
    }
    return value;
  }

  static int? _optionalGridColumns(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! int || value < 1 || value > 6) {
      _fail('Mp grid columns must be an integer from 1 to 6.', path: path);
    }
    return value;
  }

  static num _requiredNonNegativeNumber(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = json[key];
    if (value is! num || value < 0 || !value.isFinite) {
      _fail(
        'Mp "$key" must be a finite non-negative number.',
        path: '$path.$key',
      );
    }
    return value;
  }

  static num _requiredPositiveNumber(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = json[key];
    if (value is! num || value <= 0 || !value.isFinite) {
      _fail('Mp "$key" must be a finite positive number.', path: '$path.$key');
    }
    return value;
  }

  static void _optionalNonNegativeNumber(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return;
    }
    if (value is! num || value < 0 || !value.isFinite) {
      _fail('Mp numeric value must be finite and non-negative.', path: path);
    }
  }

  static num? _optionalNonNegativeNumberValue(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return null;
    }
    if (value is! num || value < 0 || !value.isFinite) {
      _fail('Mp numeric value must be finite and non-negative.', path: path);
    }
    return value;
  }

  static num? _optionalPositiveNumberValue(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return null;
    }
    if (value is! num || value <= 0 || !value.isFinite) {
      _fail('Mp numeric value must be finite and positive.', path: path);
    }
    return value;
  }

  static num? _optionalUnitIntervalNumberValue(
    Object? value, {
    required String path,
  }) {
    if (value == null) {
      return null;
    }
    if (value is! num || value < 0 || value > 1 || !value.isFinite) {
      _fail('Mp numeric value must be finite and between 0 and 1.', path: path);
    }
    return value;
  }

  static void _validateImageUrl(String src, {required String path}) {
    if (src.length > maxUrlLength) {
      _fail(
        'Mp image URL exceeds the maximum length.',
        path: path,
        details: <String, dynamic>{
          'length': src.length,
          'maxUrlLength': maxUrlLength,
        },
      );
    }
    final uri = Uri.tryParse(src);
    if (uri == null || !uri.hasAuthority) {
      _fail('Mp image src must be an absolute URL.', path: path);
    }
    if (uri.scheme == 'https') {
      return;
    }
    if (uri.scheme == 'http' && _isLocalPreviewHost(uri.host)) {
      return;
    }
    _fail(
      'Mp image src must use https, except local preview loopback URLs.',
      path: path,
      details: <String, dynamic>{'scheme': uri.scheme, 'host': uri.host},
    );
  }

  static void _validateImageSourceSrc(
    String src, {
    required String source,
    required String path,
  }) {
    switch (source) {
      case 'network':
        _validateAsyncImageNetworkUrl(src, path: path);
      case 'base64':
        _validateBase64Image(src, path: path);
      case 'asset' || 'auto':
        return;
    }
  }

  static void _validateAsyncImageNetworkUrl(
    String src, {
    required String path,
  }) {
    if (src.length > maxUrlLength) {
      _fail(
        'Mp image URL exceeds the maximum length.',
        path: path,
        details: <String, dynamic>{
          'length': src.length,
          'maxUrlLength': maxUrlLength,
        },
      );
    }
    final uri = Uri.tryParse(src);
    if (uri == null || !uri.hasAuthority) {
      _fail('Mp network image src must be an absolute URL.', path: path);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      _fail(
        'Mp network image src must use http or https.',
        path: path,
        details: <String, dynamic>{'scheme': uri.scheme},
      );
    }
  }

  static void _validateBase64Image(String src, {required String path}) {
    final payload = _base64ImagePayload(src);
    if (payload.replaceAll(RegExp(r'\s+'), '').isEmpty) {
      _fail('Mp base64 image src must be valid base64 data.', path: path);
    }
    try {
      base64Decode(_paddedBase64(payload));
    } on FormatException {
      _fail('Mp base64 image src must be valid base64 data.', path: path);
    }
  }

  static String _base64ImagePayload(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^data:image\/[-+.\w]+;base64,',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match == null ? trimmed : trimmed.substring(match.end);
  }

  static String _paddedBase64(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    final remainder = compact.length % 4;
    return remainder == 0
        ? compact
        : compact.padRight(compact.length + 4 - remainder, '=');
  }

  static bool _isLocalPreviewHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized.startsWith('127.') ||
        normalized == '::1' ||
        normalized == '0.0.0.0' ||
        normalized == '10.0.2.2';
  }

  static List<Map<String, dynamic>> _parseOptions(
    Object? value, {
    required String path,
  }) {
    if (value is! List || value.isEmpty) {
      _fail('Mp options must be a non-empty array.', path: path);
    }
    final seenValues = <String>{};
    return <Map<String, dynamic>>[
      for (var index = 0; index < value.length; index += 1)
        _parseOption(
          value[index],
          path: '$path[$index]',
          seenValues: seenValues,
        ),
    ];
  }

  static Map<String, dynamic> _parseOption(
    Object? value, {
    required String path,
    required Set<String> seenValues,
  }) {
    if (value is! Map) {
      _fail('Mp option must be an object.', path: path);
    }
    final json = Map<String, dynamic>.from(value);
    _validateObjectKeys(json, const <String>{'label', 'value'}, path: path);
    final optionValue = _requiredStableString(json, 'value', path: path);
    if (!seenValues.add(optionValue)) {
      _fail(
        'Mp option values must be unique.',
        path: '$path.value',
        details: <String, dynamic>{'value': optionValue},
      );
    }
    return <String, dynamic>{
      'label': _requiredString(json, 'label', path: path),
      'value': optionValue,
    };
  }

  static List<String> _parseStateKeys(Object? value, {required String path}) {
    if (value is! List || value.isEmpty) {
      _fail('Mp state keys must be a non-empty array.', path: path);
    }
    final keys = <String>[];
    for (var index = 0; index < value.length; index += 1) {
      final rawKey = value[index];
      if (rawKey is! String) {
        _fail('Mp state key must be a string.', path: '$path[$index]');
      }
      keys.add(_validateStateKey(rawKey, path: '$path[$index]'));
    }
    return List<String>.unmodifiable(keys);
  }

  static String _requiredStateKey(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    return _validateStateKey(
      _requiredStableString(json, key, path: path),
      path: '$path.$key',
    );
  }

  static String _validateStateKey(String value, {required String path}) {
    try {
      return validateStateKey(value);
    } on ArgumentError {
      _fail(
        'Mp state key must be a safe lowercase dot path.',
        path: path,
        details: <String, dynamic>{'stateKey': value},
      );
    }
  }

  static String _requiredCacheKey(
    Map<String, dynamic> json,
    String key, {
    required String path,
  }) {
    final value = _requiredStableString(json, key, path: path).trim();
    if (_unsafeCacheKeyPattern.hasMatch(value)) {
      _fail(
        'Mp cache key cannot contain path traversal, separators, or file path markers.',
        path: '$path.$key',
        details: <String, dynamic>{key: value},
      );
    }
    return value;
  }

  static String? _optionalCacheBucket(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final bucket = _optionalStableString(json, 'bucket', path: path);
    if (bucket == null) {
      return null;
    }
    if (!_allowedMiniProgramCacheBuckets.contains(bucket)) {
      _fail(
        'Mp cache bucket is not allowed for mini-program actions.',
        path: '$path.bucket',
        details: <String, dynamic>{'bucket': bucket},
      );
    }
    return bucket;
  }

  static String? _optionalCachePriority(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final priority = _optionalStableString(json, 'priority', path: path);
    if (priority == null) {
      return null;
    }
    if (!_allowedMiniProgramCachePriorities.contains(priority)) {
      _fail(
        'Mp cache priority is not allowed for mini-program actions.',
        path: '$path.priority',
        details: <String, dynamic>{'priority': priority},
      );
    }
    return priority;
  }

  static void _validateCacheValue(Object? value, {required String path}) {
    if (value == null || value is String || value is bool) {
      return;
    }
    if (value is num) {
      if (!value.isFinite) {
        _fail('Mp cache value numbers must be finite.', path: path);
      }
      return;
    }
    if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        _validateCacheValue(value[index], path: '$path[$index]');
      }
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String || entry.key.toString().trim().isEmpty) {
          _fail(
            'Mp cache value map keys must be non-empty strings.',
            path: path,
          );
        }
        _validateCacheValue(entry.value, path: '$path.${entry.key}');
      }
      return;
    }
    _fail('Mp cache value must be JSON-safe.', path: path);
  }

  static Never _unsupportedNode(String type, {required String path}) {
    _fail(
      'Unsupported Mp node type "$type".',
      path: '$path.type',
      details: <String, dynamic>{'nodeType': type},
    );
  }

  static Never _unsupportedAction(String type, {required String path}) {
    _fail(
      'Unsupported Mp action type "$type".',
      path: '$path.type',
      details: <String, dynamic>{'actionType': type},
    );
  }

  static Never _fail(
    String message, {
    required String path,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) {
    throw MiniProgramRenderException(
      message: 'Invalid Mp screen JSON: $message',
      details: <String, dynamic>{'path': path, ...details},
    );
  }
}

final RegExp _unsafeCacheKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/:]');

const Set<String> _allowedMiniProgramCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
};

const Set<String> _allowedMiniProgramCachePriorities = <String>{
  'low',
  'normal',
  'high',
};

class _MpScreen {
  const _MpScreen({required this.screenId, required this.root});

  final String screenId;
  final _MpNode root;
}

class _MpNode {
  const _MpNode({
    required this.type,
    required this.props,
    required this.children,
  });

  final String type;
  final Map<String, dynamic> props;
  final List<_MpNode> children;
}

class _MpAction {
  const _MpAction({required this.type, required this.props});

  final String type;
  final Map<String, dynamic> props;
}

class _MpValidationState {
  int nodeCount = 0;
}
