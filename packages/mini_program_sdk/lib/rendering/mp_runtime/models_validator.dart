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

  /// Validates an Mp screen document without rendering it.
  void validate(Map<String, dynamic> json, {required String expectedScreenId}) {
    _parse(json, expectedScreenId: expectedScreenId);
  }

  /// Parses and validates [json] into an internal Mp screen model.
  _MpScreen _parse(
    Map<String, dynamic> json, {
    required String expectedScreenId,
  }) {
    final payloadBytes = utf8.encode(jsonEncode(json)).length;
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
      ),
      'card' => _parseCardNode(
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
      'safeArea' => _parseSafeAreaNode(
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
    _validateObjectKeys(props, const <String>{'data'}, path: '$path.props');
    _requiredString(props, 'data', path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(type: type, props: props, children: const <_MpNode>[]);
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

  _MpNode _parseImageNode({
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    _validateObjectKeys(props, const <String>{
      'src',
      'alt',
    }, path: '$path.props');
    final src = _requiredString(props, 'src', path: '$path.props');
    if (!_MpBindingResolver.containsBinding(src)) {
      _validateImageUrl(src, path: '$path.props.src');
    }
    if (props.containsKey('alt')) {
      _requiredString(props, 'alt', path: '$path.props');
    }
    _validateNoChildren(children, path: '$path.children');
    return _MpNode(type: 'image', props: props, children: const <_MpNode>[]);
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
      'form.submit' => _parseFormSubmitAction(type, props, path),
      'ui.toast' => _parseToastAction(type, props, path),
      'ui.dialog' => _parseDialogAction(type, props, path),
      'state.set' || 'state.put' => _parseStateSetAction(type, props, path),
      'state.increment' => _parseStateIncrementAction(type, props, path),
      'state.remove' => _parseStateRemoveAction(type, props, path),
      'state.clear' => _parseNoPropsAction(type, props, path),
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
