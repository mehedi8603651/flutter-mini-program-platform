part of '../../../mp_screen_renderer.dart';

class _MpStateSearchField extends StatefulWidget {
  const _MpStateSearchField({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpStateSearchField> createState() => _MpStateSearchFieldState();
}

class _MpStateSearchFieldState extends State<_MpStateSearchField> {
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
  void didUpdateWidget(covariant _MpStateSearchField oldWidget) {
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

  void _handleChanged(String value, {bool immediate = false}) {
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
    if (immediate || _int(widget.node, 'debounceMs', fallback: 300) == 0) {
      unawaited(_dispatchAction(action, generation));
      return;
    }
    _debounceTimer = Timer(
      Duration(milliseconds: _int(widget.node, 'debounceMs', fallback: 300)),
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

  void _clear() {
    _controller.clear();
    _handleChanged('', immediate: true);
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
    return _MpFieldFrame(
      label: _string(widget.node, 'label'),
      hint: widget.node.props['hint'] as String?,
      child: DecoratedBox(
        decoration: _fieldDecoration(focused: _focusNode.hasFocus),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: <Widget>[
              const Icon(
                IconData(0xe567, fontFamily: 'MaterialIcons'),
                size: 20,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EditableText(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  minLines: 1,
                  maxLines: 1,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(
                      _int(widget.node, 'maxLength', fallback: 256),
                    ),
                  ],
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    height: 1.35,
                  ),
                  cursorColor: const Color(0xFF0B7A75),
                  backgroundCursorColor: const Color(0xFFE5E7EB),
                  onChanged: _handleChanged,
                  onSubmitted: _handleSubmitted,
                ),
              ),
              if (_bool(widget.node, 'showClearButton') &&
                  _controller.text.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'Clear search',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _clear,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        IconData(0xe16a, fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
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
