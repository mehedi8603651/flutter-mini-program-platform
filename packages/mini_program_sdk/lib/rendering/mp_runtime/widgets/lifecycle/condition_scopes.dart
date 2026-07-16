part of '../../../mp_screen_renderer.dart';

class _MpActionScope extends StatelessWidget {
  const _MpActionScope({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final definitions = node.props['actions'] as Map<String, _MpAction>;
    return _MpNodeView(
      node: node.children.single,
      bindings: bindings.withActionDefinitions(definitions),
    );
  }
}

class _MpCondition extends StatelessWidget {
  const _MpCondition({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final activeBindings = bindings.copyWith(scope: scope);
    final state = scope?.stateManager;
    final paths = _stateBindingPaths(node.props['condition']);
    if (state == null || paths.isEmpty) {
      return _buildBranch(activeBindings);
    }
    final listenable = Listenable.merge(
      paths.map(state.watch).toList(growable: false),
    );
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) => _buildBranch(
        bindings.copyWith(scope: MiniProgramSdkScope.maybeOf(context)),
      ),
    );
  }

  Widget _buildBranch(_MpRenderBindings activeBindings) {
    final resolved = activeBindings.resolveValue(node.props['condition']);
    final template = resolved == true
        ? node.props['whenTrue'] as _MpNode
        : node.props['whenFalse'] as _MpNode?;
    return template == null
        ? const SizedBox.shrink()
        : _MpNodeView(node: template, bindings: activeBindings);
  }
}
