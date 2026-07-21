part of '../../mp_screen_renderer.dart';

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

  /// Maximum countdown duration accepted by the runtime.
  static const int maxCountdownDurationMs = 7 * 24 * 60 * 60 * 1000;

  /// Maximum reusable actions defined by one action scope.
  static const int maxActionDefinitions = 64;

  static final RegExp _screenIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');
  static final RegExp _actionNamePattern = RegExp(r'^[a-z][a-zA-Z0-9_]{0,63}$');
  static final RegExp _fieldNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
  static final RegExp _dataResourceIdPattern = RegExp(
    r'^[a-z][a-z0-9_]{0,63}$',
  );
  static final RegExp _dataFieldPathPattern = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$',
  );
  static final RegExp _jsonAssetPathPattern = RegExp(
    r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
  );
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
    'brain',
    'trophy',
    'timer',
    'close',
    'refresh',
    'bolt',
    'location',
    'menu',
    'add',
    'delete',
    'edit',
    'note',
    'sunny',
    'cloudy',
    'rain',
    'thunderstorm',
    'waterDrop',
    'wind',
    'thermometer',
    'snow',
    'fog',
    'public',
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
      'condition' => _parseConditionNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'countdown' => _parseCountdownNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'stateScope' => _parseStateScopeNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'actionScope' => _parseActionScopeNode(
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
      'lineChart' => _parseLineChartNode(
        props: props,
        children: parsedChildren,
        path: path,
        depth: depth,
        state: state,
      ),
      'refreshIndicator' => _parseRefreshIndicatorNode(
        props: props,
        children: parsedChildren,
        path: path,
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
      'tap' => _parseTapNode(
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
      'searchField' => _parseSearchFieldNode(
        props: props,
        children: parsedChildren,
        path: path,
      ),
      'stateTextField' => _parseStateTextFieldNode(
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
      'data.loadJsonAsset' => _parseDataLoadJsonAssetAction(type, props, path),
      'data.search' => _parseDataSearchAction(type, props, path),
      'location.getCurrent' => _parseLocationGetCurrentAction(
        type,
        props,
        path,
      ),
      'cache.set' => _parseCacheSetAction(type, props, path),
      'cache.get' => _parseCacheGetAction(type, props, path),
      'cache.has' => _parseCacheHasAction(type, props, path),
      'cache.remove' => _parseCacheRemoveAction(type, props, path),
      'cache.clear' => _parseCacheClearAction(type, props, path),
      'cache.info' => _parseCacheInfoAction(type, props, path),
      'sequence' => _parseSequenceAction(type, props, path),
      'action.ifElse' => _parseIfElseAction(type, props, path),
      'action.call' => _parseActionCall(type, props, path),
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
}
