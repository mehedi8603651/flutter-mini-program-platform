part of '../../../mp_screen_renderer.dart';

class _MpRefreshViewport extends StatefulWidget {
  const _MpRefreshViewport({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpRefreshViewport> createState() => _MpRefreshViewportState();
}

class _MpRefreshViewportState extends State<_MpRefreshViewport> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final scope = MiniProgramSdkScope.maybeOf(context);
      if (scope == null || !mounted) {
        return;
      }
      await _MpActionDispatcher.dispatch(
        context,
        widget.node.props['action'] as _MpAction,
        widget.bindings.copyWith(scope: scope),
      );
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget viewport = RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(
          node: widget.node.children.single,
          bindings: widget.bindings,
        ),
      ),
    );
    final label = widget.node.props['semanticsLabel'] as String?;
    if (label != null) {
      viewport = Semantics(label: label, child: viewport);
    }
    return viewport;
  }
}
