part of '../../../mp_screen_renderer.dart';

typedef _MpFieldValidator = String? Function(Object? value);

class _MpFormController extends ChangeNotifier {
  _MpFormController({required this.id});

  final String id;
  final Map<String, Object?> _values = <String, Object?>{};
  final Map<String, String?> _errors = <String, String?>{};
  final Map<String, _MpFieldValidator> _validators =
      <String, _MpFieldValidator>{};
  bool _submitting = false;
  bool _disposed = false;

  Map<String, dynamic> get values => Map<String, dynamic>.from(_values);

  bool get submitting => _submitting;

  Object? value(String name) => _values[name];

  String? error(String name) => _errors[name];

  void registerField({
    required String name,
    required Object? initialValue,
    required _MpFieldValidator validator,
  }) {
    _validators[name] = validator;
    _values.putIfAbsent(name, () => initialValue);
    _errors.putIfAbsent(name, () => null);
  }

  void unregisterField(String name) {
    _validators.remove(name);
  }

  void setValue(String name, Object? value) {
    if (_values[name] == value) {
      return;
    }
    _values[name] = value;
    final validator = _validators[name];
    if (validator != null) {
      _errors[name] = validator(value);
    }
    _notifyIfActive();
  }

  bool validate() {
    var valid = true;
    for (final entry in _validators.entries) {
      final error = entry.value(_values[entry.key]);
      _errors[entry.key] = error;
      if (error != null) {
        valid = false;
      }
    }
    _notifyIfActive();
    return valid;
  }

  void setSubmitting(bool value) {
    if (_submitting == value) {
      return;
    }
    _submitting = value;
    _notifyIfActive();
  }

  Map<String, dynamic> toBindingData() {
    return <String, dynamic>{
      ...values,
      'id': id,
      'submitting': submitting,
      'valid': !_errors.values.any((error) => error != null),
      'errors': <String, String?>{..._errors},
    };
  }

  void _notifyIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _MpFormScope extends InheritedWidget {
  const _MpFormScope({required this.controller, required super.child});

  final _MpFormController controller;

  static _MpFormController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MpFormScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_MpFormScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}

String? _requiredTextValidator(
  Object? value, {
  required bool required,
  int? minLength,
  int? maxLength,
}) {
  final text = value?.toString() ?? '';
  if (required && text.trim().isEmpty) {
    return 'This field is required.';
  }
  if (!required && text.isEmpty) {
    return null;
  }
  if (minLength != null && text.length < minLength) {
    return 'Enter at least $minLength characters.';
  }
  if (maxLength != null && text.length > maxLength) {
    return 'Enter no more than $maxLength characters.';
  }
  return null;
}

String? _requiredChoiceValidator(Object? value, {required bool required}) {
  if (!required) {
    return null;
  }
  return value is String && value.trim().isNotEmpty
      ? null
      : 'Choose an option.';
}

String? _requiredTrueValidator(Object? value, {required bool requiredTrue}) {
  if (!requiredTrue) {
    return null;
  }
  return value == true ? null : 'This field is required.';
}
