import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';

/// Generic action composition helpers.
final class MpActionActions {
  /// Creates action composition helpers.
  const MpActionActions();

  /// Runs [steps] in order and stops when a step fails.
  MpAction sequence(List<MpAction> steps) => MpAction(
    'sequence',
    props: <String, Object?>{'steps': requiredActions(steps)},
  );

  /// Dispatches exactly one action branch from a boolean literal or binding.
  MpAction ifElse({
    required Object condition,
    required MpAction thenAction,
    required MpAction elseAction,
  }) => MpAction(
    'action.ifElse',
    props: <String, Object?>{
      'condition': _booleanOrBinding(condition, 'condition'),
      'then': thenAction,
      'else': elseAction,
    },
  );

  /// Runs the nearest scoped action registered under [name].
  MpAction call(String name) => MpAction(
    'action.call',
    props: <String, Object?>{'name': requiredActionName(name, 'name')},
  );
}

Object _booleanOrBinding(Object value, String name) {
  if (value is bool || isFullBinding(value)) {
    return value;
  }
  throw ArgumentError.value(
    value,
    name,
    'Value must be a boolean or full binding.',
  );
}
