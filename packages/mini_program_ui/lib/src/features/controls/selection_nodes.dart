import '../../core/authoring_validation.dart';
import '../../core/mp_node.dart';
import '../forms/form_models.dart';

MpNode buildDropdownNode({
  required String name,
  required String label,
  required List<MpOption> options,
  String? hint,
  String? initialValue,
  bool required = false,
}) {
  final normalizedOptions = _requiredOptions(options);
  final normalizedInitialValue = initialValue == null
      ? null
      : requiredAuthoringString(initialValue, 'initialValue');
  _validateInitialOptionValue(normalizedOptions, normalizedInitialValue);
  return MpNode(
    'dropdown',
    props: <String, Object?>{
      'name': requiredAuthoringString(name, 'name'),
      'label': requiredAuthoringString(label, 'label'),
      if (hint != null) 'hint': requiredAuthoringString(hint, 'hint'),
      'options': normalizedOptions,
      if (normalizedInitialValue != null)
        'initialValue': normalizedInitialValue,
      if (required) 'required': true,
    },
  );
}

MpNode buildCheckboxNode({
  required String name,
  required String label,
  bool initialValue = false,
  bool requiredTrue = false,
}) => MpNode(
  'checkbox',
  props: <String, Object?>{
    'name': requiredAuthoringString(name, 'name'),
    'label': requiredAuthoringString(label, 'label'),
    if (initialValue) 'initialValue': true,
    if (requiredTrue) 'requiredTrue': true,
  },
);

MpNode buildRadioGroupNode({
  required String name,
  required String label,
  required List<MpOption> options,
  String? initialValue,
  bool required = false,
}) {
  final normalizedOptions = _requiredOptions(options);
  final normalizedInitialValue = initialValue == null
      ? null
      : requiredAuthoringString(initialValue, 'initialValue');
  _validateInitialOptionValue(normalizedOptions, normalizedInitialValue);
  return MpNode(
    'radioGroup',
    props: <String, Object?>{
      'name': requiredAuthoringString(name, 'name'),
      'label': requiredAuthoringString(label, 'label'),
      'options': normalizedOptions,
      if (normalizedInitialValue != null)
        'initialValue': normalizedInitialValue,
      if (required) 'required': true,
    },
  );
}

List<MpOption> _requiredOptions(List<MpOption> options) {
  if (options.isEmpty) {
    throw ArgumentError.value(options, 'options', 'Options cannot be empty.');
  }
  final values = <String>{};
  for (final option in options) {
    final value = requiredAuthoringString(option.value, 'option.value');
    requiredAuthoringString(option.label, 'option.label');
    if (!values.add(value)) {
      throw ArgumentError.value(
        value,
        'option.value',
        'Option values must be unique.',
      );
    }
  }
  return options;
}

void _validateInitialOptionValue(List<MpOption> options, String? value) {
  if (value == null) {
    return;
  }
  if (!options.any((option) => option.value == value)) {
    throw ArgumentError.value(
      value,
      'initialValue',
      'Value must match one option value.',
    );
  }
}
