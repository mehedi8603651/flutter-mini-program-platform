part of '../../mp_screen_renderer.dart';

class _MpListView extends StatelessWidget {
  const _MpListView({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final spacing = _double(node, 'spacing', fallback: 0);
    final horizontal = _string(node, 'direction') == 'horizontal';
    final list = ListView.separated(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      shrinkWrap: true,
      primary: false,
      physics: horizontal
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: _mpInsets(node.props['padding'] as Map<String, dynamic>?),
      itemCount: node.children.length,
      separatorBuilder: (context, index) =>
          horizontal ? SizedBox(width: spacing) : SizedBox(height: spacing),
      itemBuilder: (context, index) =>
          _MpNodeView(node: node.children[index], bindings: bindings),
    );
    final height = _optionalDouble(node, 'height');
    return height == null ? list : SizedBox(height: height, child: list);
  }
}

class _MpRepeat extends StatelessWidget {
  const _MpRepeat({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final resolved = bindings.resolveStringValue(_string(node, 'source'));
    if (resolved is! List || resolved.isEmpty) {
      final empty = node.props['empty'] as _MpNode?;
      return empty == null
          ? const SizedBox.shrink()
          : _MpNodeView(node: empty, bindings: bindings);
    }

    final itemTemplate = node.props['itemTemplate'] as _MpNode;
    final separator = node.props['separator'] as _MpNode?;
    final spacing = _double(node, 'spacing', fallback: 0);
    final limit = _int(node, 'limit', fallback: 100);
    final visibleCount = resolved.length < limit ? resolved.length : limit;
    final horizontal = _string(node, 'direction') == 'horizontal';
    final children = <Widget>[];
    for (var index = 0; index < visibleCount; index += 1) {
      final rowBindings = bindings.copyWith(
        item: _mpItemBinding(resolved[index]),
        index: index,
      );
      children.add(_MpNodeView(node: itemTemplate, bindings: rowBindings));
      if (index < visibleCount - 1) {
        if (separator != null) {
          children.add(_MpNodeView(node: separator, bindings: rowBindings));
        } else if (spacing > 0) {
          children.add(
            horizontal ? SizedBox(width: spacing) : SizedBox(height: spacing),
          );
        }
      }
    }

    if (horizontal) {
      return SizedBox(
        height: _double(node, 'height', fallback: 1),
        child: ListView(
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const ClampingScrollPhysics(),
          children: children,
        ),
      );
    }
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    final height = _optionalDouble(node, 'height');
    return height == null ? column : SizedBox(height: height, child: column);
  }
}

class _MpGrid extends StatelessWidget {
  const _MpGrid({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final columns = _int(node, 'columns', fallback: 2);
    final spacing = _double(node, 'spacing', fallback: 8);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final itemWidth = (maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final child in node.children)
              SizedBox(
                width: itemWidth < 0 ? 0 : itemWidth,
                child: _MpNodeView(node: child, bindings: bindings),
              ),
          ],
        );
      },
    );
  }
}

class _MpWrap extends StatelessWidget {
  const _MpWrap({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _double(node, 'spacing', fallback: 8),
      runSpacing: _double(node, 'runSpacing', fallback: 8),
      children: <Widget>[
        for (final child in node.children)
          _MpNodeView(node: child, bindings: bindings),
      ],
    );
  }
}

Map<String, dynamic> _mpItemBinding(Object? rawItem) {
  if (rawItem is Map) {
    return Map<String, dynamic>.from(rawItem);
  }
  return <String, dynamic>{'value': rawItem};
}
