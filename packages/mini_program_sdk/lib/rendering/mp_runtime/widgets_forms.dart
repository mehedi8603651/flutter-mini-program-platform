part of '../mp_screen_renderer.dart';

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

class _MpSearchInputField extends StatefulWidget {
  const _MpSearchInputField({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpSearchInputField> createState() => _MpSearchInputFieldState();
}

class _MpSearchInputFieldState extends State<_MpSearchInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  int _generation = 0;
  bool _seeded = false;

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
    _seedInitialState();
  }

  @override
  void didUpdateWidget(covariant _MpSearchInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'stateKey') !=
        _string(widget.node, 'stateKey')) {
      _seeded = false;
      _seedInitialState();
    }
  }

  void _seedInitialState() {
    if (_seeded) {
      return;
    }
    _seeded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleChanged(_controller.text);
    });
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleChanged(String value) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final state = scope?.stateManager;
    if (scope == null || state == null) {
      return;
    }

    state.set(_string(widget.node, 'stateKey'), value);
    _generation += 1;
    final generation = _generation;
    final query = value.trim();
    if (query.length < _int(widget.node, 'minLength', fallback: 2)) {
      _debounceTimer?.cancel();
      _writeStatus(state, 'idle');
      _clearError(state);
      if (_bool(widget.node, 'clearResultsBelowMinLength')) {
        state.set(_string(widget.node, 'targetState'), const <String, dynamic>{
          'items': <Object?>[],
        });
      }
      return;
    }

    _writeStatus(state, 'loading');
    _clearError(state);
    _debounceTimer?.cancel();
    final delay = Duration(
      milliseconds: _int(widget.node, 'debounceMs', fallback: 300),
    );
    _debounceTimer = Timer(delay, () {
      unawaited(_runSearch(generation, query));
    });
  }

  Future<void> _runSearch(int generation, String query) async {
    if (!mounted || generation != _generation) {
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    final state = scope?.stateManager;
    if (scope == null || state == null) {
      return;
    }

    final bindings = widget.bindings.copyWith(scope: scope);
    final method = _string(widget.node, 'method');
    final limit = _int(widget.node, 'limit', fallback: 20);
    final requestId = '${_string(widget.node, 'requestId')}_$generation';
    final queryObject = MiniProgramBackendQuery(
      requestId: requestId,
      endpoint: method == 'GET'
          ? _searchEndpoint(widget.node, query: query, limit: limit)
          : _string(widget.node, 'endpoint'),
      method: method,
      body: method == 'GET'
          ? const <String, dynamic>{}
          : _searchBody(widget.node, bindings, query: query, limit: limit),
      cacheTtl: _duration(widget.node, 'cacheTtlSeconds'),
      forceRefresh: true,
    );

    final snapshot = await scope.backendStore.runQuery(
      connector: scope.backendConnector,
      miniProgramId: scope.miniProgramId,
      query: queryObject,
      requestInterceptor: scope.authController == null
          ? null
          : (request) => scope.authController!.authorizeRequest(
              request: request,
              connector: scope.backendConnector,
            ),
    );
    if (!mounted || generation != _generation) {
      return;
    }

    if (snapshot.isSuccess) {
      final normalized = _normalizeSearchData(snapshot.data);
      state.set(_string(widget.node, 'targetState'), normalized);
      _clearError(state);
      _writeStatus(state, _searchDataIsEmpty(normalized) ? 'empty' : 'success');
      return;
    }

    if (state.get<Object?>(_string(widget.node, 'targetState')) == null) {
      state.set(_string(widget.node, 'targetState'), const <String, dynamic>{
        'items': <Object?>[],
      });
    }
    _writeStatus(state, 'error');
    final errorState = widget.node.props['errorState'] as String?;
    if (errorState != null) {
      state.set(errorState, <String, dynamic>{
        'message': snapshot.message ?? 'Search failed',
        if (snapshot.errorCode != null) 'code': snapshot.errorCode,
      });
    }
  }

  void _writeStatus(MpStateManager state, String status) {
    final statusState = widget.node.props['statusState'] as String?;
    if (statusState != null) {
      state.set(statusState, status);
    }
  }

  void _clearError(MpStateManager state) {
    final errorState = widget.node.props['errorState'] as String?;
    if (errorState != null) {
      state.remove(errorState);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
          child: EditableText(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.text,
            obscureText: false,
            minLines: 1,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              height: 1.35,
            ),
            cursorColor: const Color(0xFF0B7A75),
            backgroundCursorColor: const Color(0xFFE5E7EB),
            onChanged: _handleChanged,
          ),
        ),
      ),
    );
  }
}

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
