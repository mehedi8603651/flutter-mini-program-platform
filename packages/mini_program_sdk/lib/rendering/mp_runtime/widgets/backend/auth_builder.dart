part of '../../../mp_screen_renderer.dart';

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
