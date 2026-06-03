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
      'primaryButton' || 'secondaryButton' => _parseButtonNode(
        type: type,
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

  static bool? _optionalBool(Object? value, {required String path}) {
    if (value == null) {
      return null;
    }
    if (value is! bool) {
      _fail('Mp value must be a boolean.', path: path);
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
