part of '../mp_screen_renderer.dart';

class _MpText extends StatelessWidget {
  const _MpText({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final data = bindings.resolveString(_string(node, 'data'));
    final isHeading = node.type == 'heading';
    final defaultColor = isHeading
        ? const Color(0xFF111827)
        : const Color(0xFF263238);
    final defaultHeight = isHeading ? 1.2 : 1.35;
    final explicitProps = Set<String>.from(
      node.props['_explicitTextProps'] as List? ?? const <String>[],
    );
    final variantName = node.props['variant'] as String?;
    final variant = variantName == null
        ? null
        : bindings.theme?.typography[variantName];
    final variantColor = variant?.color;
    final resolvedColor = explicitProps.contains('color')
        ? _mpColor(node.props['color'] as String?, fallback: defaultColor)
        : variantColor == null
        ? defaultColor
        : _mpThemeColor(variantColor, bindings.theme, fallback: defaultColor);
    final resolvedSize = explicitProps.contains('size')
        ? _optionalDouble(node, 'size') ?? _defaultTextSize(node)
        : variant?.size ?? _defaultTextSize(node);
    final resolvedWeight = explicitProps.contains('weight')
        ? _string(node, 'weight')
        : variant?.weight ?? _string(node, 'weight');
    final resolvedHeight = explicitProps.contains('lineHeight')
        ? _optionalDouble(node, 'lineHeight') ?? defaultHeight
        : variant?.lineHeight ?? defaultHeight;
    return Text(
      data,
      maxLines: node.props['maxLines'] as int?,
      overflow: _mpTextOverflow(_string(node, 'overflow')),
      softWrap: _bool(node, 'softWrap'),
      textAlign: _mpTextAlign(_string(node, 'align')),
      textDirection: _mpTextDirection(_string(node, 'textDirection'), data),
      locale: _mpLocale(node.props['locale'] as String?),
      style: TextStyle(
        color: resolvedColor,
        fontSize: resolvedSize,
        fontWeight: _mpFontWeight(resolvedWeight),
        height: resolvedHeight,
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

class _MpSkeleton extends StatelessWidget {
  const _MpSkeleton({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final color = _mpSkeletonColor(
      bindings.theme,
      node.props['colorToken'] as String?,
    );
    return switch (_string(node, 'variant')) {
      'circle' => _block(
        width: _double(node, 'size', fallback: 40),
        height: _double(node, 'size', fallback: 40),
        color: color,
        shape: BoxShape.circle,
      ),
      'text' => _block(
        width: _optionalDouble(node, 'width'),
        height: _double(node, 'height', fallback: 14),
        radius: _double(node, 'radius', fallback: 4),
        color: color,
      ),
      'card' => _block(
        width: _optionalDouble(node, 'width'),
        height: _double(node, 'height', fallback: 160),
        radius: _double(node, 'radius', fallback: 12),
        color: color,
      ),
      'list' => _list(color),
      _ => _block(
        width: _optionalDouble(node, 'width'),
        height: _optionalDouble(node, 'height'),
        radius: _double(node, 'radius', fallback: 8),
        color: color,
      ),
    };
  }

  Widget _list(Color color) {
    final count = _int(node, 'count', fallback: 3);
    final spacing = _double(node, 'spacing', fallback: 12);
    final children = <Widget>[];
    for (var index = 0; index < count; index += 1) {
      if (index > 0 && spacing > 0) {
        children.add(SizedBox(height: spacing));
      }
      children.add(
        _block(
          width: _optionalDouble(node, 'width'),
          height: _double(node, 'itemHeight', fallback: 72),
          radius: _double(node, 'radius', fallback: 8),
          color: color,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static Widget _block({
    required Color color,
    double? width,
    double? height,
    double radius = 0,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(radius),
        ),
      ),
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

class _MpCard extends StatelessWidget {
  const _MpCard({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _mpThemeToken(
          bindings.theme,
          'surface',
          fallback: const Color(0xFFFFFFFF),
        ),
        border: Border.all(
          color: _mpThemeToken(
            bindings.theme,
            'border',
            fallback: const Color(0xFFE5E7EB),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
    );
  }
}

class _MpDivider extends StatelessWidget {
  const _MpDivider({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final spacing = _double(node, 'spacing', fallback: 12);
    final thickness = _double(node, 'thickness', fallback: 1);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing / 2),
      child: SizedBox(
        height: thickness,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: node.props['color'] == null
                ? _mpThemeToken(
                    bindings.theme,
                    'border',
                    fallback: const Color(0xFFE5E7EB),
                  )
                : _mpColor(
                    node.props['color'] as String?,
                    fallback: const Color(0xFFE5E7EB),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MpIcon extends StatelessWidget {
  const _MpIcon({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = node.props['semanticLabel'] as String?;
    return _MpIconGlyph(
      name: _string(node, 'name'),
      size: _double(node, 'size', fallback: 20),
      color: node.props['color'] == null
          ? _mpThemeToken(
              bindings.theme,
              'icon',
              fallback: _mpThemeToken(
                bindings.theme,
                'textMuted',
                fallback: const Color(0xFF4B5563),
              ),
            )
          : _mpColor(
              node.props['color'] as String?,
              fallback: const Color(0xFF4B5563),
            ),
      semanticLabel: semanticLabel == null
          ? null
          : bindings.resolveString(semanticLabel),
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

class _MpChip extends StatelessWidget {
  const _MpChip({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final label = bindings.resolveString(_string(node, 'label'));
    Widget child = _MpChipPill(
      label: label,
      tone: _string(node, 'tone'),
      leadingIcon: node.props['leadingIcon'] as String?,
      theme: bindings.theme,
    );
    final action = node.props['action'] as _MpAction?;
    if (action != null) {
      child = _MpActionTap(
        label: label,
        action: action,
        bindings: bindings,
        child: child,
      );
    }
    return Align(alignment: Alignment.centerLeft, child: child);
  }
}

class _MpBadge extends StatelessWidget {
  const _MpBadge({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _MpBadgePill(
        label: bindings.resolveString(_string(node, 'label')),
        tone: _string(node, 'tone'),
        theme: bindings.theme,
      ),
    );
  }
}

class _MpAlert extends StatelessWidget {
  const _MpAlert({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final tone = _string(node, 'tone');
    final colors = _mpToneStyle(tone, bindings.theme);
    final message = _optionalResolvedString(node, bindings, 'message');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MpIconGlyph(
              name: _string(node, 'icon'),
              size: 20,
              color: colors.foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    bindings.resolveString(_string(node, 'title')),
                    style: _mpThemeTextStyle(
                      bindings.theme,
                      'alertTitle',
                      defaultColor: colors.foreground,
                      defaultSize: 14,
                      defaultWeight: 'bold',
                    ),
                  ),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: _mpThemeTextStyle(
                        bindings.theme,
                        'alertMessage',
                        defaultColor: colors.foreground,
                        defaultSize: 13,
                        defaultWeight: 'regular',
                        defaultHeight: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MpAvatar extends StatelessWidget {
  const _MpAvatar({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final size = _double(node, 'size', fallback: 40);
    final semanticLabel = _optionalResolvedString(
      node,
      bindings,
      'semanticLabel',
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: _avatarChild(size)),
      ),
    );
  }

  Widget _avatarChild(double size) {
    final imageUrl = node.props['imageUrl'] as String?;
    if (imageUrl != null) {
      final resolvedUrl = bindings.resolveString(imageUrl);
      if (!_isRenderableImageUrl(resolvedUrl)) {
        return _avatarFallback(size);
      }
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _avatarFallback(size),
      );
    }
    return _avatarFallback(size);
  }

  Widget _avatarFallback(double size) {
    final initials = node.props['initials'] as String?;
    final icon = node.props['icon'] as String?;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFEFF6FF)),
      child: Center(
        child: initials != null
            ? Text(
                bindings.resolveString(initials),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF1D4ED8),
                  fontSize: size <= 32 ? 12 : 15,
                  fontWeight: FontWeight.w700,
                ),
              )
            : _MpIconGlyph(
                name: icon ?? 'person',
                size: size * 0.55,
                color: const Color(0xFF1D4ED8),
              ),
      ),
    );
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

class _MpProgress extends StatelessWidget {
  const _MpProgress({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final colors = _mpToneStyle(_string(node, 'tone'), bindings.theme);
    final value = _double(node, 'value', fallback: 0);
    final max = _double(node, 'max', fallback: 1);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final label = _optionalResolvedString(node, bindings, 'label');
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.background),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.foreground),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    if (label == null) {
      return bar;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: _mpThemeTextStyle(
            bindings.theme,
            'progressLabel',
            defaultColor: _mpThemeToken(
              bindings.theme,
              'text',
              fallback: const Color(0xFF374151),
            ),
            defaultSize: 13,
            defaultWeight: 'semibold',
          ),
        ),
        const SizedBox(height: 6),
        bar,
      ],
    );
  }
}

class _MpEmptyState extends StatelessWidget {
  const _MpEmptyState({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final action = node.props['action'] as _MpAction?;
    final actionLabel = _optionalResolvedString(node, bindings, 'actionLabel');
    final message = _optionalResolvedString(node, bindings, 'message');
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _MpIconGlyph(
              name: _string(node, 'icon'),
              size: 34,
              color: _mpThemeToken(bindings.theme, 'icon', fallback: textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              bindings.resolveString(_string(node, 'title')),
              textAlign: TextAlign.center,
              style: _mpThemeTextStyle(
                bindings.theme,
                'emptyStateTitle',
                defaultColor: text,
                defaultSize: 16,
                defaultWeight: 'bold',
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: _mpThemeTextStyle(
                  bindings.theme,
                  'emptyStateMessage',
                  defaultColor: textMuted,
                  defaultSize: 14,
                  defaultWeight: 'regular',
                  defaultHeight: 1.35,
                ),
              ),
            ],
            if (action != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: 14),
              _MpTapButton(
                label: actionLabel,
                primary: false,
                theme: bindings.theme,
                onTap: () => unawaited(
                  _MpActionDispatcher.dispatch(context, action, bindings),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MpSection extends StatelessWidget {
  const _MpSection({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final action = node.props['action'] as _MpAction?;
    final actionLabel = _optionalResolvedString(node, bindings, 'actionLabel');
    final subtitle = _optionalResolvedString(node, bindings, 'subtitle');
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
    final primary = _mpThemeToken(
      bindings.theme,
      'primary',
      fallback: const Color(0xFF0B7A75),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    bindings.resolveString(_string(node, 'title')),
                    style: _mpThemeTextStyle(
                      bindings.theme,
                      'sectionTitle',
                      defaultColor: text,
                      defaultSize: 17,
                      defaultWeight: 'bold',
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: _mpThemeTextStyle(
                        bindings.theme,
                        'sectionSubtitle',
                        defaultColor: textMuted,
                        defaultSize: 13,
                        defaultWeight: 'regular',
                        defaultHeight: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null && actionLabel != null) ...<Widget>[
              const SizedBox(width: 12),
              _MpActionTap(
                label: actionLabel,
                action: action,
                bindings: bindings,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    actionLabel,
                    style: _mpThemeTextStyle(
                      bindings.theme,
                      'sectionAction',
                      defaultColor: primary,
                      defaultSize: 13,
                      defaultWeight: 'bold',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _MpNodeView(node: node.children.single, bindings: bindings),
      ],
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

class _MpChipPill extends StatelessWidget {
  const _MpChipPill({
    required this.label,
    required this.tone,
    this.leadingIcon,
    this.theme,
  });

  final String label;
  final String tone;
  final String? leadingIcon;
  final _MpThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final colors = _mpToneStyle(tone, theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leadingIcon != null) ...<Widget>[
              _MpIconGlyph(
                name: leadingIcon!,
                size: 14,
                color: colors.foreground,
              ),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mpTypographyColor(
                    theme,
                    'chip',
                    fallback: colors.foreground,
                  ),
                  fontSize: _mpTypographySize(theme, 'chip', fallback: 13),
                  fontWeight: _mpTypographyWeight(
                    theme,
                    'chip',
                    fallback: 'semibold',
                  ),
                  height: _mpTypographyHeight(theme, 'chip'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MpBadgePill extends StatelessWidget {
  const _MpBadgePill({required this.label, required this.tone, this.theme});

  final String label;
  final String tone;
  final _MpThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final colors = _mpToneStyle(tone, theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _mpTypographyColor(
                theme,
                'badge',
                fallback: colors.foreground,
              ),
              fontSize: _mpTypographySize(theme, 'badge', fallback: 12),
              fontWeight: _mpTypographyWeight(theme, 'badge', fallback: 'bold'),
              height: _mpTypographyHeight(theme, 'badge'),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpIconGlyph extends StatelessWidget {
  const _MpIconGlyph({
    required this.name,
    required this.size,
    required this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _mpIconData(name),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}

class _MpToneColors {
  const _MpToneColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

class _MpButtonColors {
  const _MpButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color disabledBorder;
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

Map<String, dynamic> _mpItemBinding(Object? rawItem) {
  if (rawItem is Map) {
    return Map<String, dynamic>.from(rawItem);
  }
  return <String, dynamic>{'value': rawItem};
}

FlexFit _mpFlexFit(String value) {
  return switch (value) {
    'tight' => FlexFit.tight,
    _ => FlexFit.loose,
  };
}

FontWeight _mpFontWeight(String value) {
  return switch (value) {
    'medium' => FontWeight.w500,
    'semibold' => FontWeight.w600,
    'bold' => FontWeight.w700,
    _ => FontWeight.w400,
  };
}

TextAlign _mpTextAlign(String value) {
  return switch (value) {
    'left' => TextAlign.left,
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'end' => TextAlign.end,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

TextOverflow _mpTextOverflow(String value) {
  return switch (value) {
    'ellipsis' => TextOverflow.ellipsis,
    'fade' => TextOverflow.fade,
    'visible' => TextOverflow.visible,
    _ => TextOverflow.clip,
  };
}

BoxFit _mpBoxFit(String value) {
  return switch (value) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    'fitWidth' => BoxFit.fitWidth,
    'fitHeight' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    _ => BoxFit.cover,
  };
}

TextDirection _mpTextDirection(String value, String data) {
  return switch (value) {
    'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => _rtlTextPattern.hasMatch(data) ? TextDirection.rtl : TextDirection.ltr,
  };
}

Locale? _mpLocale(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.split('-');
  return parts.length == 1
      ? Locale(parts.first)
      : Locale(parts.first, parts[1]);
}

double _defaultTextSize(_MpNode node) {
  if (node.type != 'heading') {
    return 15;
  }
  return switch (_int(node, 'level', fallback: 1)) {
    2 => 22,
    3 => 20,
    4 => 18,
    5 => 16,
    6 => 15,
    _ => 24,
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

Color _mpColor(String? value, {required Color fallback}) {
  if (value == null) {
    return fallback;
  }
  final hex = value.substring(1);
  if (hex.length == 6) {
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }
  return Color(int.parse(hex, radix: 16));
}

Color _mpThemeToken(
  _MpThemeData? theme,
  String token, {
  required Color fallback,
}) {
  return _mpThemeColor(token, theme, fallback: fallback);
}

Color _mpThemeColor(
  String value,
  _MpThemeData? theme, {
  required Color fallback,
}) {
  if (value.startsWith('#')) {
    return _mpColor(value, fallback: fallback);
  }
  final tokenColor = theme?.colors[value];
  if (tokenColor == null) {
    return fallback;
  }
  return _mpColor(tokenColor, fallback: fallback);
}

Color _mpSkeletonColor(_MpThemeData? theme, String? colorToken) {
  const fallback = Color(0xFFE5E7EB);
  if (colorToken != null) {
    final explicitColor = theme?.colors[colorToken];
    if (explicitColor != null) {
      return _mpColor(explicitColor, fallback: fallback);
    }
  }
  return _mpThemeToken(theme, 'skeleton', fallback: fallback);
}

TextStyle _mpThemeTextStyle(
  _MpThemeData? theme,
  String variant, {
  required Color defaultColor,
  required double defaultSize,
  required String defaultWeight,
  double? defaultHeight,
}) {
  return TextStyle(
    color: _mpTypographyColor(theme, variant, fallback: defaultColor),
    fontSize: _mpTypographySize(theme, variant, fallback: defaultSize),
    fontWeight: _mpTypographyWeight(theme, variant, fallback: defaultWeight),
    height: _mpTypographyHeight(theme, variant) ?? defaultHeight,
  );
}

Color _mpTypographyColor(
  _MpThemeData? theme,
  String variant, {
  required Color fallback,
}) {
  final color = theme?.typography[variant]?.color;
  return color == null
      ? fallback
      : _mpThemeColor(color, theme, fallback: fallback);
}

double _mpTypographySize(
  _MpThemeData? theme,
  String variant, {
  required double fallback,
}) {
  return theme?.typography[variant]?.size ?? fallback;
}

FontWeight _mpTypographyWeight(
  _MpThemeData? theme,
  String variant, {
  required String fallback,
}) {
  return _mpFontWeight(theme?.typography[variant]?.weight ?? fallback);
}

double? _mpTypographyHeight(_MpThemeData? theme, String variant) {
  return theme?.typography[variant]?.lineHeight;
}

_MpButtonColors _mpButtonColors({
  required bool primary,
  required bool enabled,
  required bool hoveredOrFocused,
  required bool pressed,
  required _MpThemeData? theme,
}) {
  final primaryColor = _mpThemeToken(
    theme,
    'primary',
    fallback: const Color(0xFF0B7A75),
  );
  final onPrimary = _mpThemeToken(
    theme,
    'onPrimary',
    fallback: const Color(0xFFFFFFFF),
  );
  final surface = _mpThemeToken(
    theme,
    'surface',
    fallback: const Color(0xFFFFFFFF),
  );
  final surfaceMuted = _mpThemeToken(
    theme,
    'surfaceMuted',
    fallback: const Color(0xFFE5E7EB),
  );
  final border = _mpThemeToken(
    theme,
    'border',
    fallback: const Color(0xFFD1D5DB),
  );
  final textMuted = _mpThemeToken(
    theme,
    'textMuted',
    fallback: const Color(0xFF6B7280),
  );
  if (!enabled) {
    return _MpButtonColors(
      background: surfaceMuted,
      foreground: textMuted,
      border: border,
      disabledBackground: surfaceMuted,
      disabledForeground: textMuted,
      disabledBorder: border,
    );
  }
  if (!primary) {
    final background = hoveredOrFocused || pressed
        ? _mpThemeToken(theme, 'surfaceMuted', fallback: surface)
        : surface;
    return _MpButtonColors(
      background: background,
      foreground: primaryColor,
      border: primaryColor,
      disabledBackground: surfaceMuted,
      disabledForeground: textMuted,
      disabledBorder: border,
    );
  }

  final background = pressed
      ? _mpThemeToken(
          theme,
          'primaryPressed',
          fallback: const Color(0xFF065F56),
        )
      : hoveredOrFocused
      ? _mpThemeToken(theme, 'primaryHover', fallback: const Color(0xFF0F766E))
      : primaryColor;
  return _MpButtonColors(
    background: background,
    foreground: onPrimary,
    border: primaryColor,
    disabledBackground: surfaceMuted,
    disabledForeground: textMuted,
    disabledBorder: border,
  );
}

bool _isRenderableImageUrl(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    return false;
  }
  return uri.scheme == 'https' ||
      (uri.scheme == 'http' && _isLocalPreviewHost(uri.host));
}

bool _isHttpImageSrc(String src) {
  final uri = Uri.tryParse(src);
  return uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

bool _isDataUriBase64Image(String src) {
  return RegExp(
    r'^data:image\/[-+.\w]+;base64,',
    caseSensitive: false,
  ).hasMatch(src.trim());
}

bool _isAssetLikeImageSrc(String src) {
  final normalized = src.trim().toLowerCase();
  if (normalized.startsWith('assets/') ||
      normalized.startsWith('asset/') ||
      normalized.startsWith('images/') ||
      normalized.startsWith('packages/')) {
    return true;
  }
  return normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.gif') ||
      normalized.endsWith('.webp') ||
      normalized.endsWith('.bmp') ||
      normalized.endsWith('.avif');
}

_MpToneColors _mpToneStyle(String tone, [_MpThemeData? theme]) {
  final defaults = switch (tone) {
    'info' => const _MpToneColors(
      background: Color(0xFFEFF6FF),
      foreground: Color(0xFF1D4ED8),
      border: Color(0xFFBFDBFE),
    ),
    'success' => const _MpToneColors(
      background: Color(0xFFECFDF5),
      foreground: Color(0xFF047857),
      border: Color(0xFFA7F3D0),
    ),
    'warning' => const _MpToneColors(
      background: Color(0xFFFFFBEB),
      foreground: Color(0xFFB45309),
      border: Color(0xFFFDE68A),
    ),
    'danger' => const _MpToneColors(
      background: Color(0xFFFEF2F2),
      foreground: Color(0xFFB91C1C),
      border: Color(0xFFFECACA),
    ),
    _ => const _MpToneColors(
      background: Color(0xFFF3F4F6),
      foreground: Color(0xFF374151),
      border: Color(0xFFE5E7EB),
    ),
  };
  return _MpToneColors(
    background: _mpThemeToken(
      theme,
      '${tone}Bg',
      fallback: defaults.background,
    ),
    foreground: _mpThemeToken(theme, tone, fallback: defaults.foreground),
    border: _mpThemeToken(theme, '${tone}Border', fallback: defaults.border),
  );
}

IconData _mpIconData(String name) {
  final icon = _mpIcons[name];
  if (icon == null) {
    throw MiniProgramRenderException(
      message: 'Unsupported Mp icon "$name".',
      details: <String, dynamic>{'iconName': name},
    );
  }
  return icon;
}

String? _optionalResolvedString(
  _MpNode node,
  _MpRenderBindings bindings,
  String key,
) {
  final value = node.props[key] as String?;
  return value == null ? null : bindings.resolveString(value);
}

double _double(_MpNode node, String key, {required double fallback}) {
  return (node.props[key] as num?)?.toDouble() ?? fallback;
}

double? _optionalDouble(_MpNode node, String key) {
  return (node.props[key] as num?)?.toDouble();
}

double _mapDouble(Map<String, dynamic>? map, String key) {
  return (map?[key] as num?)?.toDouble() ?? 0;
}

const Map<String, IconData> _mpIcons = <String, IconData>{
  'person': IconData(0xe491, fontFamily: 'MaterialIcons'),
  'settings': IconData(0xe57f, fontFamily: 'MaterialIcons'),
  'chevronRight': IconData(
    0xe15f,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'star': IconData(0xe5f9, fontFamily: 'MaterialIcons'),
  'gift': IconData(0xe13e, fontFamily: 'MaterialIcons'),
  'check': IconData(0xe156, fontFamily: 'MaterialIcons'),
  'warning': IconData(0xe6cb, fontFamily: 'MaterialIcons'),
  'info': IconData(0xe33d, fontFamily: 'MaterialIcons'),
  'lock': IconData(0xe3b1, fontFamily: 'MaterialIcons'),
  'mail': IconData(0xe3c4, fontFamily: 'MaterialIcons'),
  'home': IconData(0xf107, fontFamily: 'MaterialIcons'),
  'search': IconData(0xe567, fontFamily: 'MaterialIcons'),
  'history': IconData(0xe314, fontFamily: 'MaterialIcons'),
  'backspace': IconData(
    0xe0c5,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'arrowBack': IconData(
    0xe092,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'brain': IconData(0xf08b1, fontFamily: 'MaterialIcons'),
  'trophy': IconData(0xf01a, fontFamily: 'MaterialIcons'),
  'timer': IconData(0xf44a, fontFamily: 'MaterialIcons'),
  'close': IconData(0xf647, fontFamily: 'MaterialIcons'),
  'refresh': IconData(0xf00e9, fontFamily: 'MaterialIcons'),
  'bolt': IconData(0xf5ca, fontFamily: 'MaterialIcons'),
  'location': IconData(0xf193, fontFamily: 'MaterialIcons'),
  'menu': IconData(0xf8b6, fontFamily: 'MaterialIcons'),
  'sunny': IconData(0xf4bc, fontFamily: 'MaterialIcons'),
  'cloudy': IconData(0xef62, fontFamily: 'MaterialIcons'),
  'rain': IconData(0xf46d, fontFamily: 'MaterialIcons'),
  'thunderstorm': IconData(0xf071b, fontFamily: 'MaterialIcons'),
  'waterDrop': IconData(0xf0695, fontFamily: 'MaterialIcons'),
  'wind': IconData(0xf542, fontFamily: 'MaterialIcons'),
  'thermometer': IconData(0xf022c, fontFamily: 'MaterialIcons'),
  'snow': IconData(0xe037, fontFamily: 'MaterialIcons'),
  'fog': IconData(0xf0505, fontFamily: 'MaterialIcons'),
  'public': IconData(0xe4f0, fontFamily: 'MaterialIcons'),
};
