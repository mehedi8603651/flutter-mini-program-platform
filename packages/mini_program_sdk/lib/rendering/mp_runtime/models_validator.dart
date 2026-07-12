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
    'history',
    'backspace',
    'arrowBack',
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
      'lazyChunk' => _parseLazyChunkNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'initialize' => _parseInitializeNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'stateScope' => _parseStateScopeNode(
        props: props,
        children: parsedChildren,
        path: path,
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
      'button' => _parseStyledButtonNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'iconButton' => _parseIconButtonNode(
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

  _MpNode _parseLazyChunkNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'bucket',
      'cacheKeyPrefix',
      'cursorState',
      'empty',
      'end',
      'error',
      'hasMoreState',
      'id',
      'initialActions',
      'itemTemplate',
      'itemsState',
      'loadingMore',
      'loadMoreActions',
      'loadMore',
      'once',
      'placeholder',
      'refreshIfCached',
      'retry',
      'retryDelayMs',
      'statusState',
      'ttlMs',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    if (!props.containsKey('itemTemplate')) {
      _fail(
        'Mp lazyChunk requires an itemTemplate.',
        path: '$path.props.itemTemplate',
      );
    }

    return _MpNode(
      type: 'lazyChunk',
      props: <String, dynamic>{
        'bucket': _optionalCacheBucket(props, path: '$path.props') ?? 'data',
        if (props.containsKey('cacheKeyPrefix'))
          'cacheKeyPrefix': _requiredCacheKey(
            props,
            'cacheKeyPrefix',
            path: '$path.props',
          ),
        if (props.containsKey('cursorState'))
          'cursorState': _requiredStateKey(
            props,
            'cursorState',
            path: '$path.props',
          ),
        if (props.containsKey('hasMoreState'))
          'hasMoreState': _requiredStateKey(
            props,
            'hasMoreState',
            path: '$path.props',
          ),
        'id': _requiredStableString(props, 'id', path: '$path.props'),
        'initialActions': _parseRequiredLazyActions(
          props['initialActions'],
          name: 'initialActions',
          path: '$path.props.initialActions',
        ),
        'itemsState': _requiredStateKey(
          props,
          'itemsState',
          path: '$path.props',
        ),
        'loadMoreActions': _parseRequiredLazyActions(
          props['loadMoreActions'],
          name: 'loadMoreActions',
          path: '$path.props.loadMoreActions',
        ),
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
        if (props.containsKey('ttlMs'))
          'ttlMs': _optionalPositiveInt(
            props['ttlMs'],
            path: '$path.props.ttlMs',
          ),
        ..._parseTemplateProps(
          props,
          const <String>{
            'empty',
            'end',
            'error',
            'itemTemplate',
            'loadingMore',
            'loadMore',
            'placeholder',
          },
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

  _MpNode _parseStyledButtonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'label',
      'action',
      'height',
      'backgroundColor',
      'foregroundColor',
      'borderColor',
      'borderWidth',
      'borderRadius',
      'fontSize',
      'fontWeight',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(
      type: 'button',
      props: <String, dynamic>{
        'label': _requiredString(props, 'label', path: '$path.props'),
        'action': _parseAction(props['action'], path: '$path.props.action'),
        'height': _requiredPositiveNumber(props, 'height', path: '$path.props'),
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
        'foregroundColor': _requiredHexColor(
          props,
          'foregroundColor',
          path: '$path.props',
        ),
        'borderColor': _requiredHexColor(
          props,
          'borderColor',
          path: '$path.props',
        ),
        'borderWidth': _requiredNonNegativeNumber(
          props,
          'borderWidth',
          path: '$path.props',
        ),
        'borderRadius': _requiredNonNegativeNumber(
          props,
          'borderRadius',
          path: '$path.props',
        ),
        'fontSize': _requiredPositiveNumber(
          props,
          'fontSize',
          path: '$path.props',
        ),
        'fontWeight': _optionalTextWeight(
          props,
          'fontWeight',
          path: '$path.props',
        )!,
      },
      children: const <_MpNode>[],
    );
  }

  _MpNode _parseIconButtonNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'name',
      'semanticLabel',
      'action',
      'size',
      'iconSize',
      'color',
      'backgroundColor',
      'borderColor',
      'borderWidth',
      'borderRadius',
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final size = _requiredPositiveNumber(props, 'size', path: '$path.props');
    final iconSize = _requiredPositiveNumber(
      props,
      'iconSize',
      path: '$path.props',
    );
    if (iconSize > size) {
      _fail(
        'Mp iconButton iconSize cannot exceed size.',
        path: '$path.props.iconSize',
      );
    }
    return _MpNode(
      type: 'iconButton',
      props: <String, dynamic>{
        'name': _requiredIconName(props, 'name', path: '$path.props'),
        'semanticLabel': _requiredString(
          props,
          'semanticLabel',
          path: '$path.props',
        ),
        'action': _parseAction(props['action'], path: '$path.props.action'),
        'size': size,
        'iconSize': iconSize,
        'color': _requiredHexColor(props, 'color', path: '$path.props'),
        'backgroundColor': _requiredHexColor(
          props,
          'backgroundColor',
          path: '$path.props',
        ),
        'borderColor': _requiredHexColor(
          props,
          'borderColor',
          path: '$path.props',
        ),
        'borderWidth': _requiredNonNegativeNumber(
          props,
          'borderWidth',
          path: '$path.props',
        ),
        'borderRadius': _requiredNonNegativeNumber(
          props,
          'borderRadius',
          path: '$path.props',
        ),
      },
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
      'lazy.chunk.loadMore' => _parseLazyChunkLoadMoreAction(type, props, path),
      'search.clear' => _parseSearchClearAction(type, props, path),
      'search.refresh' => _parseSearchRefreshAction(type, props, path),
      'search.loadMore' => _parseSearchLoadMoreAction(type, props, path),
      'form.submit' => _parseFormSubmitAction(type, props, path),
      'ui.toast' => _parseToastAction(type, props, path),
      'ui.dialog' => _parseDialogAction(type, props, path),
      'state.set' || 'state.put' => _parseStateSetAction(type, props, path),
      'state.setDefault' => _parseStateSetAction(type, props, path),
      'state.patch' => _parseStatePatchAction(type, props, path),
      'state.increment' ||
      'state.decrement' => _parseStateNumberMutationAction(type, props, path),
      'state.copy' => _parseStateCopyAction(type, props, path),
      'state.toggle' => _parseStateToggleAction(type, props, path),
      'state.appendText' => _parseStateAppendTextAction(type, props, path),
      'state.backspace' => _parseStateBackspaceAction(type, props, path),
      'state.listAppend' ||
      'state.listPrepend' => _parseStateListAddAction(type, props, path),
      'state.listInsert' => _parseStateListInsertAction(type, props, path),
      'state.listRemoveAt' => _parseStateListRemoveAtAction(type, props, path),
      'state.listRemoveValue' => _parseStateListRemoveValueAction(
        type,
        props,
        path,
      ),
      'state.remove' => _parseStateRemoveAction(type, props, path),
      'state.clear' => _parseNoPropsAction(type, props, path),
      'math.evaluate' => _parseMathEvaluateAction(type, props, path),
      'math.compare' => _parseMathCompareAction(type, props, path),
      'math.randomInt' => _parseMathRandomIntAction(type, props, path),
      'math.randomDouble' => _parseMathRandomDoubleAction(type, props, path),
      'math.aggregate' => _parseMathAggregateAction(type, props, path),
      'cache.set' => _parseCacheSetAction(type, props, path),
      'cache.get' => _parseCacheGetAction(type, props, path),
      'cache.has' => _parseCacheHasAction(type, props, path),
      'cache.remove' => _parseCacheRemoveAction(type, props, path),
      'cache.clear' => _parseCacheClearAction(type, props, path),
      'cache.info' => _parseCacheInfoAction(type, props, path),
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

  List<_MpAction> _parseRequiredLazyActions(
    Object? value, {
    required String name,
    required String path,
  }) {
    final actions = _parseLazyActions(value, path: path);
    if (actions.isEmpty) {
      _fail('Mp lazyChunk requires non-empty $name.', path: path);
    }
    return actions;
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

  _MpAction _parseLazyChunkLoadMoreAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'id'}, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'id': _requiredStableString(props, 'id', path: '$path.props'),
      },
    );
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

  _MpAction _parseSearchClearAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'queryState',
      'targetState',
      'statusState',
      'errorState',
    }, path: '$path.props');
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
      },
    );
  }

  _MpAction _parseSearchRefreshAction(
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
        'Mp search.refresh method must be GET or POST.',
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

  _MpNode _parseInitializeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    _validateObjectKeys(props, const <String>{
      'actions',
      'loading',
      'error',
      'statusState',
      'errorState',
      'retry',
      'retryDelayMs',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'initialize', path: path);
    final actions = _parseLazyActions(
      props['actions'],
      path: '$path.props.actions',
    );
    if (actions.isEmpty) {
      _fail(
        'Mp initialize requires at least one action.',
        path: '$path.props.actions',
      );
    }
    final retry =
        _optionalNonNegativeInt(props['retry'], path: '$path.props.retry') ?? 0;
    final retryDelayMs =
        _optionalNonNegativeInt(
          props['retryDelayMs'],
          path: '$path.props.retryDelayMs',
        ) ??
        300;
    if (retry > 10) {
      _fail('Mp initialize retry cannot exceed 10.', path: '$path.props.retry');
    }
    if (retryDelayMs > 60000) {
      _fail(
        'Mp initialize retryDelayMs cannot exceed 60000.',
        path: '$path.props.retryDelayMs',
      );
    }
    return _MpNode(
      type: 'initialize',
      props: <String, dynamic>{
        'actions': actions,
        'retry': retry,
        'retryDelayMs': retryDelayMs,
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
        ..._parseTemplateProps(
          props,
          const <String>{'loading', 'error'},
          path: '$path.props',
          depth: depth,
          state: state,
        ),
      },
      children: children,
    );
  }

  _MpNode _parseStateScopeNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'prefix',
      'clearOnDispose',
    }, path: '$path.props');
    _validateSingleChild(children, nodeType: 'stateScope', path: path);
    return _MpNode(
      type: 'stateScope',
      props: <String, dynamic>{
        'prefix': _requiredStateKey(props, 'prefix', path: '$path.props'),
        'clearOnDispose': props.containsKey('clearOnDispose')
            ? _requiredBoolValue(
                props['clearOnDispose'],
                path: '$path.props.clearOnDispose',
              )
            : true,
      },
      children: children,
    );
  }

  _MpAction _parseStatePatchAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'values',
      'remove',
    }, path: '$path.props');
    final rawValues = props['values'];
    if (rawValues != null && rawValues is! Map) {
      _fail(
        'Mp state.patch values must be an object.',
        path: '$path.props.values',
      );
    }
    final values = rawValues == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawValues as Map);
    final normalizedValues = <String, dynamic>{};
    for (final entry in values.entries) {
      final key = _validateStateKey(
        entry.key,
        path: '$path.props.values.${entry.key}',
      );
      normalizedValues[key] = entry.value;
    }

    final rawRemove = props['remove'];
    if (rawRemove != null && rawRemove is! List) {
      _fail(
        'Mp state.patch remove must be an array.',
        path: '$path.props.remove',
      );
    }
    final remove = <String>[];
    if (rawRemove is List) {
      for (var index = 0; index < rawRemove.length; index += 1) {
        final rawKey = rawRemove[index];
        if (rawKey is! String) {
          _fail(
            'Mp state.patch remove paths must be strings.',
            path: '$path.props.remove[$index]',
          );
        }
        remove.add(
          _validateStateKey(rawKey, path: '$path.props.remove[$index]'),
        );
      }
    }
    if (normalizedValues.isEmpty && remove.isEmpty) {
      _fail(
        'Mp state.patch requires values or remove paths.',
        path: '$path.props',
      );
    }
    final paths = <String>[...normalizedValues.keys, ...remove];
    for (var left = 0; left < paths.length; left += 1) {
      for (var right = left + 1; right < paths.length; right += 1) {
        if (_statePatchPathsOverlap(paths[left], paths[right])) {
          _fail(
            'Mp state.patch paths cannot duplicate or overlap.',
            path: '$path.props',
            details: <String, dynamic>{
              'left': paths[left],
              'right': paths[right],
            },
          );
        }
      }
    }
    remove.sort();
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (normalizedValues.isNotEmpty) 'values': normalizedValues,
        if (remove.isNotEmpty) 'remove': remove,
      },
    );
  }

  _MpAction _parseStateNumberMutationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'by',
      'defaultValue',
      'min',
      'max',
    }, path: '$path.props');
    final by = props['by'] ?? 1;
    _validateFiniteNumberOrBinding(by, path: '$path.props.by');
    final defaultValue = _optionalFiniteNumber(
      props['defaultValue'],
      fallback: 0,
      path: '$path.props.defaultValue',
    );
    final min = _optionalFiniteNumber(props['min'], path: '$path.props.min');
    final max = _optionalFiniteNumber(props['max'], path: '$path.props.max');
    if (min != null && max != null && min > max) {
      _fail(
        'Mp $type min cannot be greater than max.',
        path: '$path.props.min',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'by': by,
        'defaultValue': defaultValue,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      },
    );
  }

  _MpAction _parseStateCopyAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'from',
      'to',
      'convertTo',
    }, path: '$path.props');
    final convertTo = props['convertTo'] ?? 'value';
    if (convertTo is! String ||
        !const <String>{'value', 'text', 'number'}.contains(convertTo)) {
      _fail(
        'Mp state.copy convertTo must be value, text, or number.',
        path: '$path.props.convertTo',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'from': _requiredStateKey(props, 'from', path: '$path.props'),
        'to': _requiredStateKey(props, 'to', path: '$path.props'),
        'convertTo': convertTo,
      },
    );
  }

  _MpAction _parseStateToggleAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'defaultValue',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'defaultValue':
            _optionalBool(
              props['defaultValue'],
              path: '$path.props.defaultValue',
            ) ??
            false,
      },
    );
  }

  void _validateFiniteNumberOrBinding(Object? value, {required String path}) {
    if (value is num && value.isFinite ||
        value is String &&
            _MpBindingResolver.isSingleBindingExpression(value)) {
      return;
    }
    _fail(
      'Mp state numeric operand must be a finite number or full binding.',
      path: path,
    );
  }

  num? _optionalFiniteNumber(
    Object? value, {
    num? fallback,
    required String path,
  }) {
    if (value == null) {
      return fallback;
    }
    if (value is num && value.isFinite) {
      return value;
    }
    _fail('Mp state numeric option must be finite.', path: path);
  }

  _MpAction _parseStateAppendTextAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'text',
      'maxLength',
    }, path: '$path.props');
    final text = _requiredString(props, 'text', path: '$path.props');
    final maxLength =
        _optionalPositiveInt(
          props['maxLength'],
          path: '$path.props.maxLength',
        ) ??
        4096;
    if (maxLength > _maxStateTextLength) {
      _fail(
        'Mp state.appendText maxLength cannot exceed $_maxStateTextLength.',
        path: '$path.props.maxLength',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'text': text,
        'maxLength': maxLength,
      },
    );
  }

  _MpAction _parseStateBackspaceAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'count',
    }, path: '$path.props');
    final count =
        _optionalPositiveInt(props['count'], path: '$path.props.count') ?? 1;
    if (count > _maxStateTextLength) {
      _fail(
        'Mp state.backspace count cannot exceed $_maxStateTextLength.',
        path: '$path.props.count',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'count': count,
      },
    );
  }

  _MpAction _parseStateListAddAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
      'maxItems',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp $type requires a value.', path: '$path.props.value');
    }
    final maxItems = _optionalPositiveInt(
      props['maxItems'],
      path: '$path.props.maxItems',
    );
    if (maxItems != null && maxItems > _maxStateListItems) {
      _fail(
        'Mp state list maxItems cannot exceed $_maxStateListItems.',
        path: '$path.props.maxItems',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
        if (maxItems != null) 'maxItems': maxItems,
      },
    );
  }

  _MpAction _parseStateListInsertAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'index',
      'value',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp state.listInsert requires a value.', path: '$path.props.value');
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'index': _requiredIntegerOrBinding(
          props['index'],
          path: '$path.props.index',
        ),
        'value': props['value'],
      },
    );
  }

  _MpAction _parseStateListRemoveAtAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'index',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'index': _requiredIntegerOrBinding(
          props['index'],
          path: '$path.props.index',
        ),
      },
    );
  }

  _MpAction _parseStateListRemoveValueAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
      'all',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail(
        'Mp state.listRemoveValue requires a value.',
        path: '$path.props.value',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
        'all': _optionalBool(props['all'], path: '$path.props.all') ?? false,
      },
    );
  }

  _MpAction _parseMathEvaluateAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'expression',
      'variables',
      'targetState',
      'errorState',
      'precision',
      'angleMode',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'expression': _requiredMathOperand(
          props['expression'],
          path: '$path.props.expression',
        ),
        ..._parsedMathCommon(props, path: '$path.props'),
        'precision': _mathPrecision(props, path: '$path.props'),
        'angleMode': _mathOption(
          props,
          'angleMode',
          const <String>{'radians', 'degrees'},
          fallback: 'radians',
          path: '$path.props',
        ),
      },
    );
  }

  _MpAction _parseMathCompareAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'left',
      'right',
      'comparison',
      'tolerance',
      'variables',
      'targetState',
      'errorState',
    }, path: '$path.props');
    final tolerance = props['tolerance'] ?? 1e-9;
    if (tolerance is! num || !tolerance.isFinite || tolerance < 0) {
      _fail(
        'Mp math.compare tolerance must be finite and non-negative.',
        path: '$path.props.tolerance',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'left': _requiredMathOperand(props['left'], path: '$path.props.left'),
        'right': _requiredMathOperand(
          props['right'],
          path: '$path.props.right',
        ),
        'comparison': _mathOption(
          props,
          'comparison',
          const <String>{
            'equal',
            'notEqual',
            'lessThan',
            'lessThanOrEqual',
            'greaterThan',
            'greaterThanOrEqual',
          },
          fallback: 'equal',
          path: '$path.props',
        ),
        'tolerance': tolerance,
        ..._parsedMathCommon(props, path: '$path.props'),
      },
    );
  }

  _MpAction _parseMathRandomIntAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) => _parseMathRandomAction(type, props, path, allowDecimalPlaces: false);

  _MpAction _parseMathRandomDoubleAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) => _parseMathRandomAction(type, props, path, allowDecimalPlaces: true);

  _MpAction _parseMathRandomAction(
    String type,
    Map<String, dynamic> props,
    String path, {
    required bool allowDecimalPlaces,
  }) {
    _validateObjectKeys(props, <String>{
      'min',
      'max',
      'targetState',
      'errorState',
      'seed',
      if (allowDecimalPlaces) 'decimalPlaces',
    }, path: '$path.props');
    final seed = props['seed'];
    if (seed != null && seed is! int) {
      _fail('Mp $type seed must be an integer.', path: '$path.props.seed');
    }
    final decimalPlaces = allowDecimalPlaces
        ? _optionalNonNegativeInt(
            props['decimalPlaces'],
            path: '$path.props.decimalPlaces',
          )
        : null;
    if (decimalPlaces != null && decimalPlaces > 15) {
      _fail(
        'Mp math.randomDouble decimalPlaces cannot exceed 15.',
        path: '$path.props.decimalPlaces',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'min': _requiredMathOperand(props['min'], path: '$path.props.min'),
        'max': _requiredMathOperand(props['max'], path: '$path.props.max'),
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        if (seed != null) 'seed': seed,
        if (decimalPlaces != null) 'decimalPlaces': decimalPlaces,
      },
    );
  }

  _MpAction _parseMathAggregateAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'values',
      'operation',
      'targetState',
      'errorState',
      'precision',
    }, path: '$path.props');
    final operation = _mathOption(props, 'operation', const <String>{
      'sum',
      'average',
      'min',
      'max',
      'count',
      'median',
    }, path: '$path.props');
    final values = props['values'];
    if (values is List) {
      if (values.length > _maxMathAggregateItems) {
        _fail(
          'Mp math.aggregate cannot exceed $_maxMathAggregateItems values.',
          path: '$path.props.values',
        );
      }
      if (operation != 'count') {
        for (var index = 0; index < values.length; index += 1) {
          final value = values[index];
          if (value is num && value.isFinite) {
            continue;
          }
          if (value is String &&
              _MpBindingResolver.isSingleBindingExpression(value)) {
            continue;
          }
          _fail(
            'Mp math.aggregate numeric values must be finite numbers or bindings.',
            path: '$path.props.values[$index]',
          );
        }
      }
    } else if (values is! String ||
        !_MpBindingResolver.isSingleBindingExpression(values)) {
      _fail(
        'Mp math.aggregate values must be a list or single list binding.',
        path: '$path.props.values',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'values': values,
        'operation': operation,
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
        if (props.containsKey('errorState'))
          'errorState': _requiredStateKey(
            props,
            'errorState',
            path: '$path.props',
          ),
        'precision': _mathPrecision(props, path: '$path.props'),
      },
    );
  }

  Map<String, dynamic> _parsedMathCommon(
    Map<String, dynamic> props, {
    required String path,
  }) => <String, dynamic>{
    if (props.containsKey('variables'))
      'variables': _requiredMathVariables(
        props['variables'],
        path: '$path.variables',
      ),
    'targetState': _requiredStateKey(props, 'targetState', path: path),
    if (props.containsKey('errorState'))
      'errorState': _requiredStateKey(props, 'errorState', path: path),
  };

  Object _requiredMathOperand(Object? value, {required String path}) {
    if (value is num && value.isFinite) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      if (value.length > _maxMathExpressionLength) {
        _fail(
          'Mp math expression exceeds $_maxMathExpressionLength characters.',
          path: path,
        );
      }
      return value;
    }
    _fail(
      'Mp math operand must be a finite number or non-empty expression.',
      path: path,
    );
  }

  Map<String, dynamic> _requiredMathVariables(
    Object? value, {
    required String path,
  }) {
    if (value is! Map) {
      _fail('Mp math variables must be an object.', path: path);
    }
    final variables = Map<String, dynamic>.from(value);
    if (variables.length > _maxMathVariables) {
      _fail(
        'Mp math actions support at most $_maxMathVariables variables.',
        path: path,
      );
    }
    for (final entry in variables.entries) {
      if (!_mathVariableNamePattern.hasMatch(entry.key) ||
          _reservedMathNames.contains(entry.key)) {
        _fail(
          'Invalid or reserved math variable name.',
          path: '$path.${entry.key}',
        );
      }
      final variable = entry.value;
      if (variable is num && variable.isFinite) {
        continue;
      }
      if (variable is String &&
          _MpBindingResolver.isSingleBindingExpression(variable)) {
        continue;
      }
      _fail(
        'Mp math variables must be finite numbers or single bindings.',
        path: '$path.${entry.key}',
      );
    }
    return variables;
  }

  int _mathPrecision(Map<String, dynamic> props, {required String path}) {
    final precision =
        _optionalPositiveInt(props['precision'], path: '$path.precision') ?? 12;
    if (precision > 15) {
      _fail('Mp math precision cannot exceed 15.', path: '$path.precision');
    }
    return precision;
  }

  String _mathOption(
    Map<String, dynamic> props,
    String key,
    Set<String> allowed, {
    String? fallback,
    required String path,
  }) {
    final value = props[key] ?? fallback;
    if (value is! String || !allowed.contains(value)) {
      _fail(
        'Mp math $key must be one of: ${allowed.join(', ')}.',
        path: '$path.$key',
      );
    }
    return value;
  }

  Object _requiredIntegerOrBinding(Object? value, {required String path}) {
    if (value is int ||
        value is String &&
            _MpBindingResolver.isSingleBindingExpression(value)) {
      return value!;
    }
    _fail('Mp state list index must be an integer or binding.', path: path);
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

  _MpAction _parseCacheInfoAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'requestId',
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
        'targetState': _requiredStateKey(
          props,
          'targetState',
          path: '$path.props',
        ),
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
}
