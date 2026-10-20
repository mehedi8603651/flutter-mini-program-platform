part of '../../mp_screen_renderer.dart';

/// Scoped defaults for toolbar content; explicit child styling takes priority.
class _MpAppBarScope extends InheritedWidget {
  const _MpAppBarScope({required this.foregroundColor, required super.child});

  final Color foregroundColor;

  static _MpAppBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MpAppBarScope>();

  @override
  bool updateShouldNotify(_MpAppBarScope oldWidget) =>
      foregroundColor != oldWidget.foregroundColor;
}

class _MpAppBar extends StatelessWidget {
  const _MpAppBar({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = _mpColor(
      node.props['foregroundColor'] as String?,
      fallback:
          theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
    );
    var index = 0;
    final leading = _bool(node, 'hasLeading') ? node.children[index++] : null;
    final title = node.children[index++];
    final actions = node.children.skip(index).toList(growable: false);
    final spacing = _double(node, 'spacing', fallback: 8);
    final height = _double(node, 'height', fallback: 64);
    final elevation = _double(node, 'elevation', fallback: 0);

    return _MpAppBarScope(
      foregroundColor: foreground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final padding = math.min(
            _double(node, 'paddingHorizontal', fallback: 12),
            width / 4,
          );
          final contentWidth = math.max(0.0, width - padding * 2);
          final titleMinimum = math.min(48.0, contentWidth / 3);
          final leadingWidth = leading == null
              ? 0.0
              : math.min(
                  _double(node, 'leadingWidth', fallback: 56),
                  contentWidth / 2,
                );
          final titleSpacing = leading == null ? padding : spacing;
          final actionWidth = math.max(
            0.0,
            contentWidth - leadingWidth - titleMinimum - titleSpacing * 2,
          );
          return SizedBox(
            width: width,
            height: height,
            child: AppBar(
              primary: false,
              automaticallyImplyLeading: false,
              centerTitle: _bool(node, 'centerTitle'),
              toolbarHeight: height,
              leadingWidth: leading == null ? null : leadingWidth + padding,
              titleSpacing: titleSpacing,
              backgroundColor: _mpColor(
                node.props['backgroundColor'] as String?,
                fallback:
                    theme.appBarTheme.backgroundColor ??
                    theme.colorScheme.surface,
              ),
              foregroundColor: foreground,
              shadowColor: node.props['shadowColor'] == null
                  ? theme.appBarTheme.shadowColor ?? theme.shadowColor
                  : _mpColor(
                      node.props['shadowColor'] as String?,
                      fallback: theme.shadowColor,
                    ),
              elevation: elevation,
              scrolledUnderElevation: elevation,
              surfaceTintColor: Colors.transparent,
              notificationPredicate: (_) => false,
              leading: leading == null
                  ? null
                  : Padding(
                      padding: EdgeInsetsDirectional.only(start: padding),
                      child: _MpNodeView(node: leading, bindings: bindings),
                    ),
              title: _MpNodeView(node: title, bindings: bindings),
              // A non-empty list also prevents an enclosing host Scaffold's
              // end drawer from inserting an unrelated toolbar action.
              actions: <Widget>[
                if (actions.isEmpty)
                  const SizedBox.shrink()
                else
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: padding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: actionWidth),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (
                              var action = 0;
                              action < actions.length;
                              action++
                            ) ...[
                              if (action > 0) SizedBox(width: spacing),
                              _MpNodeView(
                                node: actions[action],
                                bindings: bindings,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
