part of '../../mp_screen_renderer.dart';

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
