part of '../../../mp_screen_renderer.dart';

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
