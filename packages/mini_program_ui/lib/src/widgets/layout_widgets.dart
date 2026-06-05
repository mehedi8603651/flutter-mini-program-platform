import '../mp_node.dart';
import '../mp_action.dart';
import 'widget_props.dart';

MpNode buildPaddingNode({
  required MpNode child,
  num? all,
  num? horizontal,
  num? vertical,
  num? left,
  num? top,
  num? right,
  num? bottom,
}) {
  return MpNode(
    'padding',
    props: <String, Object?>{
      'padding': widgetSpacing(
        all: all,
        horizontal: horizontal,
        vertical: vertical,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
    },
    children: <MpNode>[child],
  );
}

MpNode buildContainerNode({
  required MpNode child,
  num? width,
  num? height,
  num? paddingAll,
  num? paddingHorizontal,
  num? paddingVertical,
  num? paddingLeft,
  num? paddingTop,
  num? paddingRight,
  num? paddingBottom,
  String? backgroundColor,
  String? borderColor,
  num? borderWidth,
  num? borderRadius,
}) {
  final padding = widgetSpacing(
    all: paddingAll,
    horizontal: paddingHorizontal,
    vertical: paddingVertical,
    left: paddingLeft,
    top: paddingTop,
    right: paddingRight,
    bottom: paddingBottom,
  );
  return MpNode(
    'container',
    props: <String, Object?>{
      if (backgroundColor != null)
        'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      if (borderColor != null)
        'borderColor': widgetColor(borderColor, 'borderColor'),
      if (borderRadius != null)
        'borderRadius': nonNegativeWidgetNumber(borderRadius, 'borderRadius'),
      if (borderWidth != null)
        'borderWidth': nonNegativeWidgetNumber(borderWidth, 'borderWidth'),
      if (height != null) 'height': nonNegativeWidgetNumber(height, 'height'),
      if (padding.isNotEmpty) 'padding': padding,
      if (width != null) 'width': nonNegativeWidgetNumber(width, 'width'),
    },
    children: <MpNode>[child],
  );
}

MpNode buildScrollViewNode({
  required MpNode child,
  num? paddingAll,
  num? paddingHorizontal,
  num? paddingVertical,
  num? paddingLeft,
  num? paddingTop,
  num? paddingRight,
  num? paddingBottom,
}) {
  final padding = widgetSpacing(
    all: paddingAll,
    horizontal: paddingHorizontal,
    vertical: paddingVertical,
    left: paddingLeft,
    top: paddingTop,
    right: paddingRight,
    bottom: paddingBottom,
  );
  return MpNode(
    'scrollView',
    props: <String, Object?>{if (padding.isNotEmpty) 'padding': padding},
    children: <MpNode>[child],
  );
}

MpNode buildDividerNode({
  num thickness = 1,
  num spacing = 12,
  String color = '#E5E7EB',
}) {
  return MpNode(
    'divider',
    props: <String, Object?>{
      'color': widgetColor(color, 'color'),
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
      'thickness': nonNegativeWidgetNumber(thickness, 'thickness'),
    },
  );
}

MpNode buildGridNode({
  required List<MpNode> children,
  int columns = 2,
  num spacing = 8,
}) {
  return MpNode(
    'grid',
    props: <String, Object?>{
      'columns': gridColumnCount(columns),
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
    },
    children: requiredWidgetList(children, 'children'),
  );
}

MpNode buildWrapNode({
  required List<MpNode> children,
  num spacing = 8,
  num runSpacing = 8,
}) {
  return MpNode(
    'wrap',
    props: <String, Object?>{
      'runSpacing': nonNegativeWidgetNumber(runSpacing, 'runSpacing'),
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
    },
    children: requiredWidgetList(children, 'children'),
  );
}

MpNode buildSectionNode({
  required String title,
  String? subtitle,
  required MpNode child,
  String? actionLabel,
  MpAction? action,
}) {
  final normalizedActionLabel = pairedActionLabel(
    action: action,
    actionLabel: actionLabel,
    owner: 'section',
  );
  return MpNode(
    'section',
    props: <String, Object?>{
      if (action != null) 'action': action,
      if (normalizedActionLabel != null) 'actionLabel': normalizedActionLabel,
      if (subtitle != null)
        'subtitle': requiredWidgetString(subtitle, 'subtitle'),
      'title': requiredWidgetString(title, 'title'),
    },
    children: <MpNode>[child],
  );
}
