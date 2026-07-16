part of '../../../mp_screen_renderer.dart';

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
