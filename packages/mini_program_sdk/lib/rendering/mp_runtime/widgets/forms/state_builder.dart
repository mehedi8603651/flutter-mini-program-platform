part of '../../../mp_screen_renderer.dart';

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
