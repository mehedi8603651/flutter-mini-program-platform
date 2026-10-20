import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

/// Serializes a standalone app bar; placement belongs to the surrounding layout.
MpNode buildAppBarNode({
  required MpNode title,
  MpNode? leading,
  List<MpNode> actions = const <MpNode>[],
  String? backgroundColor,
  String? foregroundColor,
  String? shadowColor,
  bool centerTitle = false,
  num height = 64,
  num leadingWidth = 56,
  num paddingHorizontal = 12,
  num spacing = 8,
  num elevation = 0,
}) {
  if (actions.length > 4) {
    throw ArgumentError.value(actions, 'actions', 'Use at most four actions.');
  }
  return MpNode(
    'appBar',
    props: <String, Object?>{
      'hasLeading': leading != null,
      'actionCount': actions.length,
      'centerTitle': centerTitle,
      'height': _bounded(height, 'height', 48, 160),
      'leadingWidth': _bounded(leadingWidth, 'leadingWidth', 0, 256),
      'paddingHorizontal': _bounded(
        paddingHorizontal,
        'paddingHorizontal',
        0,
        48,
      ),
      'spacing': _bounded(spacing, 'spacing', 0, 24),
      'elevation': _bounded(elevation, 'elevation', 0, 24),
      if (backgroundColor != null)
        'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      if (foregroundColor != null)
        'foregroundColor': widgetColor(foregroundColor, 'foregroundColor'),
      if (shadowColor != null)
        'shadowColor': widgetColor(shadowColor, 'shadowColor'),
    },
    children: <MpNode>[if (leading != null) leading, title, ...actions],
  );
}

num _bounded(num value, String name, num minimum, num maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Use a finite number between $minimum and $maximum.',
    );
  }
  return value;
}
