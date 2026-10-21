part of '../../../mp_screen_renderer.dart';

// Overlay actions contain nodes, whose controls can contain more actions.
// Bound the complete mixed tree before parsing or encoding it, so a fresh
// node budget for each panel cannot bypass the screen's resource limits.
void _validateMpPayloadBudget(Object? payload, {required String path}) {
  var nodes = 0;
  var actions = 0;
  var members = 0;
  void visit(Object? value, int depth, int nodeDepth) {
    if (++members > 200000 || depth > 256) {
      _fail('Mp payload exceeds the structural complexity limit.', path: path);
    }
    if (value is Map) {
      final type = value['type'];
      if (type is String &&
          (value.containsKey('props') ||
              value.containsKey('children') ||
              value.length == 1)) {
        if (!type.contains('.') && type != 'sequence') {
          nodeDepth++;
          if (nodeDepth > MpScreenValidator.maxDepth) {
            _fail('Mp screen exceeds the maximum node depth.', path: path);
          }
          if (++nodes > MpScreenValidator.maxNodes) {
            _fail('Mp screen exceeds the maximum node count.', path: path);
          }
        } else if (++actions > 4000) {
          _fail('Mp payload exceeds the maximum action count.', path: path);
        }
      }
      for (final entry in value.entries) {
        if (entry.key is! String) {
          _fail('Mp JSON object keys must be strings.', path: path);
        }
        visit(entry.value, depth + 1, nodeDepth);
      }
    } else if (value is List) {
      for (final child in value) {
        visit(child, depth + 1, nodeDepth);
      }
    }
  }

  visit(payload, 0, 0);
  try {
    if (utf8.encode(jsonEncode(payload)).length >
        MpScreenValidator.maxPayloadBytes) {
      _fail(
        'Mp payload exceeds the ${MpScreenValidator.maxPayloadBytes} byte limit.',
        path: path,
      );
    }
  } on MiniProgramRenderException {
    rethrow;
  } catch (_) {
    _fail('Mp payload must be JSON-safe.', path: path);
  }
}

extension _MpOverlayActionValidation on MpScreenValidator {
  _MpAction _parseOverlayOpenAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    final drawer = type == ActionNames.drawerOpen;
    _validateObjectKeys(props, <String>{
      'side',
      'child',
      'dismissible',
      'enableDrag',
      'padding',
      'borderRadius',
      'backgroundColor',
      'barrierColor',
      'semanticLabel',
      if (drawer)
        'width'
      else ...[
        'heightFactor',
        'maxWidth',
        'showDragHandle',
      ],
    }, path: '$path.props');
    final side = _requiredStableString(props, 'side', path: '$path.props');
    if (!(drawer ? const ['left', 'right'] : const ['bottom', 'top']).contains(
      side,
    )) {
      _fail('Mp panel side is invalid.', path: '$path.props.side');
    }
    return _MpAction(
      type: type,
      props: {
        ..._parseOverlaySurface(
          props,
          path,
          defaultRadius: drawer ? 16 : 24,
          defaultPadding: 16,
        ),
        'side': side,
        'child': _parseOverlayChild(props, path),
        'enableDrag':
            _optionalBool(
              props['enableDrag'],
              path: '$path.props.enableDrag',
            ) ??
            true,
        if (drawer)
          'width': _boundedNumber(
            props['width'] ?? 320,
            path: '$path.props.width',
            minimum: 80,
            maximum: 1200,
          )
        else ...{
          'heightFactor': _boundedNumber(
            props['heightFactor'] ?? 0.6,
            path: '$path.props.heightFactor',
            minimum: 0.1,
            maximum: 1,
          ),
          'maxWidth': _boundedNumber(
            props['maxWidth'] ?? 640,
            path: '$path.props.maxWidth',
            minimum: 80,
            maximum: 1200,
          ),
          'showDragHandle':
              _optionalBool(
                props['showDragHandle'],
                path: '$path.props.showDragHandle',
              ) ??
              true,
        },
      },
    );
  }

  _MpAction _parseOverlayDialogAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    final custom = props.containsKey('child');
    _validateObjectKeys(props, <String>{
      'dismissible',
      'backgroundColor',
      'barrierColor',
      'semanticLabel',
      if (custom) ...[
        'child',
        'width',
        'padding',
        'borderRadius',
      ] else ...[
        'title',
        'message',
        'confirmLabel',
        'cancelLabel',
        'onConfirm',
        'onCancel',
      ],
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: {
        ..._parseOverlaySurface(
          props,
          path,
          defaultRadius: 24,
          defaultPadding: 24,
        ),
        'width': _boundedNumber(
          props['width'] ?? 420,
          path: '$path.props.width',
          minimum: 80,
          maximum: 1200,
        ),
        if (custom)
          'child': _parseOverlayChild(props, path)
        else ...{
          if (props.containsKey('title'))
            'title': _requiredString(props, 'title', path: '$path.props'),
          'message': _requiredString(props, 'message', path: '$path.props'),
          'confirmLabel': props.containsKey('confirmLabel')
              ? _requiredString(props, 'confirmLabel', path: '$path.props')
              : 'OK',
          if (props.containsKey('cancelLabel') || props.containsKey('onCancel'))
            'cancelLabel': props.containsKey('cancelLabel')
                ? _requiredString(props, 'cancelLabel', path: '$path.props')
                : 'Cancel',
          for (final key in ['onConfirm', 'onCancel'])
            if (props.containsKey(key))
              key: _parseAction(props[key], path: '$path.props.$key'),
        },
      },
    );
  }

  _MpNode _parseOverlayChild(Map<String, dynamic> props, String path) {
    final raw = props['child'];
    if (raw is! Map) {
      _fail('Mp panel child must be a node.', path: '$path.props.child');
    }
    return _parseNode(
      Map<String, dynamic>.from(raw),
      path: '$path.props.child',
      depth: 1,
      state: _MpValidationState(),
    );
  }

  Map<String, dynamic> _parseOverlaySurface(
    Map<String, dynamic> props,
    String path, {
    required num defaultRadius,
    required num defaultPadding,
  }) => {
    'dismissible':
        _optionalBool(props['dismissible'], path: '$path.props.dismissible') ??
        true,
    'padding': _boundedNumber(
      props['padding'] ?? defaultPadding,
      path: '$path.props.padding',
      minimum: 0,
      maximum: 64,
    ),
    'borderRadius': _boundedNumber(
      props['borderRadius'] ?? defaultRadius,
      path: '$path.props.borderRadius',
      minimum: 0,
      maximum: 64,
    ),
    for (final key in ['backgroundColor', 'barrierColor'])
      if (props.containsKey(key))
        key: _requiredHexColor(props, key, path: '$path.props'),
    if (props.containsKey('semanticLabel'))
      'semanticLabel': _requiredString(
        props,
        'semanticLabel',
        path: '$path.props',
      ),
  };
}
