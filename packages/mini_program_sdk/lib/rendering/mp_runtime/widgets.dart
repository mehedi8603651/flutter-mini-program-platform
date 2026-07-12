part of '../mp_screen_renderer.dart';

class _MpScreenView extends StatelessWidget {
  const _MpScreenView({required this.screen});

  final _MpScreen screen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(
          node: screen.root,
          bindings: _MpRenderBindings(
            scope: MiniProgramSdkScope.maybeOf(context),
            screenId: screen.screenId,
          ),
        ),
      ),
    );
  }
}

enum _MpParentKind { normal, stack }

final RegExp _rtlTextPattern = RegExp(r'[\u0590-\u08FF]');

class _MpThemeData {
  const _MpThemeData({
    this.colors = const <String, String>{},
    this.typography = const <String, _MpTypographyStyle>{},
  });

  final Map<String, String> colors;
  final Map<String, _MpTypographyStyle> typography;

  factory _MpThemeData.fromNode(_MpNode node) {
    final rawColors =
        node.props['colors'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawTypography =
        node.props['typography'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return _MpThemeData(
      colors: <String, String>{
        for (final entry in rawColors.entries) entry.key: entry.value as String,
      },
      typography: <String, _MpTypographyStyle>{
        for (final entry in rawTypography.entries)
          entry.key: _MpTypographyStyle.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  _MpThemeData merge(_MpThemeData child) {
    return _MpThemeData(
      colors: <String, String>{...colors, ...child.colors},
      typography: <String, _MpTypographyStyle>{
        ...typography,
        ...child.typography,
      },
    );
  }
}

class _MpTypographyStyle {
  const _MpTypographyStyle({
    this.size,
    this.weight,
    this.lineHeight,
    this.color,
  });

  factory _MpTypographyStyle.fromMap(Map<String, dynamic> style) {
    return _MpTypographyStyle(
      size: (style['size'] as num?)?.toDouble(),
      weight: style['weight'] as String?,
      lineHeight: (style['lineHeight'] as num?)?.toDouble(),
      color: style['color'] as String?,
    );
  }

  final double? size;
  final String? weight;
  final double? lineHeight;
  final String? color;
}

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

class _MpFieldFrame extends StatelessWidget {
  const _MpFieldFrame({
    required this.label,
    required this.child,
    this.hint,
    this.error,
  });

  final String label;
  final String? hint;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label.isNotEmpty) ...<Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          child,
          if (hint != null && hint!.isNotEmpty && error == null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _fieldDecoration({String? error, bool focused = false}) {
  return BoxDecoration(
    color: const Color(0xFFFFFFFF),
    border: Border.all(
      color: error != null
          ? const Color(0xFFDC2626)
          : focused
          ? const Color(0xFF0B7A75)
          : const Color(0xFFD1D5DB),
    ),
    borderRadius: BorderRadius.circular(8),
  );
}

TextInputType _keyboardType(String? value) {
  return switch (value) {
    'email' => TextInputType.emailAddress,
    'number' => TextInputType.number,
    'phone' => TextInputType.phone,
    'url' => TextInputType.url,
    _ => TextInputType.text,
  };
}

List<Map<String, dynamic>> _options(_MpNode node) {
  return (node.props['options'] as List)
      .whereType<Map>()
      .map((option) => Map<String, dynamic>.from(option))
      .toList(growable: false);
}

Map<String, dynamic>? _optionForValue(_MpNode node, String value) {
  for (final option in _options(node)) {
    if (option['value'] == value) {
      return option;
    }
  }
  return null;
}

class _MpOptionDialog extends StatelessWidget {
  const _MpOptionDialog({
    required this.title,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in options)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(option['value'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        option['label'] as String,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpCheckMark extends StatelessWidget {
  const _MpCheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF0B7A75) : const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _MpRadioMark extends StatelessWidget {
  const _MpRadioMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF0B7A75),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _NoopListenable implements Listenable {
  const _NoopListenable();

  static const instance = _NoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _MpToastView extends StatelessWidget {
  const _MpToastView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _MpDialogView extends StatelessWidget {
  const _MpDialogView({
    required this.message,
    required this.confirmLabel,
    this.title,
  });

  final String? title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MpTapButton(
                    label: confirmLabel,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpNodeView extends StatelessWidget {
  const _MpNodeView({
    required this.node,
    required this.bindings,
    this.parentKind = _MpParentKind.normal,
  });

  final _MpNode node;
  final _MpRenderBindings bindings;
  final _MpParentKind parentKind;

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'column' => _MpColumn(node: node, bindings: bindings),
      'row' => _MpRow(node: node, bindings: bindings),
      'text' || 'heading' => _MpText(node: node, bindings: bindings),
      'sizedBox' => SizedBox(
        width: (node.props['width'] as num?)?.toDouble(),
        height: (node.props['height'] as num?)?.toDouble(),
      ),
      'image' => _MpImage(node: node, bindings: bindings),
      'lazy' => _MpLazySection(node: node, bindings: bindings),
      'lazyChunk' => _MpLazyChunk(node: node, bindings: bindings),
      'initialize' => _MpInitialize(node: node, bindings: bindings),
      'stateScope' => _MpStateScope(node: node, bindings: bindings),
      'skeleton' => _MpSkeleton(node: node, bindings: bindings),
      'card' => _MpCard(node: node, bindings: bindings),
      'theme' => _MpTheme(node: node, bindings: bindings),
      'padding' => Padding(
        padding: _mpInsets(node.props['padding'] as Map<String, dynamic>?),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'align' => Align(
        alignment: _mpAlignment(_string(node, 'alignment')),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'center' => Center(
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'spacer' => const SizedBox.shrink(),
      'expanded' => _MpNodeView(node: node.children.single, bindings: bindings),
      'flexible' => _MpNodeView(node: node.children.single, bindings: bindings),
      'container' => _MpContainer(node: node, bindings: bindings),
      'scrollView' => _MpScrollView(node: node, bindings: bindings),
      'listView' => _MpListView(node: node, bindings: bindings),
      'repeat' => _MpRepeat(node: node, bindings: bindings),
      'safeArea' => SafeArea(
        left: _bool(node, 'left'),
        top: _bool(node, 'top'),
        right: _bool(node, 'right'),
        bottom: _bool(node, 'bottom'),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'visibility' => _MpVisibility(node: node, bindings: bindings),
      'opacity' => Opacity(
        opacity: _double(node, 'opacity', fallback: 1),
        alwaysIncludeSemantics: _bool(node, 'alwaysIncludeSemantics'),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'aspectRatio' => AspectRatio(
        aspectRatio: _double(node, 'aspectRatio', fallback: 1),
        child: _MpNodeView(node: node.children.single, bindings: bindings),
      ),
      'stack' => _MpStack(node: node, bindings: bindings),
      'positioned' =>
        parentKind == _MpParentKind.stack
            ? _MpPositioned(node: node, bindings: bindings)
            : _MpNodeView(node: node.children.single, bindings: bindings),
      'divider' => _MpDivider(node: node, bindings: bindings),
      'icon' => _MpIcon(node: node, bindings: bindings),
      'listTile' => _MpListTile(node: node, bindings: bindings),
      'chip' => _MpChip(node: node, bindings: bindings),
      'badge' => _MpBadge(node: node, bindings: bindings),
      'alert' => _MpAlert(node: node, bindings: bindings),
      'avatar' => _MpAvatar(node: node, bindings: bindings),
      'grid' => _MpGrid(node: node, bindings: bindings),
      'wrap' => _MpWrap(node: node, bindings: bindings),
      'progress' => _MpProgress(node: node, bindings: bindings),
      'emptyState' => _MpEmptyState(node: node, bindings: bindings),
      'section' => _MpSection(node: node, bindings: bindings),
      'primaryButton' => _MpButton(
        node: node,
        primary: true,
        bindings: bindings,
      ),
      'secondaryButton' => _MpButton(
        node: node,
        primary: false,
        bindings: bindings,
      ),
      'button' => _MpButton(node: node, primary: false, bindings: bindings),
      'iconButton' => _MpIconButton(node: node, bindings: bindings),
      'textInput' => _MpTextInputField(node: node, multiline: false),
      'searchInput' => _MpSearchInputField(node: node, bindings: bindings),
      'textArea' => _MpTextInputField(node: node, multiline: true),
      'dropdown' => _MpDropdownField(node: node),
      'checkbox' => _MpCheckboxField(node: node),
      'radioGroup' => _MpRadioGroupField(node: node),
      'form' => _MpForm(node: node, bindings: bindings),
      'formSubmit' => _MpFormSubmitButton(node: node, bindings: bindings),
      'authBuilder' => _MpAuthBuilder(node: node, bindings: bindings),
      'backendBuilder' => _MpBackendBuilder(node: node, bindings: bindings),
      'pagedBackendBuilder' => _MpPagedBackendBuilder(
        node: node,
        bindings: bindings,
      ),
      'stateBuilder' => _MpStateBuilder(node: node, bindings: bindings),
      _ => throw MiniProgramRenderException(
        message: 'Unsupported Mp node type "${node.type}".',
        details: <String, dynamic>{'nodeType': node.type},
      ),
    };
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

class _MpTheme extends StatelessWidget {
  const _MpTheme({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final parentTheme = bindings.theme ?? const _MpThemeData();
    final mergedTheme = parentTheme.merge(_MpThemeData.fromNode(node));
    return _MpNodeView(
      node: node.children.single,
      bindings: bindings.copyWith(theme: mergedTheme),
    );
  }
}
