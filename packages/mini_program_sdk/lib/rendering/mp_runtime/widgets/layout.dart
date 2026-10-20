part of '../../mp_screen_renderer.dart';

const _defaultMpResponsiveBreakpoints = _MpResponsiveBreakpoints(
  mediumMinWidth: 600,
  expandedMinWidth: 840,
);

class _MpResponsiveBreakpoints {
  const _MpResponsiveBreakpoints({
    required this.mediumMinWidth,
    required this.expandedMinWidth,
  });

  final double mediumMinWidth;
  final double expandedMinWidth;
}

class _MpResponsiveScope extends InheritedWidget {
  const _MpResponsiveScope({required this.breakpoints, required super.child});

  final _MpResponsiveBreakpoints breakpoints;

  static _MpResponsiveBreakpoints of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_MpResponsiveScope>()
            ?.breakpoints ??
        _defaultMpResponsiveBreakpoints;
  }

  @override
  bool updateShouldNotify(_MpResponsiveScope oldWidget) {
    return breakpoints.mediumMinWidth != oldWidget.breakpoints.mediumMinWidth ||
        breakpoints.expandedMinWidth != oldWidget.breakpoints.expandedMinWidth;
  }
}

class _MpPage extends StatelessWidget {
  const _MpPage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    Widget child = _MpNodeView(node: node.children.single, bindings: bindings);
    final rawBreakpoints = node.props['breakpoints'] as Map<String, dynamic>?;
    final breakpoints = rawBreakpoints == null
        ? _defaultMpResponsiveBreakpoints
        : _MpResponsiveBreakpoints(
            mediumMinWidth: (rawBreakpoints['mediumMinWidth'] as num)
                .toDouble(),
            expandedMinWidth: (rawBreakpoints['expandedMinWidth'] as num)
                .toDouble(),
          );
    child = _MpResponsiveScope(breakpoints: breakpoints, child: child);
    if (_bool(node, 'safeArea')) {
      child = SafeArea(child: child);
    }
    final backgroundColor = node.props['backgroundColor'] as String?;
    return ColoredBox(
      color: _mpColor(
        backgroundColor,
        fallback: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: child,
    );
  }
}

class _MpResponsive extends StatelessWidget {
  const _MpResponsive({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final breakpoints = _MpResponsiveScope.of(context);
    final compact = node.children.first;
    var index = 1;
    final medium = _bool(node, 'hasMedium') ? node.children[index++] : compact;
    final expanded = _bool(node, 'hasExpanded') ? node.children[index] : medium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final selected = width >= breakpoints.expandedMinWidth
            ? expanded
            : width >= breakpoints.mediumMinWidth
            ? medium
            : compact;
        return _MpNodeView(node: selected, bindings: bindings);
      },
    );
  }
}

class _MpConstrainedContent extends StatelessWidget {
  const _MpConstrainedContent({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _double(node, 'paddingHorizontal', fallback: 16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _double(node, 'maxWidth', fallback: 1200),
          ),
          child: SizedBox(
            width: double.infinity,
            child: _MpNodeView(node: node.children.single, bindings: bindings),
          ),
        ),
      ),
    );
  }
}

class _MpColumn extends StatelessWidget {
  const _MpColumn({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _mpFlexChildren(
          node.children,
          bindings: bindings,
          isRow: false,
          hasBoundedMainAxis: constraints.hasBoundedHeight,
        ),
      ),
    );
  }
}

class _MpRow extends StatelessWidget {
  const _MpRow({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _mpFlexChildren(
          node.children,
          bindings: bindings,
          isRow: true,
          hasBoundedMainAxis: constraints.hasBoundedWidth,
        ),
      ),
    );
  }
}

class _MpContainer extends StatelessWidget {
  const _MpContainer({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    Widget child = _MpNodeView(node: node.children.single, bindings: bindings);
    final padding = _mpInsets(node.props['padding'] as Map<String, dynamic>?);
    if (padding != EdgeInsets.zero) {
      child = Padding(padding: padding, child: child);
    }

    final decoration = _containerDecoration(node);
    if (decoration != null) {
      child = DecoratedBox(decoration: decoration, child: child);
    }

    final width = _optionalDouble(node, 'width');
    final height = _optionalDouble(node, 'height');
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}

class _MpScrollView extends StatelessWidget {
  const _MpScrollView({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final padding = _mpInsets(node.props['padding'] as Map<String, dynamic>?);
    return LayoutBuilder(
      builder: (context, constraints) {
        final child = _MpNodeView(
          node: node.children.single,
          bindings: bindings,
        );
        if (!constraints.hasBoundedHeight) {
          return padding == EdgeInsets.zero
              ? child
              : Padding(padding: padding, child: child);
        }
        return SingleChildScrollView(
          primary: false,
          padding: padding,
          child: child,
        );
      },
    );
  }
}

class _MpVisibility extends StatelessWidget {
  const _MpVisibility({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final maintainSize = _bool(node, 'maintainSize');
    final maintainState = maintainSize || _bool(node, 'maintainState');
    return Visibility(
      visible: _bool(node, 'visible'),
      maintainSize: maintainSize,
      maintainState: maintainState,
      maintainAnimation: maintainSize,
      child: _MpNodeView(node: node.children.single, bindings: bindings),
    );
  }
}

class _MpStack extends StatelessWidget {
  const _MpStack({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: _mpAlignment(_string(node, 'alignment')),
      clipBehavior: _bool(node, 'clip') ? Clip.hardEdge : Clip.none,
      children: node.children
          .map(
            (child) => _MpNodeView(
              node: child,
              bindings: bindings,
              parentKind: _MpParentKind.stack,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _MpPositioned extends StatelessWidget {
  const _MpPositioned({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _optionalDouble(node, 'bottom'),
      height: _optionalDouble(node, 'height'),
      left: _optionalDouble(node, 'left'),
      right: _optionalDouble(node, 'right'),
      top: _optionalDouble(node, 'top'),
      width: _optionalDouble(node, 'width'),
      child: _MpNodeView(node: node.children.single, bindings: bindings),
    );
  }
}

BoxDecoration? _containerDecoration(_MpNode node) {
  final backgroundColor = node.props['backgroundColor'] as String?;
  final borderColor = node.props['borderColor'] as String?;
  final borderWidth = _optionalDouble(node, 'borderWidth');
  final borderRadius = _optionalDouble(node, 'borderRadius');
  if (backgroundColor == null &&
      borderColor == null &&
      borderWidth == null &&
      borderRadius == null) {
    return null;
  }
  return BoxDecoration(
    color: backgroundColor == null
        ? null
        : _mpColor(backgroundColor, fallback: const Color(0xFFFFFFFF)),
    border: borderColor == null && borderWidth == null
        ? null
        : Border.all(
            color: _mpColor(borderColor, fallback: const Color(0xFFE5E7EB)),
            width: borderWidth ?? 1,
          ),
    borderRadius: BorderRadius.circular(borderRadius ?? 0),
  );
}

List<Widget> _mpFlexChildren(
  List<_MpNode> children, {
  required _MpRenderBindings bindings,
  required bool isRow,
  required bool hasBoundedMainAxis,
}) {
  return children
      .map((child) {
        if (child.type == 'spacer') {
          return Spacer(flex: _int(child, 'flex', fallback: 1));
        }
        if (child.type == 'expanded' || child.type == 'flexible') {
          final view = _MpNodeView(
            node: child.children.single,
            bindings: bindings,
          );
          if (!hasBoundedMainAxis) {
            return view;
          }
          final flex = _int(child, 'flex', fallback: 1);
          if (child.type == 'expanded') {
            return Expanded(flex: flex, child: view);
          }
          return Flexible(
            flex: flex,
            fit: _mpFlexFit(_string(child, 'fit')),
            child: view,
          );
        }
        final view = _MpNodeView(node: child, bindings: bindings);
        return isRow ? Flexible(child: view) : view;
      })
      .toList(growable: false);
}

FlexFit _mpFlexFit(String value) {
  return switch (value) {
    'tight' => FlexFit.tight,
    _ => FlexFit.loose,
  };
}

Alignment _mpAlignment(String value) {
  return switch (value) {
    'topLeft' => Alignment.topLeft,
    'topCenter' => Alignment.topCenter,
    'topRight' => Alignment.topRight,
    'centerLeft' => Alignment.centerLeft,
    'centerRight' => Alignment.centerRight,
    'bottomLeft' => Alignment.bottomLeft,
    'bottomCenter' => Alignment.bottomCenter,
    'bottomRight' => Alignment.bottomRight,
    _ => Alignment.center,
  };
}

EdgeInsets _mpInsets(Map<String, dynamic>? padding) {
  return EdgeInsets.only(
    bottom: _mapDouble(padding, 'bottom'),
    left: _mapDouble(padding, 'left'),
    right: _mapDouble(padding, 'right'),
    top: _mapDouble(padding, 'top'),
  );
}
