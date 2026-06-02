import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../sdk_context.dart';
import '../widgets/sdk_email_auth_sheet.dart';
import 'mini_program_screen_renderer.dart';

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

    final type = _requiredString(json, 'type', path: path);
    final props = _optionalMap(json['props'], path: '$path.props');
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

    switch (type) {
      case 'column':
      case 'row':
        _validateNoProps(props, path: '$path.props');
        break;
      case 'text':
      case 'heading':
        _validateObjectKeys(props, const <String>{'data'}, path: '$path.props');
        _requiredString(props, 'data', path: '$path.props');
        _validateNoChildren(parsedChildren, path: '$path.children');
        break;
      case 'sizedBox':
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
        _validateNoChildren(parsedChildren, path: '$path.children');
        break;
      case 'image':
        _validateObjectKeys(props, const <String>{
          'src',
          'alt',
        }, path: '$path.props');
        final src = _requiredString(props, 'src', path: '$path.props');
        _validateImageUrl(src, path: '$path.props.src');
        if (props.containsKey('alt')) {
          _requiredString(props, 'alt', path: '$path.props');
        }
        _validateNoChildren(parsedChildren, path: '$path.children');
        break;
      case 'card':
        _validateNoProps(props, path: '$path.props');
        if (parsedChildren.length != 1) {
          _fail('Mp card requires exactly one child.', path: '$path.children');
        }
        break;
      case 'primaryButton':
      case 'secondaryButton':
        _validateObjectKeys(props, const <String>{
          'label',
          'action',
        }, path: '$path.props');
        _requiredString(props, 'label', path: '$path.props');
        _parseAction(props['action'], path: '$path.props.action');
        _validateNoChildren(parsedChildren, path: '$path.children');
        break;
      default:
        _fail(
          'Unsupported Mp node type "$type".',
          path: '$path.type',
          details: <String, dynamic>{'nodeType': type},
        );
    }

    return _MpNode(
      type: type,
      props: props,
      children: List<_MpNode>.unmodifiable(parsedChildren),
    );
  }

  _MpAction _parseAction(Object? value, {required String path}) {
    if (value is! Map) {
      _fail('Mp action must be an object.', path: path);
    }
    final json = Map<String, dynamic>.from(value);
    _validateObjectKeys(json, const <String>{'type', 'props'}, path: path);
    final type = _requiredString(json, 'type', path: path);
    final props = _optionalMap(json['props'], path: '$path.props');
    switch (type) {
      case 'auth.showEmailAuth':
        _validateNoProps(props, path: '$path.props');
        break;
      default:
        _fail(
          'Unsupported Mp action type "$type".',
          path: '$path.type',
          details: <String, dynamic>{'actionType': type},
        );
    }
    return _MpAction(type: type, props: props);
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
      _fail('This Mp node does not support props.', path: path);
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

class _MpScreenView extends StatelessWidget {
  const _MpScreenView({required this.screen});

  final _MpScreen screen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(node: screen.root),
      ),
    );
  }
}

class _MpNodeView extends StatelessWidget {
  const _MpNodeView({required this.node});

  final _MpNode node;

  @override
  Widget build(BuildContext context) {
    switch (node.type) {
      case 'column':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: node.children
              .map((child) => _MpNodeView(node: child))
              .toList(growable: false),
        );
      case 'row':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: node.children
              .map((child) => Flexible(child: _MpNodeView(node: child)))
              .toList(growable: false),
        );
      case 'text':
        return Text(
          node.props['data'] as String,
          style: const TextStyle(
            fontSize: 15,
            height: 1.35,
            color: Color(0xFF263238),
          ),
        );
      case 'heading':
        return Text(
          node.props['data'] as String,
          style: const TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        );
      case 'sizedBox':
        return SizedBox(
          width: (node.props['width'] as num?)?.toDouble(),
          height: (node.props['height'] as num?)?.toDouble(),
        );
      case 'image':
        return Image.network(
          node.props['src'] as String,
          semanticLabel: node.props['alt'] as String?,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFFE5E7EB)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Image unavailable'),
              ),
            );
          },
        );
      case 'card':
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _MpNodeView(node: node.children.single),
          ),
        );
      case 'primaryButton':
        return _MpButton(
          label: node.props['label'] as String,
          action: _actionFromProps(node.props),
          primary: true,
        );
      case 'secondaryButton':
        return _MpButton(
          label: node.props['label'] as String,
          action: _actionFromProps(node.props),
          primary: false,
        );
      default:
        throw MiniProgramRenderException(
          message: 'Unsupported Mp node type "${node.type}".',
          details: <String, dynamic>{'nodeType': node.type},
        );
    }
  }

  _MpAction _actionFromProps(Map<String, dynamic> props) {
    final action = Map<String, dynamic>.from(props['action'] as Map);
    return _MpAction(
      type: action['type'] as String,
      props: Map<String, dynamic>.from(action['props'] as Map? ?? const {}),
    );
  }
}

class _MpButton extends StatefulWidget {
  const _MpButton({
    required this.label,
    required this.action,
    required this.primary,
  });

  final String label;
  final _MpAction action;
  final bool primary;

  @override
  State<_MpButton> createState() => _MpButtonState();
}

class _MpButtonState extends State<_MpButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.primary
        ? (_pressed
              ? const Color(0xFF065F56)
              : _hovered || _focused
              ? const Color(0xFF0F766E)
              : const Color(0xFF0B7A75))
        : const Color(0xFFFFFFFF);
    final foreground = widget.primary
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B7A75);

    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () => _dispatchAction(context, widget.action),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: const Color(0xFF0B7A75)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dispatchAction(BuildContext context, _MpAction action) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    switch (action.type) {
      case 'auth.showEmailAuth':
        final controller = scope.authController;
        final connector = scope.backendConnector;
        if (controller == null || connector == null) {
          scope.logger.warn(
            'Mp auth action ignored because auth or backend is not configured.',
            context: <String, Object?>{
              'miniProgramId': scope.miniProgramId,
              'actionType': action.type,
            },
          );
          return;
        }
        await showMiniProgramEmailAuthSheet(
          context: context,
          controller: controller,
          connector: connector,
          miniProgramId: scope.miniProgramId,
          initialMode: MiniProgramEmailAuthMode.signIn,
        );
    }
  }
}
