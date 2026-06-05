part of '../mp_screen_renderer.dart';

class _MpScreenView extends StatelessWidget {
  const _MpScreenView({required this.screen});

  final _MpScreen screen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(
          node: screen.root,
          bindings: _MpRenderBindings(
            scope: MiniProgramSdkScope.maybeOf(context),
          ),
        ),
      ),
    );
  }
}

class _MpTapButton extends StatefulWidget {
  const _MpTapButton({
    required this.label,
    required this.primary,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_MpTapButton> createState() => _MpTapButtonState();
}

class _MpTapButtonState extends State<_MpTapButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final background = !enabled
        ? const Color(0xFFE5E7EB)
        : widget.primary
        ? (_pressed
              ? const Color(0xFF065F56)
              : _hovered || _focused
              ? const Color(0xFF0F766E)
              : const Color(0xFF0B7A75))
        : const Color(0xFFFFFFFF);
    final foreground = !enabled
        ? const Color(0xFF6B7280)
        : widget.primary
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B7A75);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onTap : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: enabled
                    ? const Color(0xFF0B7A75)
                    : const Color(0xFFD1D5DB),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpFieldFrame extends StatelessWidget {
  const _MpFieldFrame({
    required this.label,
    required this.child,
    this.hint,
    this.error,
  });

  final String label;
  final String? hint;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label.isNotEmpty) ...<Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          child,
          if (hint != null && hint!.isNotEmpty && error == null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _fieldDecoration({String? error, bool focused = false}) {
  return BoxDecoration(
    color: const Color(0xFFFFFFFF),
    border: Border.all(
      color: error != null
          ? const Color(0xFFDC2626)
          : focused
          ? const Color(0xFF0B7A75)
          : const Color(0xFFD1D5DB),
    ),
    borderRadius: BorderRadius.circular(8),
  );
}

TextInputType _keyboardType(String? value) {
  return switch (value) {
    'email' => TextInputType.emailAddress,
    'number' => TextInputType.number,
    'phone' => TextInputType.phone,
    'url' => TextInputType.url,
    _ => TextInputType.text,
  };
}

List<Map<String, dynamic>> _options(_MpNode node) {
  return (node.props['options'] as List)
      .whereType<Map>()
      .map((option) => Map<String, dynamic>.from(option))
      .toList(growable: false);
}

Map<String, dynamic>? _optionForValue(_MpNode node, String value) {
  for (final option in _options(node)) {
    if (option['value'] == value) {
      return option;
    }
  }
  return null;
}

class _MpOptionDialog extends StatelessWidget {
  const _MpOptionDialog({
    required this.title,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in options)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(option['value'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        option['label'] as String,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpCheckMark extends StatelessWidget {
  const _MpCheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF0B7A75) : const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _MpRadioMark extends StatelessWidget {
  const _MpRadioMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF0B7A75),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _NoopListenable implements Listenable {
  const _NoopListenable();

  static const instance = _NoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _MpToastView extends StatelessWidget {
  const _MpToastView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _MpDialogView extends StatelessWidget {
  const _MpDialogView({
    required this.message,
    required this.confirmLabel,
    this.title,
  });

  final String? title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MpTapButton(
                    label: confirmLabel,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpNodeView extends StatelessWidget {
  const _MpNodeView({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'column' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: node.children
            .map((child) => _MpNodeView(node: child, bindings: bindings))
            .toList(growable: false),
      ),
      'row' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node.children
            .map(
              (child) => Flexible(
                child: _MpNodeView(node: child, bindings: bindings),
              ),
            )
            .toList(growable: false),
      ),
      'text' => Text(
        bindings.resolveString(node.props['data'] as String),
        style: const TextStyle(
          fontSize: 15,
          height: 1.35,
          color: Color(0xFF263238),
        ),
      ),
      'heading' => Text(
        bindings.resolveString(node.props['data'] as String),
        style: const TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      'sizedBox' => SizedBox(
        width: (node.props['width'] as num?)?.toDouble(),
        height: (node.props['height'] as num?)?.toDouble(),
      ),
      'image' => _MpImage(node: node, bindings: bindings),
      'card' => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _MpNodeView(node: node.children.single, bindings: bindings),
        ),
      ),
      'primaryButton' => _MpButton(
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: true,
        bindings: bindings,
      ),
      'secondaryButton' => _MpButton(
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: false,
        bindings: bindings,
      ),
      'textInput' => _MpTextInputField(node: node, multiline: false),
      'textArea' => _MpTextInputField(node: node, multiline: true),
      'dropdown' => _MpDropdownField(node: node),
      'checkbox' => _MpCheckboxField(node: node),
      'radioGroup' => _MpRadioGroupField(node: node),
      'form' => _MpForm(node: node, bindings: bindings),
      'formSubmit' => _MpFormSubmitButton(node: node, bindings: bindings),
      'authBuilder' => _MpAuthBuilder(node: node),
      'backendBuilder' => _MpBackendBuilder(node: node),
      'pagedBackendBuilder' => _MpPagedBackendBuilder(node: node),
      _ => throw MiniProgramRenderException(
        message: 'Unsupported Mp node type "${node.type}".',
        details: <String, dynamic>{'nodeType': node.type},
      ),
    };
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

class _MpImage extends StatelessWidget {
  const _MpImage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final src = bindings.resolveString(node.props['src'] as String);
    final uri = Uri.tryParse(src);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                MpScreenValidator._isLocalPreviewHost(uri.host)))) {
      return _imageFallback();
    }
    return Image.network(
      src,
      semanticLabel: node.props['alt'] == null
          ? null
          : bindings.resolveString(node.props['alt'] as String),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _imageFallback(),
    );
  }

  Widget _imageFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFE5E7EB)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Image unavailable'),
      ),
    );
  }
}

class _MpButton extends StatefulWidget {
  const _MpButton({
    required this.label,
    required this.action,
    required this.primary,
    required this.bindings,
  });

  final String label;
  final _MpAction action;
  final bool primary;
  final _MpRenderBindings bindings;

  @override
  State<_MpButton> createState() => _MpButtonState();
}

class _MpButtonState extends State<_MpButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.primary
        ? (_pressed
              ? const Color(0xFF065F56)
              : _hovered || _focused
              ? const Color(0xFF0F766E)
              : const Color(0xFF0B7A75))
        : const Color(0xFFFFFFFF);
    final foreground = widget.primary
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B7A75);

    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () => unawaited(
            _MpActionDispatcher.dispatch(
              context,
              widget.action,
              widget.bindings,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: const Color(0xFF0B7A75)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpAuthBuilder extends StatelessWidget {
  const _MpAuthBuilder({required this.node});

  final _MpNode node;

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
          bindings: _MpRenderBindings(scope: scope),
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

class _MpBackendBuilder extends StatefulWidget {
  const _MpBackendBuilder({required this.node});

  final _MpNode node;

  @override
  State<_MpBackendBuilder> createState() => _MpBackendBuilderState();
}

class _MpBackendBuilderState extends State<_MpBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.node) != _queryKey(oldWidget.node)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final model = widget.node;
    final key = _queryKey(model);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.snapshot(_string(model, 'requestId'));
    if (!_bool(model, 'forceRefresh') && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      final bindings = _MpRenderBindings(scope: activeScope);
      activeScope.backendStore.runQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _backendQuery(model, bindings),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.snapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasData) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final itemTemplate = widget.node.props['itemTemplate'] as _MpNode?;
    if (itemTemplate != null) {
      return _renderItems(scope, snapshot, itemTemplate);
    }

    return _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
        const SizedBox.shrink();
  }

  Widget _renderItems(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
    _MpNode itemTemplate,
  ) {
    final itemsPath = widget.node.props['itemsPath'] as String?;
    final rawItems = itemsPath == null || itemsPath.isEmpty
        ? snapshot.data['items']
        : _readPath(snapshot.toBindingData(), itemsPath);
    if (rawItems is! List || rawItems.isEmpty) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final rawItem in rawItems)
          _MpNodeView(
            node: itemTemplate,
            bindings: _MpRenderBindings(
              scope: scope,
              item: rawItem is Map
                  ? Map<String, dynamic>.from(rawItem)
                  : <String, dynamic>{'value': rawItem},
            ),
          ),
      ],
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: _MpRenderBindings(scope: scope),
    );
  }
}

class _MpPagedBackendBuilder extends StatefulWidget {
  const _MpPagedBackendBuilder({required this.node});

  final _MpNode node;

  @override
  State<_MpPagedBackendBuilder> createState() => _MpPagedBackendBuilderState();
}

class _MpPagedBackendBuilderState extends State<_MpPagedBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpPagedBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.node) != _queryKey(oldWidget.node)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final key = _queryKey(widget.node);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.pagedSnapshot(
      _string(widget.node, 'requestId'),
    );
    if (!_bool(widget.node, 'forceRefresh') && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      activeScope.backendStore.runPagedQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _pagedQuery(widget.node),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.pagedSnapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramPagedBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (!snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final children = <Widget>[
      for (final rawItem in snapshot.items)
        _MpNodeView(
          node: widget.node.props['itemTemplate'] as _MpNode,
          bindings: _MpRenderBindings(
            scope: scope,
            item: rawItem is Map
                ? Map<String, dynamic>.from(rawItem)
                : <String, dynamic>{'value': rawItem},
          ),
        ),
    ];

    if (snapshot.isFailure) {
      final error = _renderTemplate(
        scope,
        widget.node.props['error'] as _MpNode?,
      );
      if (error != null) {
        children.add(error);
      }
    } else if (snapshot.loadingMore) {
      final loadingMore = _renderTemplate(
        scope,
        widget.node.props['loadingMore'] as _MpNode?,
      );
      if (loadingMore != null) {
        children.add(loadingMore);
      }
    } else if (snapshot.hasMore) {
      final loadMore = _renderTemplate(
        scope,
        widget.node.props['loadMore'] as _MpNode?,
      );
      if (loadMore != null) {
        children.add(loadMore);
      }
    } else {
      final end = _renderTemplate(scope, widget.node.props['end'] as _MpNode?);
      if (end != null) {
        children.add(end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: _MpRenderBindings(scope: scope),
    );
  }
}

MiniProgramBackendQuery _backendQuery(
  _MpNode node,
  _MpRenderBindings bindings,
) {
  return MiniProgramBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    method: _string(node, 'method'),
    body: Map<String, dynamic>.from(
      bindings.resolveValue(node.props['body']) as Map? ??
          const <String, dynamic>{},
    ),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

MiniProgramPagedBackendQuery _pagedQuery(_MpNode node) {
  return MiniProgramPagedBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    limit: _int(node, 'limit', fallback: 20),
    initialCursor: node.props['initialCursor'] as String?,
    cursorParam: _string(node, 'cursorParam'),
    limitParam: _string(node, 'limitParam'),
    itemsPath: _string(node, 'itemsPath'),
    nextCursorPath: _string(node, 'nextCursorPath'),
    hasMorePath: _string(node, 'hasMorePath'),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

String _queryKey(_MpNode node) {
  return jsonEncode(
    node.props.map<String, Object?>((key, value) {
      if (value is _MpNode) {
        return MapEntry<String, Object?>(key, value.type);
      }
      return MapEntry<String, Object?>(key, value);
    }),
  );
}

String _string(_MpNode node, String key) => node.props[key] as String;

bool _bool(_MpNode node, String key) => node.props[key] == true;

int _int(_MpNode node, String key, {required int fallback}) {
  return node.props[key] as int? ?? fallback;
}

Duration? _duration(_MpNode node, String key) {
  final seconds = node.props[key] as int?;
  return seconds == null ? null : Duration(seconds: seconds);
}
