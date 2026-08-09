import '../../core/authoring_validation.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';

/// Display behavior that is active only while its child remains mounted.
final class MpDisplay {
  const MpDisplay();

  /// Temporarily overrides host-window brightness for [child].
  ///
  /// The host may deny or clamp the requested [level]. The runtime restores
  /// the host setting automatically when this node unmounts or the app leaves
  /// the foreground.
  MpNode brightnessScope({
    required MpNode child,
    num level = 1,
    String? statusState,
    String? errorState,
  }) => buildBrightnessScopeNode(
    child: child,
    level: level,
    statusState: statusState,
    errorState: errorState,
  );
}

MpNode buildBrightnessScopeNode({
  required MpNode child,
  num level = 1,
  String? statusState,
  String? errorState,
}) {
  final normalizedLevel = finiteNumber(level, 'level').toDouble();
  if (normalizedLevel <= 0 || normalizedLevel > 1) {
    throw ArgumentError.value(
      level,
      'level',
      'Value must be over 0 and at most 1.',
    );
  }
  return MpNode(
    'brightnessScope',
    props: <String, Object?>{
      'level': normalizedLevel,
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
    },
    children: <MpNode>[child],
  );
}
