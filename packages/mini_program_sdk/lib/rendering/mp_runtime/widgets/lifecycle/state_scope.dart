part of '../../../mp_screen_renderer.dart';

class _MpStateScope extends StatefulWidget {
  const _MpStateScope({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpStateScope> createState() => _MpStateScopeState();
}

class _MpStateScopeState extends State<_MpStateScope> {
  MpStateManager? _stateManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MiniProgramSdkScope.maybeOf(context)?.stateManager;
    if (!identical(next, _stateManager)) {
      _clearOwnedState(widget.node, manager: _stateManager);
      _stateManager = next;
    }
  }

  @override
  void didUpdateWidget(covariant _MpStateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'prefix') != _string(widget.node, 'prefix')) {
      _clearOwnedState(oldWidget.node);
    }
  }

  void _clearOwnedState(_MpNode node, {MpStateManager? manager}) {
    if (_bool(node, 'clearOnDispose')) {
      (manager ?? _stateManager)?.remove(_string(node, 'prefix'));
    }
  }

  @override
  void dispose() {
    _clearOwnedState(widget.node);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _MpNodeView(node: widget.node.children.single, bindings: widget.bindings);
}
