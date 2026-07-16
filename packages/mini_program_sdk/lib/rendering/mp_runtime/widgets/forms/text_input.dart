part of '../../../mp_screen_renderer.dart';

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
