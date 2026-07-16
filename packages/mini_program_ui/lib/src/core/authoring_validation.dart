import 'mp_action.dart';
import 'mp_node.dart';

final RegExp _stateKeyPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);
final RegExp _fieldNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
final RegExp _actionNamePattern = RegExp(r'^[a-z][a-zA-Z0-9_]{0,63}$');

const Set<String> _blockedStateSegments = <String>{
  'authorization',
  'credential',
  'idtoken',
  'password',
  'refreshtoken',
  'secret',
  'token',
};

String requiredAuthoringString(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Value cannot be empty.');
  }
  return trimmed;
}

String stableAuthoringString(String value, String name) {
  final stable = requiredAuthoringString(value, name);
  if (stable.contains('{{') || stable.contains('}}')) {
    throw ArgumentError.value(value, name, 'Value cannot contain bindings.');
  }
  return stable;
}

String requiredActionName(String value, String name) {
  final normalized = stableAuthoringString(value, name);
  if (!_actionNamePattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Action names must start with a lowercase letter and contain only letters, numbers, or underscores.',
    );
  }
  return normalized;
}

String requiredFieldName(String value, String name) {
  final normalized = requiredAuthoringString(value, name);
  if (!_fieldNamePattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must match ^[a-z][a-z0-9_]*\$.',
    );
  }
  return normalized;
}

String requiredStateKey(String value, String name) {
  final normalized = requiredAuthoringString(value, name);
  if (!_stateKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Mp state keys must be lowercase dot paths.',
    );
  }
  for (final segment in normalized.split('.')) {
    final compact = segment.replaceAll('_', '').toLowerCase();
    if (_blockedStateSegments.contains(compact)) {
      throw ArgumentError.value(
        value,
        name,
        'Mp state keys cannot contain secret-like segments.',
      );
    }
  }
  return normalized;
}

List<String> requiredStateKeys(List<String> keys) {
  if (keys.isEmpty) {
    throw ArgumentError.value(keys, 'keys', 'State keys cannot be empty.');
  }
  return keys
      .map((key) => requiredStateKey(key, 'key'))
      .toList(growable: false);
}

List<MpNode> requiredChildren(List<MpNode> children, String name) {
  if (children.isEmpty) {
    throw ArgumentError.value(children, name, 'Children cannot be empty.');
  }
  return children;
}

List<MpAction> requiredActions(List<MpAction> actions) {
  if (actions.isEmpty) {
    throw ArgumentError.value(actions, 'steps', 'Actions cannot be empty.');
  }
  return actions;
}
