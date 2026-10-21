part of '../../mp_screen_renderer.dart';

class _MpPanelSurface extends StatefulWidget {
  const _MpPanelSurface({required this.session});
  final _MpOverlaySession session;
  @override
  State<_MpPanelSurface> createState() => _MpPanelSurfaceState();
}

class _MpPanelSurfaceState extends State<_MpPanelSurface> {
  double _drag = 0;

  _MpOverlaySession get session => widget.session;

  void _endDrag(DragEndDetails details) {
    final side = session.props['side'];
    final sign = side == 'left' || side == 'top' ? -1 : 1;
    final speed = details.primaryVelocity ?? 0;
    if (_drag * sign > 48 || speed * sign > 500) session.close();
    _drag = 0;
  }

  @override
  Widget build(BuildContext context) {
    final props = session.props;
    final bindings = session.bindings.copyWith(
      scope: MiniProgramSdkScope.of(context),
      form: session.form?._disposed == false
          ? session.form!.toBindingData()
          : null,
    );
    final custom = props['child'] as _MpNode?;
    final radius = (props['borderRadius'] as num).toDouble();
    final side = props['side'];
    final shape = switch (side) {
      'left' => BorderRadius.horizontal(right: Radius.circular(radius)),
      'right' => BorderRadius.horizontal(left: Radius.circular(radius)),
      'bottom' => BorderRadius.vertical(top: Radius.circular(radius)),
      'top' => BorderRadius.vertical(bottom: Radius.circular(radius)),
      _ => BorderRadius.circular(radius),
    };
    Widget content = Padding(
      padding: EdgeInsets.all((props['padding'] as num).toDouble()),
      child: custom != null
          ? _MpNodeView(node: custom, bindings: bindings)
          : _MpPanelDialog(session: session, bindings: bindings),
    );
    content = SingleChildScrollView(primary: false, child: content);
    if (session.kind == 'sheet') {
      final handle = props['showDragHandle'] == true
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: props['enableDrag'] == true
                  ? (_) => _drag = 0
                  : null,
              onVerticalDragUpdate: props['enableDrag'] == true
                  ? (d) => _drag += d.delta.dy
                  : null,
              onVerticalDragEnd: props['enableDrag'] == true ? _endDrag : null,
              child: SizedBox(
                height: 40,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink();
      final body = content;
      content = LayoutBuilder(
        builder: (context, limits) {
          final boundedHandle = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: limits.maxHeight / 2),
            child: handle,
          );
          return Column(
            children: [
              if (side == 'bottom') boundedHandle,
              Expanded(child: body),
              if (side == 'top') boundedHandle,
            ],
          );
        },
      );
    }
    content = Material(
      key: ValueKey('mp-${session.kind}-${side ?? 'center'}'),
      color: props['backgroundColor'] == null
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : _mpColor(
              props['backgroundColor'] as String,
              fallback: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
      elevation: 16,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    if (session.kind == 'drawer' && props['enableDrag'] == true) {
      content = GestureDetector(
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
        onHorizontalDragEnd: _endDrag,
        child: content,
      );
    }
    if (session.kind == 'sheet' &&
        props['enableDrag'] == true &&
        props['showDragHandle'] != true) {
      content = GestureDetector(
        onVerticalDragStart: (_) => _drag = 0,
        onVerticalDragUpdate: (d) => _drag += d.delta.dy,
        onVerticalDragEnd: _endDrag,
        child: content,
      );
    }
    final label = props['semanticLabel'] as String?;
    final surface = Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: label == null
          ? '${session.kind} panel'
          : bindings.resolveString(label),
      explicitChildNodes: true,
      child: FocusTraversalGroup(child: content),
    );
    return SafeArea(
      child: AnimatedPadding(
        padding: MediaQuery.viewInsetsOf(context),
        duration: const Duration(milliseconds: 150),
        child: LayoutBuilder(
          builder: (context, limits) {
            if (session.kind == 'drawer') {
              return Align(
                alignment: side == 'left'
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: SizedBox(
                  width: math.min(
                    (props['width'] as num).toDouble(),
                    limits.maxWidth * 0.94,
                  ),
                  height: limits.maxHeight,
                  child: surface,
                ),
              );
            }
            final maxWidth = session.kind == 'sheet'
                ? props['maxWidth']
                : props['width'];
            final width = math.min(
              (maxWidth as num).toDouble(),
              math.max(0.0, limits.maxWidth - 32),
            );
            return Align(
              alignment: side == 'top'
                  ? Alignment.topCenter
                  : side == 'bottom'
                  ? Alignment.bottomCenter
                  : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    0.0,
                    limits.maxHeight - (session.kind == 'dialog' ? 32 : 0),
                  ),
                ),
                child: SizedBox(
                  width: width,
                  height: session.kind == 'sheet'
                      ? limits.maxHeight *
                            (props['heightFactor'] as num).toDouble()
                      : null,
                  child: surface,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MpPanelDialog extends StatefulWidget {
  const _MpPanelDialog({required this.session, required this.bindings});
  final _MpOverlaySession session;
  final _MpRenderBindings bindings;
  @override
  State<_MpPanelDialog> createState() => _MpPanelDialogState();
}

class _MpPanelDialogState extends State<_MpPanelDialog> {
  bool _pending = false;
  String? _error;

  Future<void> _choose(String key) async {
    if (_pending || !widget.session.current) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    final action = widget.session.props[key] as _MpAction?;
    final result = action == null
        ? null
        : await _MpActionDispatcher.dispatch(
            context,
            action,
            widget.bindings,
            const _MpActionCallContext(userGesture: true),
          );
    if (!mounted) return;
    setState(() => _pending = false);
    if (result is HostActionResult && !result.isSuccess) {
      setState(() => _error = 'Unable to complete this action.');
      return;
    }
    widget.session.close();
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.session.props;
    final state = widget.bindings.scope?.stateManager;
    final paths = <String>{
      for (final key in ['title', 'message', 'confirmLabel', 'cancelLabel'])
        ..._stateBindingPaths(props[key]),
    };
    return AnimatedBuilder(
      animation: Listenable.merge([
        if (state != null)
          for (final path in paths) state.watch(path),
      ]),
      builder: (context, _) {
        String text(String key) =>
            widget.bindings.resolveString(props[key] as String);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (props['title'] != null) ...[
              Text(
                text('title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
            ],
            Text(text('message'), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                if (props['cancelLabel'] != null)
                  TextButton(
                    onPressed: _pending ? null : () => _choose('onCancel'),
                    child: Text(text('cancelLabel')),
                  ),
                TextButton(
                  onPressed: _pending ? null : () => _choose('onConfirm'),
                  child: Text(text('confirmLabel')),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      },
    );
  }
}
