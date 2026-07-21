import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';
import '../shared/presentation_validation.dart';

MpNode buildStateTextFieldNode({
  required String stateKey,
  String? label,
  String? hint,
  String initialValue = '',
  int maxLength = 4096,
  int minLines = 1,
  int maxLines = 1,
  String keyboardType = 'text',
  String textInputAction = 'done',
  bool autofocus = false,
  Duration debounce = Duration.zero,
  MpAction? onChanged,
  MpAction? onSubmitted,
  String textColor = '#FF111827',
  String hintColor = '#FF6B7280',
  String cursorColor = '#FF0B7A75',
  String backgroundColor = '#FFFFFFFF',
  String borderColor = '#FFD1D5DB',
  String focusedBorderColor = '#FF0B7A75',
  num borderWidth = 1,
  num borderRadius = 8,
  num fontSize = 15,
  num paddingHorizontal = 12,
  num paddingVertical = 10,
}) {
  if (initialValue.length > maxLength) {
    throw ArgumentError.value(
      initialValue,
      'initialValue',
      'Value cannot exceed maxLength.',
    );
  }
  final normalizedMinLines = boundedInt(
    minLines,
    'minLines',
    minimum: 1,
    maximum: 100,
  );
  final normalizedMaxLines = boundedInt(
    maxLines,
    'maxLines',
    minimum: 1,
    maximum: 100,
  );
  if (normalizedMaxLines < normalizedMinLines) {
    throw ArgumentError.value(
      maxLines,
      'maxLines',
      'Value must be greater than or equal to minLines.',
    );
  }
  final debounceMs = debounce.inMilliseconds;
  if (debounceMs < 0 || debounceMs > 60000) {
    throw ArgumentError.value(
      debounce,
      'debounce',
      'Value must be between 0 and 60 seconds.',
    );
  }
  return MpNode(
    'stateTextField',
    props: <String, Object?>{
      'stateKey': requiredStateKey(stateKey, 'stateKey'),
      if (label != null) 'label': requiredAuthoringString(label, 'label'),
      if (hint != null) 'hint': requiredAuthoringString(hint, 'hint'),
      'initialValue': initialValue,
      'maxLength': boundedInt(
        maxLength,
        'maxLength',
        minimum: 1,
        maximum: 65536,
      ),
      'minLines': normalizedMinLines,
      'maxLines': normalizedMaxLines,
      'keyboardType': allowedValue(keyboardType, 'keyboardType', const <String>{
        'text',
        'multiline',
        'email',
        'number',
        'phone',
        'url',
      }),
      'textInputAction': allowedValue(
        textInputAction,
        'textInputAction',
        const <String>{'done', 'next', 'newline'},
      ),
      'autofocus': autofocus,
      'debounceMs': debounceMs,
      if (onChanged != null) 'onChanged': onChanged,
      if (onSubmitted != null) 'onSubmitted': onSubmitted,
      'textColor': widgetColor(textColor, 'textColor'),
      'hintColor': widgetColor(hintColor, 'hintColor'),
      'cursorColor': widgetColor(cursorColor, 'cursorColor'),
      'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      'borderColor': widgetColor(borderColor, 'borderColor'),
      'focusedBorderColor': widgetColor(
        focusedBorderColor,
        'focusedBorderColor',
      ),
      'borderWidth': nonNegativeWidgetNumber(borderWidth, 'borderWidth'),
      'borderRadius': nonNegativeWidgetNumber(borderRadius, 'borderRadius'),
      'fontSize': positiveWidgetNumber(fontSize, 'fontSize'),
      'paddingHorizontal': nonNegativeWidgetNumber(
        paddingHorizontal,
        'paddingHorizontal',
      ),
      'paddingVertical': nonNegativeWidgetNumber(
        paddingVertical,
        'paddingVertical',
      ),
    },
  );
}

MpNode buildSearchFieldNode({
  required String stateKey,
  String label = 'Search',
  String? hint,
  String initialValue = '',
  int maxLength = 256,
  Duration debounce = const Duration(milliseconds: 300),
  MpAction? onChanged,
  MpAction? onSubmitted,
  bool showClearButton = true,
}) {
  final debounceMs = debounce.inMilliseconds;
  if (debounceMs < 0 || debounceMs > 60000) {
    throw ArgumentError.value(
      debounce,
      'debounce',
      'Value must be between 0 and 60 seconds.',
    );
  }
  if (initialValue.length > maxLength) {
    throw ArgumentError.value(
      initialValue,
      'initialValue',
      'Value cannot exceed maxLength.',
    );
  }
  return MpNode(
    'searchField',
    props: <String, Object?>{
      'stateKey': requiredStateKey(stateKey, 'stateKey'),
      'label': requiredAuthoringString(label, 'label'),
      if (hint != null) 'hint': requiredAuthoringString(hint, 'hint'),
      'initialValue': initialValue,
      'maxLength': boundedInt(maxLength, 'maxLength', minimum: 1, maximum: 256),
      'debounceMs': debounceMs,
      if (onChanged != null) 'onChanged': onChanged,
      if (onSubmitted != null) 'onSubmitted': onSubmitted,
      'showClearButton': showClearButton,
    },
  );
}

MpNode buildTextInputNode({
  required String name,
  required String label,
  String? hint,
  String? initialValue,
  bool required = false,
  int? minLength,
  int? maxLength,
  bool obscureText = false,
  String keyboardType = 'text',
}) {
  return MpNode(
    'textInput',
    props: _inputProps(
      name: name,
      label: label,
      hint: hint,
      initialValue: initialValue,
      required: required,
      minLength: minLength,
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: keyboardType,
    ),
  );
}

MpNode buildTextAreaNode({
  required String name,
  required String label,
  String? hint,
  String? initialValue,
  bool required = false,
  int? minLength,
  int? maxLength,
  int minLines = 3,
  int maxLines = 6,
}) {
  if (minLines <= 0) {
    throw ArgumentError.value(minLines, 'minLines', 'Value must be positive.');
  }
  if (maxLines < minLines) {
    throw ArgumentError.value(
      maxLines,
      'maxLines',
      'Value must be greater than or equal to minLines.',
    );
  }
  return MpNode(
    'textArea',
    props: <String, Object?>{
      ..._inputProps(
        name: name,
        label: label,
        hint: hint,
        initialValue: initialValue,
        required: required,
        minLength: minLength,
        maxLength: maxLength,
        includeKeyboardType: false,
      ),
      'minLines': minLines,
      'maxLines': maxLines,
    },
  );
}

MpNode buildFormNode({String id = 'form', required List<MpNode> children}) {
  return MpNode(
    'form',
    props: <String, Object?>{'id': requiredAuthoringString(id, 'id')},
    children: requiredChildren(children, 'children'),
  );
}

MpNode buildFormSubmitNode({
  required String label,
  required String endpoint,
  String? requestId,
  String method = 'POST',
  Map<String, Object?> body = const <String, Object?>{},
  int? cacheTtlSeconds,
  MpAction? onSuccess,
  MpAction? onError,
}) => MpNode(
  'formSubmit',
  props: <String, Object?>{
    'label': requiredAuthoringString(label, 'label'),
    'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
    if (requestId != null)
      'requestId': requiredAuthoringString(requestId, 'requestId'),
    'method': requiredAuthoringString(method, 'method'),
    if (body.isNotEmpty) 'body': body,
    if (cacheTtlSeconds != null)
      'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    if (onSuccess != null) 'onSuccess': onSuccess,
    if (onError != null) 'onError': onError,
  },
);

Map<String, Object?> _inputProps({
  required String name,
  required String label,
  String? hint,
  String? initialValue,
  bool required = false,
  int? minLength,
  int? maxLength,
  bool obscureText = false,
  String keyboardType = 'text',
  bool includeKeyboardType = true,
}) {
  if (minLength != null && minLength < 0) {
    throw ArgumentError.value(
      minLength,
      'minLength',
      'Value cannot be negative.',
    );
  }
  if (maxLength != null && maxLength <= 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'Value must be positive.',
    );
  }
  if (minLength != null && maxLength != null && minLength > maxLength) {
    throw ArgumentError.value(
      minLength,
      'minLength',
      'Value must be less than or equal to maxLength.',
    );
  }
  return <String, Object?>{
    'name': requiredAuthoringString(name, 'name'),
    'label': requiredAuthoringString(label, 'label'),
    if (hint != null) 'hint': requiredAuthoringString(hint, 'hint'),
    if (initialValue != null) 'initialValue': initialValue,
    if (required) 'required': true,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
    if (includeKeyboardType && obscureText) 'obscureText': true,
    if (includeKeyboardType)
      'keyboardType': requiredAuthoringString(keyboardType, 'keyboardType'),
  };
}
