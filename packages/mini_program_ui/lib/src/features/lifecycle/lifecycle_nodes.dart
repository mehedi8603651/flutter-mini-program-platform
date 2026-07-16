import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';

MpNode buildRefreshIndicatorNode({
  required MpAction action,
  required MpNode child,
  String? semanticsLabel,
}) => MpNode(
  'refreshIndicator',
  props: <String, Object?>{
    'action': action,
    if (semanticsLabel != null)
      'semanticsLabel': requiredAuthoringString(
        semanticsLabel,
        'semanticsLabel',
      ),
  },
  children: <MpNode>[child],
);

MpNode buildStateBuilderNode({
  required List<String> keys,
  required MpNode child,
}) => MpNode(
  'stateBuilder',
  props: <String, Object?>{'keys': requiredStateKeys(keys), 'child': child},
);

MpNode buildConditionNode({
  required Object condition,
  required MpNode whenTrue,
  MpNode? whenFalse,
}) => MpNode(
  'condition',
  props: <String, Object?>{
    'condition': _booleanOrBinding(condition, 'condition'),
    'whenTrue': whenTrue,
    if (whenFalse != null) 'whenFalse': whenFalse,
  },
);

MpNode buildInitializeNode({
  required List<MpAction> actions,
  required MpNode child,
  MpNode? loading,
  MpNode? error,
  String? statusState,
  String? errorState,
  int retry = 0,
  Duration retryDelay = const Duration(milliseconds: 300),
}) {
  if (actions.isEmpty) {
    throw ArgumentError.value(
      actions,
      'actions',
      'Mp.initialize requires at least one action.',
    );
  }
  final retryDelayMs = retryDelay.inMilliseconds;
  if (retry < 0 || retry > 10) {
    throw ArgumentError.value(retry, 'retry', 'Value must be from 0 to 10.');
  }
  if (retryDelayMs < 0 || retryDelayMs > 60000) {
    throw ArgumentError.value(
      retryDelay,
      'retryDelay',
      'Value must be from zero to 60 seconds.',
    );
  }
  return MpNode(
    'initialize',
    props: <String, Object?>{
      'actions': actions,
      if (loading != null) 'loading': loading,
      if (error != null) 'error': error,
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (retry != 0) 'retry': retry,
      if (retryDelayMs != 300) 'retryDelayMs': retryDelayMs,
    },
    children: <MpNode>[child],
  );
}

MpNode buildStateScopeNode({
  required String prefix,
  required MpNode child,
  bool clearOnDispose = true,
}) => MpNode(
  'stateScope',
  props: <String, Object?>{
    'prefix': requiredStateKey(prefix, 'prefix'),
    if (!clearOnDispose) 'clearOnDispose': false,
  },
  children: <MpNode>[child],
);

MpNode buildActionScopeNode({
  required Map<String, MpAction> actions,
  required MpNode child,
}) => MpNode(
  'actionScope',
  props: <String, Object?>{'actions': _actionDefinitions(actions)},
  children: <MpNode>[child],
);

Map<String, MpAction> _actionDefinitions(Map<String, MpAction> actions) {
  if (actions.isEmpty || actions.length > 64) {
    throw ArgumentError.value(
      actions,
      'actions',
      'Mp.actionScope requires from 1 to 64 actions.',
    );
  }
  return <String, MpAction>{
    for (final entry in actions.entries)
      requiredActionName(entry.key, 'actions'): entry.value,
  };
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
