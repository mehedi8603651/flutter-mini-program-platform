import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

MpNode buildListViewNode({
  required List<MpNode> children,
  String direction = 'vertical',
  num? height,
  num spacing = 0,
  num? paddingAll,
  num? paddingHorizontal,
  num? paddingVertical,
  num? paddingLeft,
  num? paddingTop,
  num? paddingRight,
  num? paddingBottom,
}) {
  final normalizedDirection = _collectionDirection(direction);
  final normalizedHeight = _collectionHeight(normalizedDirection, height);
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
      if (normalizedDirection != 'vertical') 'direction': normalizedDirection,
      if (normalizedHeight != null) 'height': normalizedHeight,
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
  String direction = 'vertical',
  num? height,
}) {
  final normalizedDirection = _collectionDirection(direction);
  final normalizedHeight = _collectionHeight(normalizedDirection, height);
  return MpNode(
    'repeat',
    props: <String, Object?>{
      if (empty != null) 'empty': empty,
      'itemTemplate': itemTemplate,
      'limit': repeatLimit(limit),
      if (separator != null) 'separator': separator,
      'source': widgetBindingExpression(source, 'source'),
      'spacing': nonNegativeWidgetNumber(spacing, 'spacing'),
      if (normalizedDirection != 'vertical') 'direction': normalizedDirection,
      if (normalizedHeight != null) 'height': normalizedHeight,
    },
  );
}

MpNode buildGridNode({
  required List<MpNode> children,
  int? columns,
  num? minItemWidth,
  int? maxColumns,
  num spacing = 8,
}) {
  if (minItemWidth == null && maxColumns != null) {
    throw ArgumentError(
      'Mp.grid maxColumns requires minItemWidth for adaptive layout.',
    );
  }
  if (minItemWidth != null && columns != null) {
    throw ArgumentError(
      'Mp.grid cannot combine fixed columns with minItemWidth.',
    );
  }
  final adaptive = minItemWidth != null;
  return MpNode(
    'grid',
    props: <String, Object?>{
      if (!adaptive) 'columns': gridColumnCount(columns ?? 2),
      if (adaptive) 'maxColumns': gridColumnCount(maxColumns ?? 6),
      if (adaptive)
        'minItemWidth': positiveWidgetNumber(minItemWidth, 'minItemWidth'),
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

String _collectionDirection(String value) {
  if (value != 'vertical' && value != 'horizontal') {
    throw ArgumentError.value(
      value,
      'direction',
      'Value must be vertical or horizontal.',
    );
  }
  return value;
}

num? _collectionHeight(String direction, num? height) {
  if (direction == 'horizontal' && height == null) {
    throw ArgumentError('Horizontal collections require a height.');
  }
  return height == null ? null : positiveWidgetNumber(height, 'height');
}
