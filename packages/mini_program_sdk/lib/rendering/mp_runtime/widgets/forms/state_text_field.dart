part of '../../../mp_screen_renderer.dart';

class _MpStateTextField extends StatefulWidget {
  const _MpStateTextField({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpStateTextField> createState() => _MpStateTextFieldState();
}

class _MpStateTextFieldState extends State<_MpStateTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  MpStateManager? _state;
  ValueListenable<Object?>? _stateListenable;
  Timer? _debounceTimer;
  int _generation = 0;
  bool _updatingController = false;

  String get _stateKey => _string(widget.node, 'stateKey');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.node.props['initialValue'] as String? ?? '',
    );
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindState();
  }

  @override
  void didUpdateWidget(covariant _MpStateTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'stateKey') != _stateKey) {
      _bindState(force: true);
    }
  }

  void _bindState({bool force = false}) {
    final state = MiniProgramSdkScope.maybeOf(context)?.stateManager;
    if (!force && identical(state, _state)) {
      return;
    }
    _stateListenable?.removeListener(_syncFromState);
    _state = state;
    if (state == null) {
      _stateListenable = null;
      return;
    }
    _stateListenable = state.watch(_stateKey)..addListener(_syncFromState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_state, state)) {
        return;
      }
      if (!state.contains(_stateKey)) {
        state.set(
          _stateKey,
          widget.node.props['initialValue'] as String? ?? '',
        );
      }
      _syncFromState();
    });
  }

  void _syncFromState() {
    if (!mounted || _updatingController) {
      return;
    }
    final value = _state?.get<Object?>(_stateKey);
    final text = value is String ? value : value?.toString() ?? '';
    if (_controller.text == text) {
      return;
    }
    _updatingController = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updatingController = false;
    setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleChanged(String value) {
    if (_updatingController) {
      return;
    }
    final state = _state;
    if (state == null) {
      return;
    }
    state.set(_stateKey, value);
    if (mounted) {
      setState(() {});
    }
    _generation += 1;
    final generation = _generation;
    _debounceTimer?.cancel();
    final action = widget.node.props['onChanged'] as _MpAction?;
    if (action == null) {
      return;
    }
    final debounceMs = _int(widget.node, 'debounceMs', fallback: 0);
    if (debounceMs == 0) {
      unawaited(_dispatchAction(action, generation));
      return;
    }
    _debounceTimer = Timer(
      Duration(milliseconds: debounceMs),
      () => unawaited(_dispatchAction(action, generation)),
    );
  }

  void _handleSubmitted(String value) {
    _debounceTimer?.cancel();
    _generation += 1;
    final action = widget.node.props['onSubmitted'] as _MpAction?;
    if (action != null) {
      unawaited(_dispatchAction(action, _generation));
    }
  }

  Future<void> _dispatchAction(_MpAction action, int generation) async {
    if (!mounted || generation != _generation) {
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    await _MpActionDispatcher.dispatch(
      context,
      action,
      widget.bindings.copyWith(scope: scope),
    );
  }

  @override
  void dispose() {
    _generation += 1;
    _debounceTimer?.cancel();
    _stateListenable?.removeListener(_syncFromState);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = _double(widget.node, 'borderWidth', fallback: 1);
    final borderRadius = BorderRadius.circular(
      _double(widget.node, 'borderRadius', fallback: 8),
    );
    final textColor = _mpColor(
      _string(widget.node, 'textColor'),
      fallback: const Color(0xFF111827),
    );
    final hintColor = _mpColor(
      _string(widget.node, 'hintColor'),
      fallback: const Color(0xFF6B7280),
    );
    final fontSize = _double(widget.node, 'fontSize', fallback: 15);
    final hint = widget.node.props['hint'] as String?;
    return _MpFieldFrame(
      label: widget.node.props['label'] as String? ?? '',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _mpColor(
            _string(widget.node, 'backgroundColor'),
            fallback: const Color(0xFFFFFFFF),
          ),
          border: Border.all(
            color: _focusNode.hasFocus
                ? _mpColor(
                    _string(widget.node, 'focusedBorderColor'),
                    fallback: const Color(0xFF0B7A75),
                  )
                : _mpColor(
                    _string(widget.node, 'borderColor'),
                    fallback: const Color(0xFFD1D5DB),
                  ),
            width: borderWidth,
          ),
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _double(widget.node, 'paddingHorizontal', fallback: 12),
            vertical: _double(widget.node, 'paddingVertical', fallback: 10),
          ),
          child: Stack(
            children: <Widget>[
              if (_controller.text.isEmpty && hint != null)
                IgnorePointer(
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: fontSize,
                      height: 1.35,
                    ),
                  ),
                ),
              EditableText(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: _bool(widget.node, 'autofocus'),
                keyboardType: _stateTextKeyboardType(
                  _string(widget.node, 'keyboardType'),
                ),
                textInputAction: _stateTextInputAction(
                  _string(widget.node, 'textInputAction'),
                ),
                minLines: _int(widget.node, 'minLines', fallback: 1),
                maxLines: _int(widget.node, 'maxLines', fallback: 1),
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    _int(widget.node, 'maxLength', fallback: 4096),
                  ),
                ],
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  height: 1.35,
                ),
                cursorColor: _mpColor(
                  _string(widget.node, 'cursorColor'),
                  fallback: const Color(0xFF0B7A75),
                ),
                backgroundCursorColor: hintColor,
                onChanged: _handleChanged,
                onSubmitted: _handleSubmitted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextInputType _stateTextKeyboardType(String value) {
  return switch (value) {
    'multiline' => TextInputType.multiline,
    'email' => TextInputType.emailAddress,
    'number' => TextInputType.number,
    'phone' => TextInputType.phone,
    'url' => TextInputType.url,
    _ => TextInputType.text,
  };
}

TextInputAction _stateTextInputAction(String value) {
  return switch (value) {
    'next' => TextInputAction.next,
    'newline' => TextInputAction.newline,
    _ => TextInputAction.done,
  };
}
