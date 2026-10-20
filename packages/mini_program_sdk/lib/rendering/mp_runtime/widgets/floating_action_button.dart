part of '../../mp_screen_renderer.dart';

class _MpFloatingActionButton extends StatefulWidget {
  const _MpFloatingActionButton({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpFloatingActionButton> createState() =>
      _MpFloatingActionButtonState();
}

class _MpFloatingActionButtonState extends State<_MpFloatingActionButton> {
  bool _running = false;

  Future<void> _press() async {
    if (_running || !_bool(widget.node, 'enabled')) return;
    setState(() => _running = true);
    try {
      await _MpActionDispatcher.dispatch(
        context,
        widget.node.props['action'] as _MpAction,
        widget.bindings,
        const _MpActionCallContext(userGesture: true),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final enabled = _bool(node, 'enabled') && !_running;
    final semanticLabel = widget.bindings.resolveString(
      _string(node, 'semanticLabel'),
    );
    final background = node.props['backgroundColor'] as String?;
    final foreground = node.props['foregroundColor'] as String?;
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = background == null
        ? null
        : _mpColor(background, fallback: colors.primaryContainer);
    final foregroundColor = foreground == null
        ? null
        : _mpColor(foreground, fallback: colors.onPrimaryContainer);
    final onPressed = enabled ? () => unawaited(_press()) : null;
    final icon = node.props['icon'] as String?;
    Widget? iconWidget({double? size}) => icon == null
        ? null
        : ExcludeSemantics(child: Icon(_mpIconData(icon), size: size));

    Widget button;
    switch (_string(node, 'variant')) {
      case 'small':
        button = FloatingActionButton.small(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          child: iconWidget(),
        );
      case 'large':
        button = FloatingActionButton.large(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          child: iconWidget(),
        );
      case 'extended':
        button = LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final labelWidth = math.max(0.0, width - (icon == null ? 40 : 72));
            return FloatingActionButton.extended(
              heroTag: null,
              onPressed: onPressed,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
              extendedIconLabelSpacing: 8,
              icon: iconWidget(size: 24),
              label: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelWidth),
                  child: Text(
                    widget.bindings.resolveString(_string(node, 'label')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        );
      default:
        button = FloatingActionButton(
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          child: iconWidget(),
        );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: button,
      ),
    );
  }
}
