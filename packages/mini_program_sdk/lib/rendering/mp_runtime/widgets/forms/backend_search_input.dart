part of '../../../mp_screen_renderer.dart';

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
