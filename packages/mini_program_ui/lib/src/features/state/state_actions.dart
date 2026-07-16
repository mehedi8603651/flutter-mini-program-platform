import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

/// Mini-program memory state action builders.
final class MpStateActions {
  /// Creates state action helpers.
  const MpStateActions();

  /// Creates or replaces [key] with [value].
  MpAction put(String key, Object? value) => MpAction(
    'state.put',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'value': value,
    },
  );

  /// Replaces [key] with [value].
  MpAction set(String key, Object? value) => MpAction(
    'state.set',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'value': value,
    },
  );

  /// Sets [value] only when [key] is missing or null.
  MpAction setDefault(String key, Object? value) => MpAction(
    'state.setDefault',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'value': value,
    },
  );

  /// Atomically writes and removes multiple state paths.
  MpAction patch(
    Map<String, Object?> values, {
    List<String> remove = const <String>[],
  }) {
    return MpAction('state.patch', props: _statePatchProps(values, remove));
  }

  /// Adds [by] to the numeric state value at [key].
  MpAction increment(
    String key, {
    Object by = 1,
    num defaultValue = 0,
    num? min,
    num? max,
  }) => MpAction(
    'state.increment',
    props: _stateNumberMutationProps(
      key: key,
      by: by,
      defaultValue: defaultValue,
      min: min,
      max: max,
    ),
  );

  /// Subtracts [by] from the numeric state value at [key].
  MpAction decrement(
    String key, {
    Object by = 1,
    num defaultValue = 0,
    num? min,
    num? max,
  }) => MpAction(
    'state.decrement',
    props: _stateNumberMutationProps(
      key: key,
      by: by,
      defaultValue: defaultValue,
      min: min,
      max: max,
    ),
  );

  /// Copies one state value to another with an optional scalar conversion.
  MpAction copy({
    required String from,
    required String to,
    String convertTo = 'value',
  }) => MpAction(
    'state.copy',
    props: <String, Object?>{
      'from': requiredStateKey(from, 'from'),
      'to': requiredStateKey(to, 'to'),
      'convertTo': allowedValue(convertTo, 'convertTo', const <String>{
        'value',
        'text',
        'number',
      }),
    },
  );

  /// Toggles a boolean state value, using [defaultValue] when it is unset.
  MpAction toggle(String key, {bool defaultValue = false}) => MpAction(
    'state.toggle',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      if (defaultValue) 'defaultValue': true,
    },
  );

  /// Appends [text] to a string state value.
  MpAction appendText(String key, String text, {int maxLength = 4096}) =>
      MpAction(
        'state.appendText',
        props: <String, Object?>{
          'key': requiredStateKey(key, 'key'),
          'text': text,
          'maxLength': boundedInt(
            maxLength,
            'maxLength',
            minimum: 1,
            maximum: 65536,
          ),
        },
      );

  /// Removes [count] Unicode code points from the end of a string state value.
  MpAction backspace(String key, {int count = 1}) => MpAction(
    'state.backspace',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'count': boundedInt(count, 'count', minimum: 1, maximum: 65536),
    },
  );

  /// Appends [value] to a list state value.
  MpAction listAppend(String key, Object? value, {int? maxItems}) => MpAction(
    'state.listAppend',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'value': value,
      if (maxItems != null)
        'maxItems': boundedInt(maxItems, 'maxItems', minimum: 1, maximum: 1000),
    },
  );

  /// Prepends [value] to a list state value.
  MpAction listPrepend(String key, Object? value, {int? maxItems}) => MpAction(
    'state.listPrepend',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'value': value,
      if (maxItems != null)
        'maxItems': boundedInt(maxItems, 'maxItems', minimum: 1, maximum: 1000),
    },
  );

  /// Inserts [value] at [index] in a list state value.
  MpAction listInsert(String key, Object index, Object? value) => MpAction(
    'state.listInsert',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'index': _integerOrBinding(index, 'index'),
      'value': value,
    },
  );

  /// Removes the item at [index] from a list state value.
  MpAction listRemoveAt(String key, Object index) => MpAction(
    'state.listRemoveAt',
    props: <String, Object?>{
      'key': requiredStateKey(key, 'key'),
      'index': _integerOrBinding(index, 'index'),
    },
  );

  /// Removes the first matching [value], or every match when [all] is true.
  MpAction listRemoveValue(String key, Object? value, {bool all = false}) =>
      MpAction(
        'state.listRemoveValue',
        props: <String, Object?>{
          'key': requiredStateKey(key, 'key'),
          'value': value,
          if (all) 'all': true,
        },
      );

  /// Removes [key] from memory state.
  MpAction remove(String key) => MpAction(
    'state.remove',
    props: <String, Object?>{'key': requiredStateKey(key, 'key')},
  );

  /// Clears all memory state for the current mini-program instance.
  MpAction clear() => MpAction('state.clear');
}

Map<String, Object?> _stateNumberMutationProps({
  required String key,
  required Object by,
  required num defaultValue,
  required num? min,
  required num? max,
}) {
  final normalizedDefault = finiteNumber(defaultValue, 'defaultValue');
  final normalizedMin = min == null ? null : finiteNumber(min, 'min');
  final normalizedMax = max == null ? null : finiteNumber(max, 'max');
  if (normalizedMin != null &&
      normalizedMax != null &&
      normalizedMin > normalizedMax) {
    throw ArgumentError.value(min, 'min', 'Value cannot be greater than max.');
  }
  return <String, Object?>{
    'key': requiredStateKey(key, 'key'),
    'by': _stateNumberOperand(by, 'by'),
    if (normalizedDefault != 0) 'defaultValue': normalizedDefault,
    if (normalizedMin != null) 'min': normalizedMin,
    if (normalizedMax != null) 'max': normalizedMax,
  };
}

Object _stateNumberOperand(Object value, String name) {
  if (value is num && value.isFinite || isFullBinding(value)) {
    return value;
  }
  throw ArgumentError.value(
    value,
    name,
    'Value must be a finite number or full binding.',
  );
}

Object _integerOrBinding(Object value, String name) {
  if (value is int || isFullBinding(value)) {
    return value;
  }
  throw ArgumentError.value(
    value,
    name,
    'Value must be an integer or binding.',
  );
}

Map<String, Object?> _statePatchProps(
  Map<String, Object?> values,
  List<String> remove,
) {
  if (values.isEmpty && remove.isEmpty) {
    throw ArgumentError('Mp.state.patch requires values or remove paths.');
  }
  final normalizedValues = <String, Object?>{
    for (final entry in values.entries)
      requiredStateKey(entry.key, 'values'): entry.value,
  };
  final normalizedRemove = remove
      .map((key) => requiredStateKey(key, 'remove'))
      .toList(growable: false);
  final paths = <String>[...normalizedValues.keys, ...normalizedRemove];
  for (var left = 0; left < paths.length; left += 1) {
    for (var right = left + 1; right < paths.length; right += 1) {
      if (_statePathsOverlap(paths[left], paths[right])) {
        throw ArgumentError.value(
          paths,
          'values',
          'Mp.state.patch paths cannot duplicate or overlap.',
        );
      }
    }
  }
  normalizedRemove.sort();
  return <String, Object?>{
    if (normalizedValues.isNotEmpty) 'values': normalizedValues,
    if (normalizedRemove.isNotEmpty) 'remove': normalizedRemove,
  };
}

bool _statePathsOverlap(String left, String right) {
  return left == right ||
      left.startsWith('$right.') ||
      right.startsWith('$left.');
}
