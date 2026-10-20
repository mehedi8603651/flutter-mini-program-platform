part of '../../mp_screen_renderer.dart';

class _MpBottomNavigationBar extends StatefulWidget {
  const _MpBottomNavigationBar({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpBottomNavigationBar> createState() => _MpBottomNavigationBarState();
}

class _MpBottomNavigationBarState extends State<_MpBottomNavigationBar> {
  bool _running = false;

  Future<void> _select(int index) async {
    final items = widget.node.props['items'] as List;
    final item = items[index] as Map<String, dynamic>;
    if (_running || item['enabled'] != true) return;
    setState(() => _running = true);
    try {
      await _MpActionDispatcher.dispatch(
        context,
        item['action'] as _MpAction,
        widget.bindings.copyWith(scope: MiniProgramSdkScope.maybeOf(context)),
        const _MpActionCallContext(userGesture: true),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.node.props['items'] as List;
    final state = MiniProgramSdkScope.maybeOf(context)?.stateManager;
    final paths = <String>{
      ..._stateBindingPaths(widget.node.props['selectedIndex']),
      for (final item in items) ..._stateBindingPaths((item as Map)['label']),
    };
    if (state == null || paths.isEmpty) return _buildBar(context);
    return AnimatedBuilder(
      animation: Listenable.merge(
        paths.map(state.watch).toList(growable: false),
      ),
      builder: (context, _) => _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final node = widget.node;
    final items = node.props['items'] as List;
    final bindings = widget.bindings.copyWith(
      scope: MiniProgramSdkScope.maybeOf(context),
    );
    final selection = bindings.resolveValue(node.props['selectedIndex']);
    final selected =
        selection is int && selection >= 0 && selection < items.length
        ? selection
        : 0;
    final theme = Theme.of(context);
    final barTheme = NavigationBarTheme.of(context);
    Color? color(String key) => node.props[key] == null
        ? null
        : _mpColor(
            node.props[key] as String,
            fallback: theme.colorScheme.onSurface,
          );
    final selectedColor = color('selectedItemColor');
    final unselectedColor = color('unselectedItemColor');
    Color? itemColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return null;
      return states.contains(WidgetState.selected)
          ? selectedColor
          : unselectedColor;
    }

    return NavigationBarTheme(
      data: barTheme.copyWith(
        iconTheme: selectedColor == null && unselectedColor == null
            ? null
            : WidgetStateProperty.resolveWith((states) {
                final base = barTheme.iconTheme?.resolve(states);
                final override = itemColor(states);
                return override == null
                    ? base
                    : (base ?? const IconThemeData()).copyWith(color: override);
              }),
        labelTextStyle: selectedColor == null && unselectedColor == null
            ? null
            : WidgetStateProperty.resolveWith((states) {
                final base = barTheme.labelTextStyle?.resolve(states);
                final override = itemColor(states);
                return override == null
                    ? base
                    : (base ?? theme.textTheme.labelMedium ?? const TextStyle())
                          .copyWith(color: override);
              }),
      ),
      // The surrounding Mp.page/safeArea owns display insets, as for Mp.appBar.
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final contentWidth = math.max(width, items.length * 64.0);
            final bar = SizedBox(
              width: contentWidth,
              child: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (index) => unawaited(_select(index)),
                height: _double(node, 'height', fallback: 80),
                elevation: _double(node, 'elevation', fallback: 0),
                backgroundColor: color('backgroundColor'),
                indicatorColor: color('indicatorColor'),
                surfaceTintColor: Colors.transparent,
                labelBehavior: switch (_string(node, 'labelBehavior')) {
                  'onlyShowSelected' =>
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                  'alwaysHide' => NavigationDestinationLabelBehavior.alwaysHide,
                  _ => NavigationDestinationLabelBehavior.alwaysShow,
                },
                destinations: <Widget>[
                  for (final raw in items)
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      child: NavigationDestination(
                        icon: Icon(_mpIconData((raw as Map)['icon'] as String)),
                        selectedIcon: raw['selectedIcon'] == null
                            ? null
                            : Icon(_mpIconData(raw['selectedIcon'] as String)),
                        label: bindings.resolveString(raw['label'] as String),
                        enabled: raw['enabled'] == true && !_running,
                      ),
                    ),
                ],
              ),
            );
            return contentWidth <= width
                ? bar
                : SizedBox(
                    width: width,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: bar,
                    ),
                  );
          },
        ),
      ),
    );
  }
}
