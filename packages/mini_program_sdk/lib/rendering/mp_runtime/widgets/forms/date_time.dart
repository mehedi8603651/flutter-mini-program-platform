part of '../../../mp_screen_renderer.dart';

class _MpDateTimeField extends StatefulWidget {
  const _MpDateTimeField({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpDateTimeField> createState() => _MpDateTimeFieldState();
}

class _MpDateTimeFieldState extends State<_MpDateTimeField>
    with WidgetsBindingObserver {
  MpStateManager? _state;
  ValueListenable<Object?>? _watcher;
  _MpFormController? _form;
  String? _appId;
  String _key = '';
  String _name = '';
  Object? _value;
  String? _saveError;
  bool _foreground = false;
  int _generation = 0;
  DialogRoute<Object>? _picker;
  NavigatorState? _pickerNavigator;
  ModalRoute<dynamic>? _ownerRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(covariant _MpDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dateTimeFieldIdentity(oldWidget.node) !=
        _dateTimeFieldIdentity(widget.node)) {
      _invalidatePicker();
      _saveError = null;
    }
    _bind();
  }

  void _bind() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final state = scope?.stateManager;
    final form = _MpFormScope.maybeOf(context);
    final key = _string(widget.node, 'stateKey');
    final name = _string(widget.node, 'name');
    _foreground = scope?.isForeground == true;
    _ownerRoute = ModalRoute.of(context);
    if (!_foreground ||
        (_picker?.isActive == true && _picker?.isCurrent == false)) {
      _invalidatePicker();
    }
    if (identical(_state, state) &&
        identical(_form, form) &&
        _appId == scope?.miniProgramId &&
        _key == key &&
        _name == name) {
      return;
    }
    _invalidatePicker();
    _watcher?.removeListener(_onStateChanged);
    _form?.removeListener(_onFormChanged);
    _form?.unregisterField(_name);
    _state = state;
    _form = form;
    _appId = scope?.miniProgramId;
    _key = key;
    _name = name;
    _saveError = null;
    _value = state?.contains(key) == true
        ? state!.get<Object?>(key)
        : widget.node.props['initialValue'];
    form?.registerField(
      name: name,
      initialValue: _value,
      validator: (value) => _dateTimeFieldError(widget.node, value),
    );
    form?.addListener(_onFormChanged);
    _watcher = state?.watch(key);
    _watcher?.addListener(_onStateChanged);
    final appId = _appId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_state, state) ||
          _key != key ||
          _appId != appId) {
        return;
      }
      if (state != null && !state.contains(key) && _value != null) {
        try {
          state.set(key, _value);
        } catch (_) {
          setState(() => _saveError = 'Unable to save this selection.');
          _value = null;
        }
      }
      _onStateChanged();
      _form?.setValue(_name, _value);
    });
  }

  void _onStateChanged() {
    if (!mounted || _state == null) return;
    final next = _state!.get<Object?>(_key);
    if (_sameDateTimeValue(next, _value)) return;
    _invalidatePicker();
    setState(() {
      _value = next;
      _saveError = null;
    });
    _form?.setValue(_name, next);
  }

  void _onFormChanged() {
    if (!mounted) return;
    if (_form?.submitting == true) _invalidatePicker();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _invalidatePicker();
    }
    if (mounted) setState(() {});
  }

  void _invalidatePicker() {
    _generation++;
    final route = _picker;
    final navigator = _pickerNavigator;
    _picker = null;
    _pickerNavigator = null;
    if (route == null || navigator == null) return;
    // Dependency changes/disposal can happen while the navigator is locked.
    // Remove this exact owned route, never pop whichever route is now on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  bool get _canInteract =>
      _state != null &&
      _foreground &&
      _bool(widget.node, 'enabled') &&
      _form?.submitting != true &&
      _ownerRoute?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  bool _current(int generation, MpStateManager state, String appId) {
    if (!mounted || generation != _generation || !_canInteract) return false;
    final scope = MiniProgramSdkScope.maybeOf(context);
    return scope?.miniProgramId == appId &&
        identical(scope?.stateManager, state) &&
        scope?.isForeground == true;
  }

  void _startChoosing() {
    final future = _choose();
    MiniProgramInteractionExecution.current?.track(future);
    unawaited(future);
  }

  Future<void> _choose() async {
    if (!_canInteract || _picker != null) return;
    final state = _state!;
    final appId = _appId!;
    final generation = ++_generation;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final interactionRoute = MiniProgramInteractionSurface.routeBuilder(
      context,
    );
    final route = DialogRoute<Object>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      settings: RouteSettings(name: 'mini-program/date-time/$_key'),
      builder: (pickerContext) => interactionRoute(_buildPicker(pickerContext)),
    );
    _picker = route;
    _pickerNavigator = navigator;
    setState(() => _saveError = null);
    Object? result;
    final interaction = MiniProgramInteractionExecution.current;
    if (interaction != null) interaction.waitingForPanel = true;
    try {
      result = await navigator.push<Object>(route);
    } finally {
      if (interaction != null) interaction.waitingForPanel = false;
      if (identical(_picker, route)) {
        _picker = null;
        _pickerNavigator = null;
      }
      if (mounted) setState(() {});
    }
    if (result == null || !_current(generation, state, appId)) return;
    try {
      final Object selected;
      if (widget.node.type == 'dateField' && result is DateTime) {
        selected = _dateTimeDateString(result);
      } else if (widget.node.type == 'timeField' && result is TimeOfDay) {
        selected =
            '${result.hour.toString().padLeft(2, '0')}:'
            '${result.minute.toString().padLeft(2, '0')}';
      } else if (widget.node.type == 'dateRangeField' &&
          result is DateTimeRange) {
        selected = <String, String>{
          'start': _dateTimeDateString(result.start),
          'end': _dateTimeDateString(result.end),
        };
      } else {
        throw const FormatException('Invalid picker result.');
      }
      if (_dateTimeFieldError(widget.node, selected) != null) {
        throw const FormatException(
          'Picker result is outside accepted bounds.',
        );
      }
      if (_sameDateTimeValue(selected, _value)) return;
      // Commit to the quota-enforced store before changing any form value.
      state.set(_key, selected);
      _onStateChanged();
    } catch (_) {
      if (_current(generation, state, appId)) {
        setState(() => _saveError = 'Unable to save this selection.');
      }
      return;
    }
    final action = widget.node.props['onChanged'] as _MpAction?;
    // Store notifications can rebuild this field or replace its owner.
    if (action != null &&
        mounted &&
        _canInteract &&
        identical(_state, state) &&
        _appId == appId) {
      await _MpActionDispatcher.dispatch(
        context,
        action,
        widget.bindings.copyWith(
          scope: MiniProgramSdkScope.maybeOf(context),
          form: _form?.toBindingData(),
        ),
        const _MpActionCallContext(userGesture: true),
      );
    }
  }

  Widget _buildPicker(BuildContext context) {
    // The field's route is already covered by its own dialog, so it cannot
    // observe another route being pushed. Subscribe from the dialog itself.
    final route = ModalRoute.of(context);
    if (route?.isActive == true && route?.isCurrent == false) {
      _invalidatePicker();
    }
    final label = widget.bindings.resolveString(_string(widget.node, 'label'));
    final valid =
        _dateTimeFieldError(widget.node, _value, checkRequired: false) == null;
    if (widget.node.type == 'timeField') {
      final minutes = valid && _value is String && (_value as String).isNotEmpty
          ? MiniProgramDateTimeValues.parseTime(_value)
          : null;
      return TimePickerDialog(
        helpText: label,
        initialTime: minutes == null
            ? TimeOfDay.now()
            : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      );
    }
    final first = _dateTimeLocalDate(_string(widget.node, 'minDate'));
    final last = _dateTimeLocalDate(_string(widget.node, 'maxDate'));
    if (widget.node.type == 'dateRangeField') {
      final range = valid && _value is Map
          ? MiniProgramDateTimeValues.parseDateRange(_value)
          : null;
      return DateRangePickerDialog(
        helpText: label,
        firstDate: first,
        lastDate: last,
        initialDateRange: range == null
            ? null
            : DateTimeRange(
                start: _dateTimeLocalDate(range['start']!),
                end: _dateTimeLocalDate(range['end']!),
              ),
      );
    }
    var initial = valid && _value is String && (_value as String).isNotEmpty
        ? _dateTimeLocalDate(_value as String)
        : DateUtils.dateOnly(DateTime.now());
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return DatePickerDialog(
      helpText: label,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final label = widget.bindings.resolveString(_string(widget.node, 'label'));
    final invalid = _dateTimeFieldError(
      widget.node,
      _value,
      checkRequired: false,
    );
    String? display;
    if (invalid == null && _value != null && _value != '') {
      if (widget.node.type == 'timeField') {
        final minutes = MiniProgramDateTimeValues.parseTime(_value);
        display = localizations.formatTimeOfDay(
          TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
      } else if (widget.node.type == 'dateRangeField') {
        final range = MiniProgramDateTimeValues.parseDateRange(_value);
        display =
            '${localizations.formatCompactDate(_dateTimeLocalDate(range['start']!))}'
            ' – ${localizations.formatCompactDate(_dateTimeLocalDate(range['end']!))}';
      } else {
        display = localizations.formatCompactDate(
          _dateTimeLocalDate(_value as String),
        );
      }
    }
    final enabled = _canInteract && _picker == null;
    final hint = widget.node.props['hint'] as String?;
    final placeholder = hint == null
        ? switch (widget.node.type) {
            'timeField' => localizations.timePickerDialHelpText,
            'dateRangeField' => localizations.dateRangePickerHelpText,
            _ => localizations.dateHelpText,
          }
        : widget.bindings.resolveString(hint);
    return _MpFieldFrame(
      label: label,
      error: _saveError ?? invalid ?? _form?.error(_name),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        value: display ?? '',
        onTap: enabled ? _startChoosing : null,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('mp-date-time-$_key'),
              onTap: enabled ? _startChoosing : null,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  enabled: enabled,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        display ?? placeholder,
                        style: TextStyle(
                          color: enabled && display != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.node.type == 'timeField'
                          ? Icons.access_time
                          : Icons.calendar_today,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _invalidatePicker();
    WidgetsBinding.instance.removeObserver(this);
    _watcher?.removeListener(_onStateChanged);
    _form?.removeListener(_onFormChanged);
    _form?.unregisterField(_name);
    super.dispose();
  }
}

bool _sameDateTimeValue(Object? a, Object? b) =>
    a is Map && b is Map ? mapEquals(a, b) : a == b;

String _dateTimeFieldIdentity(_MpNode node) => jsonEncode([
  node.type,
  for (final key in [
    'stateKey',
    'name',
    'initialValue',
    'minDate',
    'maxDate',
    'required',
    'enabled',
    'label',
    'hint',
  ])
    node.props[key],
  if (node.props['onChanged'] case final _MpAction action)
    _lazyActionKey(action),
]);

DateTime _dateTimeLocalDate(String value) {
  final date = MiniProgramDateTimeValues.parseDate(value);
  return DateTime(date.year, date.month, date.day);
}

String _dateTimeDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String? _dateTimeFieldError(
  _MpNode node,
  Object? value, {
  bool checkRequired = true,
}) {
  if (value == null || value == '') {
    return checkRequired && _bool(node, 'required')
        ? 'This field is required.'
        : null;
  }
  try {
    if (node.type == 'timeField') {
      MiniProgramDateTimeValues.parseTime(value);
    } else {
      final Iterable<Object?> dates = node.type == 'dateRangeField'
          ? MiniProgramDateTimeValues.parseDateRange(value).values
          : [value];
      for (final date in dates) {
        MiniProgramDateTimeValues.parseDate(date);
        if ((date as String).compareTo(_string(node, 'minDate')) < 0 ||
            date.compareTo(_string(node, 'maxDate')) > 0) {
          return 'Choose a date within the allowed range.';
        }
      }
    }
    return null;
  } on FormatException {
    return 'Choose a valid date or time.';
  }
}
