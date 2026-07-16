part of '../../mp_screen_renderer.dart';

class _MpTapButton extends StatefulWidget {
  const _MpTapButton({
    required this.label,
    required this.primary,
    required this.onTap,
    this.enabled = true,
    this.theme,
  });

  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback? onTap;
  final _MpThemeData? theme;

  @override
  State<_MpTapButton> createState() => _MpTapButtonState();
}

class _MpTapButtonState extends State<_MpTapButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final colors = _mpButtonColors(
      primary: widget.primary,
      enabled: enabled,
      hoveredOrFocused: _hovered || _focused,
      pressed: _pressed,
      theme: widget.theme,
    );
    final background = !enabled ? colors.disabledBackground : colors.background;
    final foreground = !enabled ? colors.disabledForeground : colors.foreground;
    final border = !enabled ? colors.disabledBorder : colors.border;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onTap : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: _mpThemeTextStyle(
                    widget.theme,
                    'button',
                    defaultColor: foreground,
                    defaultSize: 15,
                    defaultWeight: 'semibold',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpButton extends StatefulWidget {
  const _MpButton({
    required this.node,
    required this.primary,
    required this.bindings,
  });

  final _MpNode node;
  final bool primary;
  final _MpRenderBindings bindings;

  @override
  State<_MpButton> createState() => _MpButtonState();
}

class _MpButtonState extends State<_MpButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.bindings.resolveString(
      widget.node.props['label'] as String,
    );
    final styled = widget.node.type == 'button';
    final colors = _mpButtonColors(
      primary: widget.primary,
      enabled: true,
      hoveredOrFocused: _hovered || _focused,
      pressed: _pressed,
      theme: widget.bindings.theme,
    );
    final background = styled
        ? _mpColor(
            widget.node.props['backgroundColor'] as String?,
            fallback: colors.background,
          )
        : colors.background;
    final pressedBackground = _pressed
        ? Color.lerp(background, const Color(0xFF000000), 0.14)!
        : background;
    final foreground = styled
        ? _mpColor(
            widget.node.props['foregroundColor'] as String?,
            fallback: colors.foreground,
          )
        : colors.foreground;
    final border = styled
        ? _mpColor(
            widget.node.props['borderColor'] as String?,
            fallback: colors.border,
          )
        : colors.border;
    final borderWidth = styled
        ? (widget.node.props['borderWidth'] as num).toDouble()
        : 1.0;
    final borderRadius = styled
        ? (widget.node.props['borderRadius'] as num).toDouble()
        : 8.0;
    final height = styled
        ? (widget.node.props['height'] as num).toDouble()
        : null;

    return Semantics(
      button: true,
      label: label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () => unawaited(
            _MpActionDispatcher.dispatch(
              context,
              widget.node.props['action'] as _MpAction,
              widget.bindings,
            ),
          ),
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pressedBackground,
                border: Border.all(color: border, width: borderWidth),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: styled ? 8 : 16,
                  vertical: styled ? 0 : 11,
                ),
                child: Center(
                  widthFactor: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: styled
                          ? TextStyle(
                              color: foreground,
                              fontSize: (widget.node.props['fontSize'] as num)
                                  .toDouble(),
                              fontWeight: _mpFontWeight(
                                widget.node.props['fontWeight'] as String,
                              ),
                            )
                          : _mpThemeTextStyle(
                              widget.bindings.theme,
                              'button',
                              defaultColor: foreground,
                              defaultSize: 15,
                              defaultWeight: 'semibold',
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpIconButton extends StatefulWidget {
  const _MpIconButton({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpIconButton> createState() => _MpIconButtonState();
}

class _MpIconButtonState extends State<_MpIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final size = (node.props['size'] as num).toDouble();
    final background = _mpColor(
      node.props['backgroundColor'] as String?,
      fallback: const Color(0x00000000),
    );
    return Semantics(
      button: true,
      label: node.props['semanticLabel'] as String,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => unawaited(
          _MpActionDispatcher.dispatch(
            context,
            node.props['action'] as _MpAction,
            widget.bindings,
          ),
        ),
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _pressed
                  ? Color.lerp(background, const Color(0xFFFFFFFF), 0.12)
                  : background,
              border: Border.all(
                color: _mpColor(
                  node.props['borderColor'] as String?,
                  fallback: const Color(0x00000000),
                ),
                width: (node.props['borderWidth'] as num).toDouble(),
              ),
              borderRadius: BorderRadius.circular(
                (node.props['borderRadius'] as num).toDouble(),
              ),
            ),
            child: Center(
              child: Icon(
                _mpIconData(node.props['name'] as String),
                size: (node.props['iconSize'] as num).toDouble(),
                color: _mpColor(
                  node.props['color'] as String?,
                  fallback: const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpListTile extends StatelessWidget {
  const _MpListTile({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final title = bindings.resolveString(_string(node, 'title'));
    final subtitle = _optionalResolvedString(node, bindings, 'subtitle');
    final badge = _optionalResolvedString(node, bindings, 'badge');
    final action = node.props['action'] as _MpAction?;
    final leadingIcon = node.props['leadingIcon'] as String?;
    final trailingIcon = node.props['trailingIcon'] as String?;
    final surface = _mpThemeToken(
      bindings.theme,
      'surface',
      fallback: const Color(0xFFFFFFFF),
    );
    final border = _mpThemeToken(
      bindings.theme,
      'border',
      fallback: const Color(0xFFE5E7EB),
    );
    final text = _mpThemeToken(
      bindings.theme,
      'text',
      fallback: const Color(0xFF111827),
    );
    final textMuted = _mpThemeToken(
      bindings.theme,
      'textMuted',
      fallback: const Color(0xFF6B7280),
    );
    final iconColor = _mpThemeToken(
      bindings.theme,
      'icon',
      fallback: const Color(0xFF4B5563),
    );

    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                _MpIconGlyph(name: leadingIcon, size: 20, color: iconColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _mpThemeTextStyle(
                        bindings.theme,
                        'listTileTitle',
                        defaultColor: text,
                        defaultSize: 15,
                        defaultWeight: 'semibold',
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _mpThemeTextStyle(
                          bindings.theme,
                          'listTileSubtitle',
                          defaultColor: textMuted,
                          defaultSize: 13,
                          defaultWeight: 'regular',
                          defaultHeight: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: 10),
                _MpBadgePill(label: badge, tone: 'info', theme: bindings.theme),
              ],
              if (trailingIcon != null || action != null) ...<Widget>[
                const SizedBox(width: 10),
                _MpIconGlyph(
                  name: trailingIcon ?? 'chevronRight',
                  size: 20,
                  color: textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (action == null) {
      return row;
    }
    return _MpActionTap(
      label: title,
      action: action,
      bindings: bindings,
      child: row,
    );
  }
}

class _MpActionTap extends StatelessWidget {
  const _MpActionTap({
    required this.label,
    required this.action,
    required this.bindings,
    required this.child,
  });

  final String label;
  final _MpAction action;
  final _MpRenderBindings bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(
            _MpActionDispatcher.dispatch(context, action, bindings),
          ),
          child: child,
        ),
      ),
    );
  }
}
