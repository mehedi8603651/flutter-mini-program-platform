import '../mp_action.dart';
import '../mp_node.dart';
import 'widget_props.dart';

MpNode buildButtonNode({
  required String label,
  required MpAction action,
  required num height,
  required String backgroundColor,
  required String foregroundColor,
  required String borderColor,
  required num borderWidth,
  required num borderRadius,
  required num fontSize,
  required String fontWeight,
}) {
  return MpNode(
    'button',
    props: <String, Object?>{
      'action': action,
      'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      'borderColor': widgetColor(borderColor, 'borderColor'),
      'borderRadius': nonNegativeWidgetNumber(borderRadius, 'borderRadius'),
      'borderWidth': nonNegativeWidgetNumber(borderWidth, 'borderWidth'),
      'fontSize': positiveWidgetNumber(fontSize, 'fontSize'),
      'fontWeight': widgetTextWeight(fontWeight),
      'foregroundColor': widgetColor(foregroundColor, 'foregroundColor'),
      'height': positiveWidgetNumber(height, 'height'),
      'label': requiredWidgetString(label, 'label'),
    },
  );
}

MpNode buildIconButtonNode({
  required String name,
  required String semanticLabel,
  required MpAction action,
  required num size,
  required num iconSize,
  required String color,
  required String backgroundColor,
  required String borderColor,
  required num borderWidth,
  required num borderRadius,
}) {
  final normalizedSize = positiveWidgetNumber(size, 'size');
  final normalizedIconSize = positiveWidgetNumber(iconSize, 'iconSize');
  if (normalizedIconSize > normalizedSize) {
    throw ArgumentError.value(
      iconSize,
      'iconSize',
      'Icon size cannot exceed the button size.',
    );
  }
  return MpNode(
    'iconButton',
    props: <String, Object?>{
      'action': action,
      'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      'borderColor': widgetColor(borderColor, 'borderColor'),
      'borderRadius': nonNegativeWidgetNumber(borderRadius, 'borderRadius'),
      'borderWidth': nonNegativeWidgetNumber(borderWidth, 'borderWidth'),
      'color': widgetColor(color, 'color'),
      'iconSize': normalizedIconSize,
      'name': widgetIconName(name, 'name'),
      'semanticLabel': requiredWidgetString(semanticLabel, 'semanticLabel'),
      'size': normalizedSize,
    },
  );
}
