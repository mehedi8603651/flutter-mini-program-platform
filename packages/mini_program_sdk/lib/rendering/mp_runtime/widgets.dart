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
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: true,
        bindings: bindings,
      ),
      'secondaryButton' => _MpButton(
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: false,
        bindings: bindings,
      ),
      'textInput' => _MpTextInputField(node: node, multiline: false),
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

enum _MpLazyStatus { idle, loading, success, error }

class _MpLazySection extends StatefulWidget {
  const _MpLazySection({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpLazySection> createState() => _MpLazySectionState();
}

class _MpLazySectionState extends State<_MpLazySection> {
  _MpLazyStatus _status = _MpLazyStatus.idle;
  bool _started = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpLazySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_runtimeKey(widget) != _runtimeKey(oldWidget)) {
      _generation += 1;
      _started = false;
      _status = _MpLazyStatus.idle;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_started) {
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }

    if (_bool(widget.node, 'once') &&
        _mpLazyOnceKeys.contains(_onceKey(scope))) {
      _status = _MpLazyStatus.success;
      _writeStatus(scope, 'success');
      return;
    }

    _started = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      unawaited(_run(activeScope, generation));
    });
  }

  Future<void> _run(MiniProgramSdkScope scope, int generation) async {
    final cacheKey = widget.node.props['cacheKey'] as String?;
    final targetState = widget.node.props['targetState'] as String?;
    final state = scope.stateManager;
    _writeStatus(scope, 'loading');

    if (cacheKey != null) {
      if (state == null) {
        _finishError(scope, generation);
        return;
      }
      final cache = scope.cacheManager.forApp(
        scope.miniProgramId,
        policy: scope.cachePolicy,
      );
      final bucket = _lazyCacheBucket(widget.node);
      final found = await cache.has(cacheKey, bucket: bucket);
      if (!mounted || generation != _generation) {
        return;
      }
      if (found) {
        final cachedValue = await cache.get<Object?>(cacheKey, bucket: bucket);
        if (!mounted || generation != _generation) {
          return;
        }
        state.set(targetState!, cachedValue);
        _writeStatus(scope, 'success');
        _finishSuccess(scope, generation);
        if (!_bool(widget.node, 'refreshIfCached')) {
          return;
        }
        await _runActionsAndMaybeCache(
          scope,
          generation,
          preserveCachedContent: true,
        );
        return;
      }
    }

    if ((widget.node.props['actions'] as List<_MpAction>).isEmpty) {
      _writeStatus(scope, 'success');
      await _saveTargetStateToCache(scope, generation);
      _finishSuccess(scope, generation);
      return;
    }

    _setStatus(_MpLazyStatus.loading, generation);
    await _runActionsAndMaybeCache(
      scope,
      generation,
      preserveCachedContent: false,
    );
  }

  Future<void> _runActionsAndMaybeCache(
    MiniProgramSdkScope scope,
    int generation, {
    required bool preserveCachedContent,
  }) async {
    final retry = _int(widget.node, 'retry', fallback: 0);
    final retryDelay = Duration(
      milliseconds: _int(widget.node, 'retryDelayMs', fallback: 300),
    );

    _MpLazyActionOutcome outcome = const _MpLazyActionOutcome.failure();
    for (var attempt = 0; attempt <= retry; attempt += 1) {
      outcome = await _runActions(scope);
      if (!mounted || generation != _generation) {
        return;
      }
      if (outcome.success) {
        break;
      }
      if (attempt < retry && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
        if (!mounted || generation != _generation) {
          return;
        }
      }
    }

    if (!outcome.success) {
      if (!preserveCachedContent) {
        _writeStatus(scope, 'error');
        _finishError(scope, generation);
      }
      return;
    }

    final targetState = widget.node.props['targetState'] as String?;
    if (targetState != null && outcome.hasData) {
      final state = scope.stateManager;
      if (state == null) {
        if (!preserveCachedContent) {
          _finishError(scope, generation);
        }
        return;
      }
      state.set(targetState, outcome.data);
    }
    await _saveTargetStateToCache(scope, generation);
    _writeStatus(scope, 'success');
    _finishSuccess(scope, generation);
  }

  Future<_MpLazyActionOutcome> _runActions(MiniProgramSdkScope scope) async {
    final actions = widget.node.props['actions'] as List<_MpAction>;
    if (actions.isEmpty) {
      return const _MpLazyActionOutcome.success(hasData: false);
    }

    Object? lastResult;
    for (final action in actions) {
      lastResult = await _MpActionDispatcher.dispatch(
        context,
        action,
        widget.bindings.copyWith(scope: scope),
      );
      if (_lazyActionFailed(lastResult)) {
        return _MpLazyActionOutcome.failure(lastResult);
      }
    }
    return _MpLazyActionOutcome.success(
      data: _lazyResultData(lastResult),
      hasData: true,
    );
  }

  Future<void> _saveTargetStateToCache(
    MiniProgramSdkScope scope,
    int generation,
  ) async {
    final cacheKey = widget.node.props['cacheKey'] as String?;
    final targetState = widget.node.props['targetState'] as String?;
    if (cacheKey == null || targetState == null) {
      return;
    }
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final value = state.get<Object?>(targetState);
    await scope.cacheManager
        .forApp(scope.miniProgramId, policy: scope.cachePolicy)
        .set(
          cacheKey,
          value,
          bucket: _lazyCacheBucket(widget.node),
          ttl: _lazyTtl(widget.node),
        );
    if (!mounted || generation != _generation) {
      return;
    }
  }

  void _finishSuccess(MiniProgramSdkScope scope, int generation) {
    if (_bool(widget.node, 'once')) {
      _mpLazyOnceKeys.add(_onceKey(scope));
    }
    _setStatus(_MpLazyStatus.success, generation);
  }

  void _finishError(MiniProgramSdkScope scope, int generation) {
    _setStatus(_MpLazyStatus.error, generation);
  }

  void _setStatus(_MpLazyStatus status, int generation) {
    if (!mounted || generation != _generation || _status == status) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  void _writeStatus(MiniProgramSdkScope scope, String value) {
    final statusState = widget.node.props['statusState'] as String?;
    if (statusState == null) {
      return;
    }
    scope.stateManager?.set(statusState, value);
  }

  String _onceKey(MiniProgramSdkScope scope) {
    return '${scope.miniProgramId}/${widget.bindings.screenId ?? 'unknown'}/'
        '${_string(widget.node, 'id')}';
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return switch (_status) {
      _MpLazyStatus.idle =>
        widget.node.props.containsKey('cacheKey')
            ? const SizedBox.shrink()
            : _renderTemplate(scope, 'placeholder') ?? const SizedBox.shrink(),
      _MpLazyStatus.loading =>
        _renderTemplate(scope, 'placeholder') ?? const SizedBox.shrink(),
      _MpLazyStatus.success => _MpNodeView(
        node: widget.node.children.single,
        bindings: widget.bindings.copyWith(scope: scope),
      ),
      _MpLazyStatus.error =>
        _renderTemplate(scope, 'error') ?? const Text('Failed to load'),
    };
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, String propName) {
    final template = widget.node.props[propName] as _MpNode?;
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: widget.bindings.copyWith(scope: scope),
    );
  }
}

class _MpLazyActionOutcome {
  const _MpLazyActionOutcome.success({this.data, this.hasData = true})
    : success = true;

  const _MpLazyActionOutcome.failure([this.data])
    : success = false,
      hasData = false;

  final bool success;
  final Object? data;
  final bool hasData;
}

final Set<String> _mpLazyOnceKeys = <String>{};

String _runtimeKey(_MpLazySection widget) {
  final node = widget.node;
  final actions =
      node.props['actions'] as List<_MpAction>? ?? const <_MpAction>[];
  return <String>[
    widget.bindings.screenId ?? '',
    _string(node, 'id'),
    (node.props['cacheKey'] as String?) ?? '',
    _string(node, 'bucket'),
    (node.props['targetState'] as String?) ?? '',
    (node.props['statusState'] as String?) ?? '',
    _bool(node, 'once').toString(),
    _bool(node, 'refreshIfCached').toString(),
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    (node.props['ttlMs'] as int?)?.toString() ?? '',
    for (final action in actions) _lazyActionKey(action),
  ].join('|');
}

String _lazyActionKey(_MpAction action) {
  final keys = action.props.keys.toList(growable: false)..sort();
  final propsKey = keys
      .map((key) => '$key=${_lazyStableValueKey(action.props[key])}')
      .join(',');
  return '${action.type}:$propsKey';
}

String _lazyStableValueKey(Object? value) {
  if (value is _MpAction) {
    return _lazyActionKey(value);
  }
  if (value is _MpNode) {
    return 'node:${value.type}';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '$key=${_lazyStableValueKey(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_lazyStableValueKey).join(',')}]';
  }
  return value.toString();
}

MiniProgramCacheBucket _lazyCacheBucket(_MpNode node) {
  return switch (_string(node, 'bucket')) {
    'memory' => MiniProgramCacheBucket.memory,
    'data' => MiniProgramCacheBucket.data,
    'image' => MiniProgramCacheBucket.image,
    'state' => MiniProgramCacheBucket.state,
    _ => MiniProgramCacheBucket.data,
  };
}

Duration? _lazyTtl(_MpNode node) {
  final ttlMs = node.props['ttlMs'] as int?;
  return ttlMs == null ? null : Duration(milliseconds: ttlMs);
}

bool _lazyActionFailed(Object? result) {
  if (result is HostActionResult) {
    return !result.isSuccess;
  }
  if (result is MiniProgramBackendResult) {
    return !result.isSuccess;
  }
  if (result is Map) {
    final status = result['status'];
    if (status == 'failed' || status == 'failure') {
      return true;
    }
    if (result['success'] == false) {
      return true;
    }
  }
  return false;
}

Object? _lazyResultData(Object? result) {
  if (result is MiniProgramBackendResult) {
    return result.data;
  }
  if (result is HostActionResult) {
    return result.data;
  }
  if (result is Map) {
    if (result.containsKey('data')) {
      return result['data'];
    }
    return Map<String, dynamic>.from(result);
  }
  return result;
}

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
    return ClipRect(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          primary: false,
          padding: _mpInsets(node.props['padding'] as Map<String, dynamic>?),
          child: _MpNodeView(node: node.children.single, bindings: bindings),
        ),
      ),
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
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: _mpInsets(node.props['padding'] as Map<String, dynamic>?),
      itemCount: node.children.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) =>
          _MpNodeView(node: node.children[index], bindings: bindings),
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
      (uri.scheme == 'http' && MpScreenValidator._isLocalPreviewHost(uri.host));
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
  final codePoint = _mpIconCodePoints[name];
  if (codePoint == null) {
    throw MiniProgramRenderException(
      message: 'Unsupported Mp icon "$name".',
      details: <String, dynamic>{'iconName': name},
    );
  }
  return IconData(
    codePoint,
    fontFamily: 'MaterialIcons',
    matchTextDirection: name == 'chevronRight',
  );
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

const Map<String, int> _mpIconCodePoints = <String, int>{
  'person': 0xe491,
  'settings': 0xe57f,
  'chevronRight': 0xe15f,
  'star': 0xe5f9,
  'gift': 0xe13e,
  'check': 0xe156,
  'warning': 0xe6cb,
  'info': 0xe33d,
  'lock': 0xe3b1,
  'mail': 0xe3c4,
  'home': 0xf107,
  'search': 0xe567,
};

class _MpStateBuilder extends StatelessWidget {
  const _MpStateBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final state = scope?.stateManager;
    final child = node.props['child'] as _MpNode;
    if (state == null) {
      return _MpNodeView(node: child, bindings: bindings);
    }
    final keys = List<String>.from(node.props['keys'] as List);
    final listenable = Listenable.merge(
      keys.map(state.watch).toList(growable: false),
    );
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) => _MpNodeView(node: child, bindings: bindings),
    );
  }
}

class _MpForm extends StatefulWidget {
  const _MpForm({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpForm> createState() => _MpFormState();
}

class _MpFormState extends State<_MpForm> {
  late _MpFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _MpFormController(id: _string(widget.node, 'id'));
  }

  @override
  void didUpdateWidget(covariant _MpForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'id') != _string(widget.node, 'id')) {
      _controller.dispose();
      _controller = _MpFormController(id: _string(widget.node, 'id'));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MpFormScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final bindings = widget.bindings.copyWith(
            form: _controller.toBindingData(),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final child in widget.node.children)
                _MpNodeView(node: child, bindings: bindings),
            ],
          );
        },
      ),
    );
  }
}

class _MpTextInputField extends StatefulWidget {
  const _MpTextInputField({required this.node, required this.multiline});

  final _MpNode node;
  final bool multiline;

  @override
  State<_MpTextInputField> createState() => _MpTextInputFieldState();
}

class _MpTextInputFieldState extends State<_MpTextInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  _MpFormController? _form;

  String get _name => _string(widget.node, 'name');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.node.props['initialValue'] as String? ?? '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindForm();
  }

  @override
  void didUpdateWidget(covariant _MpTextInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'name') != _name) {
      _form?.unregisterField(_string(oldWidget.node, 'name'));
      _bindForm(force: true);
    }
  }

  void _bindForm({bool force = false}) {
    final form = _MpFormScope.maybeOf(context);
    if (!force && identical(form, _form)) {
      return;
    }
    _form?.removeListener(_onFormChanged);
    _form = form;
    form?.registerField(
      name: _name,
      initialValue: _controller.text,
      validator: (value) => _requiredTextValidator(
        value,
        required: _bool(widget.node, 'required'),
        minLength: widget.node.props['minLength'] as int?,
        maxLength: widget.node.props['maxLength'] as int?,
      ),
    );
    final formValue = form?.value(_name);
    if (formValue is String && formValue != _controller.text) {
      _controller.text = formValue;
    }
    form?.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _form?.unregisterField(_name);
    _form?.removeListener(_onFormChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _form?.error(_name);
    return _MpFieldFrame(
      label: _string(widget.node, 'label'),
      hint: widget.node.props['hint'] as String?,
      error: error,
      child: DecoratedBox(
        decoration: _fieldDecoration(
          error: error,
          focused: _focusNode.hasFocus,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: EditableText(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: _keyboardType(
              widget.node.props['keyboardType'] as String?,
            ),
            obscureText: widget.node.props['obscureText'] == true,
            minLines: widget.multiline
                ? widget.node.props['minLines'] as int? ?? 3
                : 1,
            maxLines: widget.multiline
                ? widget.node.props['maxLines'] as int? ?? 6
                : 1,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              height: 1.35,
            ),
            cursorColor: const Color(0xFF0B7A75),
            backgroundCursorColor: const Color(0xFFE5E7EB),
            onChanged: (value) => _form?.setValue(_name, value),
          ),
        ),
      ),
    );
  }
}

class _MpDropdownField extends StatefulWidget {
  const _MpDropdownField({required this.node});

  final _MpNode node;

  @override
  State<_MpDropdownField> createState() => _MpDropdownFieldState();
}

class _MpDropdownFieldState extends State<_MpDropdownField> {
  _MpFormController? _form;

  String get _name => _string(widget.node, 'name');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindForm();
  }

  @override
  void didUpdateWidget(covariant _MpDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'name') != _name) {
      _form?.unregisterField(_string(oldWidget.node, 'name'));
      _bindForm(force: true);
    }
  }

  void _bindForm({bool force = false}) {
    final form = _MpFormScope.maybeOf(context);
    if (!force && identical(form, _form)) {
      return;
    }
    _form?.removeListener(_onFormChanged);
    _form = form;
    form?.registerField(
      name: _name,
      initialValue: widget.node.props['initialValue'] as String? ?? '',
      validator: (value) => _requiredChoiceValidator(
        value,
        required: _bool(widget.node, 'required'),
      ),
    );
    form?.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _form?.unregisterField(_name);
    _form?.removeListener(_onFormChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _form?.error(_name);
    final value = _form?.value(_name)?.toString() ?? '';
    final selected = _optionForValue(widget.node, value);
    final label =
        selected?['label'] as String? ??
        widget.node.props['hint'] as String? ??
        'Choose';
    return _MpFieldFrame(
      label: _string(widget.node, 'label'),
      hint: widget.node.props['hint'] as String?,
      error: error,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_chooseOption(context)),
        child: DecoratedBox(
          decoration: _fieldDecoration(error: error),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected == null
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF111827),
                      fontSize: 15,
                    ),
                  ),
                ),
                const Text(
                  'v',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseOption(BuildContext context) async {
    final options = _options(widget.node);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Choose option',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) => _MpOptionDialog(
        title: _string(widget.node, 'label'),
        options: options,
        onSelected: (value) {
          _form?.setValue(_name, value);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _MpCheckboxField extends StatefulWidget {
  const _MpCheckboxField({required this.node});

  final _MpNode node;

  @override
  State<_MpCheckboxField> createState() => _MpCheckboxFieldState();
}

class _MpCheckboxFieldState extends State<_MpCheckboxField> {
  _MpFormController? _form;

  String get _name => _string(widget.node, 'name');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindForm();
  }

  void _bindForm() {
    final form = _MpFormScope.maybeOf(context);
    if (identical(form, _form)) {
      return;
    }
    _form?.removeListener(_onFormChanged);
    _form = form;
    form?.registerField(
      name: _name,
      initialValue: widget.node.props['initialValue'] == true,
      validator: (value) => _requiredTrueValidator(
        value,
        requiredTrue: _bool(widget.node, 'requiredTrue'),
      ),
    );
    form?.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _form?.unregisterField(_name);
    _form?.removeListener(_onFormChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _form?.value(_name) == true;
    final error = _form?.error(_name);
    return _MpFieldFrame(
      label: '',
      error: error,
      child: Semantics(
        checked: value,
        button: true,
        label: _string(widget.node, 'label'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _form?.setValue(_name, !value),
          child: Row(
            children: <Widget>[
              _MpCheckMark(checked: value),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _string(widget.node, 'label'),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MpRadioGroupField extends StatefulWidget {
  const _MpRadioGroupField({required this.node});

  final _MpNode node;

  @override
  State<_MpRadioGroupField> createState() => _MpRadioGroupFieldState();
}

class _MpRadioGroupFieldState extends State<_MpRadioGroupField> {
  _MpFormController? _form;

  String get _name => _string(widget.node, 'name');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindForm();
  }

  void _bindForm() {
    final form = _MpFormScope.maybeOf(context);
    if (identical(form, _form)) {
      return;
    }
    _form?.removeListener(_onFormChanged);
    _form = form;
    form?.registerField(
      name: _name,
      initialValue: widget.node.props['initialValue'] as String? ?? '',
      validator: (value) => _requiredChoiceValidator(
        value,
        required: _bool(widget.node, 'required'),
      ),
    );
    form?.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _form?.unregisterField(_name);
    _form?.removeListener(_onFormChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = _form?.value(_name)?.toString() ?? '';
    return _MpFieldFrame(
      label: _string(widget.node, 'label'),
      error: _form?.error(_name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final option in _options(widget.node))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _form?.setValue(_name, option['value']),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    _MpRadioMark(checked: selectedValue == option['value']),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option['label'] as String,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MpFormSubmitButton extends StatefulWidget {
  const _MpFormSubmitButton({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpFormSubmitButton> createState() => _MpFormSubmitButtonState();
}

class _MpFormSubmitButtonState extends State<_MpFormSubmitButton> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final form = _MpFormScope.maybeOf(context);
    return AnimatedBuilder(
      animation: form ?? _NoopListenable.instance,
      builder: (context, _) {
        final submitting = form?.submitting == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _MpTapButton(
              label: submitting
                  ? 'Submitting...'
                  : widget.bindings.resolveString(
                      widget.node.props['label'] as String,
                    ),
              primary: true,
              enabled: form != null && !submitting,
              theme: widget.bindings.theme,
              onTap: form == null ? null : () => unawaited(_submit(form)),
            ),
            if (_message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _message!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _submit(_MpFormController form) async {
    if (form.submitting) {
      return;
    }
    if (!form.validate()) {
      setState(() => _message = 'Check the highlighted fields.');
      return;
    }
    form.setSubmitting(true);
    setState(() => _message = null);
    final formBindings = widget.bindings.copyWith(form: form.toBindingData());
    final rawBody =
        widget.node.props['body'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final body = rawBody.isEmpty
        ? form.values
        : formBindings.resolveMap(rawBody);
    final action = _MpAction(
      type: 'form.submit',
      props: <String, dynamic>{
        'endpoint': widget.node.props['endpoint'],
        if (widget.node.props['requestId'] != null)
          'requestId': widget.node.props['requestId'],
        'method': widget.node.props['method'],
        'body': body,
        if (widget.node.props['cacheTtlSeconds'] != null)
          'cacheTtlSeconds': widget.node.props['cacheTtlSeconds'],
      },
    );
    final result = await _MpActionDispatcher.dispatch(
      context,
      action,
      formBindings,
    );
    if (!mounted) {
      form.setSubmitting(false);
      return;
    }
    form.setSubmitting(false);
    final success = result is MiniProgramBackendResult && result.isSuccess;
    final nextAction = success
        ? widget.node.props['onSuccess'] as _MpAction?
        : widget.node.props['onError'] as _MpAction?;
    if (nextAction != null) {
      await _MpActionDispatcher.dispatch(context, nextAction, formBindings);
    }
    if (!success) {
      final message = result is MiniProgramBackendResult
          ? result.message ?? 'Form submission failed.'
          : 'Form submission failed.';
      setState(() => _message = message);
    }
  }
}

class _MpImage extends StatelessWidget {
  const _MpImage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final src = bindings.resolveString(node.props['src'] as String);
    final source = _resolvedImageSource(src);
    Widget image;
    switch (source) {
      case 'network':
        if (!_isHttpImageSrc(src)) {
          image = _imageErrorFallback(context);
          break;
        }
        image = Image.network(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          headers: _resolvedHeaders(),
          semanticLabel: _semanticLabel,
        );
        break;
      case 'asset':
        image = Image.asset(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          semanticLabel: _semanticLabel,
        );
        break;
      case 'base64':
        try {
          image = Image.memory(
            base64Decode(
              MpScreenValidator._paddedBase64(
                MpScreenValidator._base64ImagePayload(src),
              ),
            ),
            errorBuilder: (context, error, stackTrace) =>
                _imageErrorFallback(context),
            fit: _mpBoxFit(_string(node, 'fit')),
            frameBuilder: _imageFrameBuilder,
            semanticLabel: _semanticLabel,
          );
        } on FormatException {
          image = _imageErrorFallback(context);
        }
        break;
      default:
        image = _imageErrorFallback(context);
        break;
    }

    final width = _optionalDouble(node, 'width');
    final height = _optionalDouble(node, 'height');
    if (width == null && height == null) {
      return image;
    }
    return SizedBox(width: width, height: height, child: image);
  }

  String? get _semanticLabel {
    final label = node.props['semanticLabel'] ?? node.props['alt'];
    return label == null ? null : bindings.resolveString(label as String);
  }

  String _resolvedImageSource(String src) {
    final configured = _string(node, 'source');
    if (configured != 'auto') {
      return configured;
    }
    if (_isHttpImageSrc(src)) {
      return 'network';
    }
    if (_isDataUriBase64Image(src)) {
      return 'base64';
    }
    if (_isAssetLikeImageSrc(src)) {
      return 'asset';
    }
    try {
      base64Decode(
        MpScreenValidator._paddedBase64(
          MpScreenValidator._base64ImagePayload(src),
        ),
      );
      return 'base64';
    } on FormatException {
      return 'asset';
    }
  }

  Map<String, String>? _resolvedHeaders() {
    final headers = node.props['headers'] as Map<String, dynamic>?;
    if (headers == null || headers.isEmpty) {
      return null;
    }
    return <String, String>{
      for (final entry in headers.entries)
        entry.key: bindings.resolveString(entry.value as String),
    };
  }

  Widget _imageFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      return _fadeIn(child, wasSynchronouslyLoaded: wasSynchronouslyLoaded);
    }
    return _imageLoadingFallback(context);
  }

  Widget _fadeIn(Widget child, {required bool wasSynchronouslyLoaded}) {
    final durationMs = _int(node, 'fadeInDurationMs', fallback: 200);
    if (wasSynchronouslyLoaded || durationMs <= 0) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }

  Widget _imageLoadingFallback(BuildContext context) {
    final placeholder = node.props['placeholder'] as _MpNode?;
    if (placeholder == null) {
      return const SizedBox.shrink();
    }
    return _MpNodeView(node: placeholder, bindings: bindings);
  }

  Widget _imageErrorFallback(BuildContext context) {
    final error = node.props['error'] as _MpNode?;
    if (error != null) {
      return _MpNodeView(node: error, bindings: bindings);
    }
    final label = _semanticLabel;
    if (label != null && label.isNotEmpty) {
      return Text(label);
    }
    return const Text('Image unavailable');
  }
}

class _MpButton extends StatefulWidget {
  const _MpButton({
    required this.label,
    required this.action,
    required this.primary,
    required this.bindings,
  });

  final String label;
  final _MpAction action;
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
    final colors = _mpButtonColors(
      primary: widget.primary,
      enabled: true,
      hoveredOrFocused: _hovered || _focused,
      pressed: _pressed,
      theme: widget.bindings.theme,
    );

    return Semantics(
      button: true,
      label: widget.label,
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
              widget.action,
              widget.bindings,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: _mpThemeTextStyle(
                    widget.bindings.theme,
                    'button',
                    defaultColor: colors.foreground,
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

class _MpAuthBuilder extends StatelessWidget {
  const _MpAuthBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final controller = scope?.authController;
    if (scope == null || controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, scope.backendStore]),
      builder: (context, _) {
        final snapshot = controller.snapshot(scope.miniProgramId);
        final template = _templateFor(snapshot);
        if (template == null) {
          return const SizedBox.shrink();
        }
        return _MpNodeView(
          node: template,
          bindings: bindings.copyWith(scope: scope),
        );
      },
    );
  }

  _MpNode? _templateFor(MiniProgramAuthSnapshot snapshot) {
    if (snapshot.loading) {
      return node.props['loading'] as _MpNode?;
    }
    if (snapshot.authenticated) {
      return node.props['signedIn'] as _MpNode?;
    }
    if (snapshot.hasError) {
      return (node.props['error'] ?? node.props['signedOut']) as _MpNode?;
    }
    return node.props['signedOut'] as _MpNode?;
  }
}

class _MpBackendBuilder extends StatefulWidget {
  const _MpBackendBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpBackendBuilder> createState() => _MpBackendBuilderState();
}

class _MpBackendBuilderState extends State<_MpBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.node) != _queryKey(oldWidget.node)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final model = widget.node;
    final key = _queryKey(model);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.snapshot(_string(model, 'requestId'));
    if (!_bool(model, 'forceRefresh') && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      final bindings = widget.bindings.copyWith(scope: activeScope);
      activeScope.backendStore.runQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _backendQuery(model, bindings),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.snapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasData) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final itemTemplate = widget.node.props['itemTemplate'] as _MpNode?;
    if (itemTemplate != null) {
      return _renderItems(scope, snapshot, itemTemplate);
    }

    return _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
        const SizedBox.shrink();
  }

  Widget _renderItems(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
    _MpNode itemTemplate,
  ) {
    final itemsPath = widget.node.props['itemsPath'] as String?;
    final rawItems = itemsPath == null || itemsPath.isEmpty
        ? snapshot.data['items']
        : _readPath(snapshot.toBindingData(), itemsPath);
    if (rawItems is! List || rawItems.isEmpty) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final rawItem in rawItems)
          _MpNodeView(
            node: itemTemplate,
            bindings: widget.bindings.copyWith(
              scope: scope,
              item: rawItem is Map
                  ? Map<String, dynamic>.from(rawItem)
                  : <String, dynamic>{'value': rawItem},
            ),
          ),
      ],
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: widget.bindings.copyWith(scope: scope),
    );
  }
}

class _MpPagedBackendBuilder extends StatefulWidget {
  const _MpPagedBackendBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpPagedBackendBuilder> createState() => _MpPagedBackendBuilderState();
}

class _MpPagedBackendBuilderState extends State<_MpPagedBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpPagedBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.node) != _queryKey(oldWidget.node)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final key = _queryKey(widget.node);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.pagedSnapshot(
      _string(widget.node, 'requestId'),
    );
    if (!_bool(widget.node, 'forceRefresh') && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      activeScope.backendStore.runPagedQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _pagedQuery(widget.node),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.pagedSnapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramPagedBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (!snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final children = <Widget>[
      for (final rawItem in snapshot.items)
        _MpNodeView(
          node: widget.node.props['itemTemplate'] as _MpNode,
          bindings: widget.bindings.copyWith(
            scope: scope,
            item: rawItem is Map
                ? Map<String, dynamic>.from(rawItem)
                : <String, dynamic>{'value': rawItem},
          ),
        ),
    ];

    if (snapshot.isFailure) {
      final error = _renderTemplate(
        scope,
        widget.node.props['error'] as _MpNode?,
      );
      if (error != null) {
        children.add(error);
      }
    } else if (snapshot.loadingMore) {
      final loadingMore = _renderTemplate(
        scope,
        widget.node.props['loadingMore'] as _MpNode?,
      );
      if (loadingMore != null) {
        children.add(loadingMore);
      }
    } else if (snapshot.hasMore) {
      final loadMore = _renderTemplate(
        scope,
        widget.node.props['loadMore'] as _MpNode?,
      );
      if (loadMore != null) {
        children.add(loadMore);
      }
    } else {
      final end = _renderTemplate(scope, widget.node.props['end'] as _MpNode?);
      if (end != null) {
        children.add(end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: widget.bindings.copyWith(scope: scope),
    );
  }
}

MiniProgramBackendQuery _backendQuery(
  _MpNode node,
  _MpRenderBindings bindings,
) {
  return MiniProgramBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    method: _string(node, 'method'),
    body: Map<String, dynamic>.from(
      bindings.resolveValue(node.props['body']) as Map? ??
          const <String, dynamic>{},
    ),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

MiniProgramPagedBackendQuery _pagedQuery(_MpNode node) {
  return MiniProgramPagedBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    limit: _int(node, 'limit', fallback: 20),
    initialCursor: node.props['initialCursor'] as String?,
    cursorParam: _string(node, 'cursorParam'),
    limitParam: _string(node, 'limitParam'),
    itemsPath: _string(node, 'itemsPath'),
    nextCursorPath: _string(node, 'nextCursorPath'),
    hasMorePath: _string(node, 'hasMorePath'),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

String _queryKey(_MpNode node) {
  return jsonEncode(
    node.props.map<String, Object?>((key, value) {
      if (value is _MpNode) {
        return MapEntry<String, Object?>(key, value.type);
      }
      return MapEntry<String, Object?>(key, value);
    }),
  );
}

String _string(_MpNode node, String key) => node.props[key] as String;

bool _bool(_MpNode node, String key) => node.props[key] == true;

int _int(_MpNode node, String key, {required int fallback}) {
  return node.props[key] as int? ?? fallback;
}

Duration? _duration(_MpNode node, String key) {
  final seconds = node.props[key] as int?;
  return seconds == null ? null : Duration(seconds: seconds);
}
