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

MpNode buildAlignNode({required MpNode child, String alignment = 'center'}) {
  return MpNode(
    'align',
    props: <String, Object?>{'alignment': widgetAlignment(alignment)},
    children: <MpNode>[child],
  );
}

MpNode buildCenterNode({required MpNode child}) {
  return MpNode('center', children: <MpNode>[child]);
}

MpNode buildSpacerNode({int flex = 1}) {
  return MpNode(
    'spacer',
    props: <String, Object?>{'flex': positiveWidgetInt(flex, 'flex')},
  );
}

MpNode buildExpandedNode({required MpNode child, int flex = 1}) {
  return MpNode(
    'expanded',
    props: <String, Object?>{'flex': positiveWidgetInt(flex, 'flex')},
    children: <MpNode>[child],
  );
}

MpNode buildFlexibleNode({
  required MpNode child,
  int flex = 1,
  String fit = 'loose',
}) {
  return MpNode(
    'flexible',
    props: <String, Object?>{
      'fit': widgetFlexFit(fit),
      'flex': positiveWidgetInt(flex, 'flex'),
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

MpNode buildListViewNode({
  required List<MpNode> children,
  num spacing = 0,
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
    'listView',
    props: <String, Object?>{
      if (padding.isNotEmpty) 'padding': padding,
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
    },
    children: requiredWidgetList(children, 'children'),
  );
}

MpNode buildRepeatNode({
  required String source,
  required MpNode itemTemplate,
  MpNode? empty,
  MpNode? separator,
  num spacing = 0,
  int limit = 100,
}) {
  return MpNode(
    'repeat',
    props: <String, Object?>{
      if (empty != null) 'empty': empty,
      'itemTemplate': itemTemplate,
      'limit': repeatLimit(limit),
      if (separator != null) 'separator': separator,
      'source': widgetBindingExpression(source, 'source'),
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
    },
  );
}

MpNode buildSafeAreaNode({
  required MpNode child,
  bool left = true,
  bool top = true,
  bool right = true,
  bool bottom = true,
}) {
  return MpNode(
    'safeArea',
    props: <String, Object?>{
      'bottom': bottom,
      'left': left,
      'right': right,
      'top': top,
    },
    children: <MpNode>[child],
  );
}

MpNode buildVisibilityNode({
  required MpNode child,
  bool visible = true,
  bool maintainSize = false,
  bool maintainState = false,
}) {
  return MpNode(
    'visibility',
    props: <String, Object?>{
      'maintainSize': maintainSize,
      'maintainState': maintainState,
      'visible': visible,
    },
    children: <MpNode>[child],
  );
}

MpNode buildOpacityNode({
  required MpNode child,
  num opacity = 1,
  bool alwaysIncludeSemantics = false,
}) {
  return MpNode(
    'opacity',
    props: <String, Object?>{
      'alwaysIncludeSemantics': alwaysIncludeSemantics,
      'opacity': unitIntervalWidgetNumber(opacity, 'opacity'),
    },
    children: <MpNode>[child],
  );
}

MpNode buildAspectRatioNode({required MpNode child, required num aspectRatio}) {
  return MpNode(
    'aspectRatio',
    props: <String, Object?>{
      'aspectRatio': positiveWidgetNumber(aspectRatio, 'aspectRatio'),
    },
    children: <MpNode>[child],
  );
}

MpNode buildStackNode({
  required List<MpNode> children,
  String alignment = 'topLeft',
  bool clip = true,
}) {
  return MpNode(
    'stack',
    props: <String, Object?>{
      'alignment': widgetAlignment(alignment),
      'clip': clip,
    },
    children: requiredWidgetList(children, 'children'),
  );
}

MpNode buildPositionedNode({
  required MpNode child,
  num? left,
  num? top,
  num? right,
  num? bottom,
  num? width,
  num? height,
}) {
  return MpNode(
    'positioned',
    props: positionedConstraints(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
    ),
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
