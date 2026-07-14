import '../mp_node.dart';
import 'widget_props.dart';

MpNode buildLineChartNode({
  required String source,
  required String valueField,
  String? labelField,
  num height = 220,
  num? minY,
  num? maxY,
  String unit = '',
  String color = '#F4C430',
  num strokeWidth = 3,
  bool curved = true,
  bool showPoints = true,
  bool showGrid = true,
  bool showArea = true,
  int maxPoints = 200,
  String? semanticLabel,
  MpNode? empty,
}) {
  final normalizedHeight = _boundedNumber(
    height,
    'height',
    minimum: 80,
    maximum: 600,
  );
  final normalizedStrokeWidth = _boundedNumber(
    strokeWidth,
    'strokeWidth',
    minimum: 1,
    maximum: 12,
  );
  final normalizedMinY = _finiteOptionalNumber(minY, 'minY');
  final normalizedMaxY = _finiteOptionalNumber(maxY, 'maxY');
  if (normalizedMinY != null &&
      normalizedMaxY != null &&
      normalizedMinY >= normalizedMaxY) {
    throw ArgumentError('minY must be less than maxY.');
  }
  return MpNode(
    'lineChart',
    props: <String, Object?>{
      'source': widgetBindingExpression(source, 'source'),
      'valueField': _dottedField(valueField, 'valueField'),
      if (labelField != null)
        'labelField': _dottedField(labelField, 'labelField'),
      'height': normalizedHeight,
      if (normalizedMinY != null) 'minY': normalizedMinY,
      if (normalizedMaxY != null) 'maxY': normalizedMaxY,
      'unit': unit,
      'color': widgetColor(color, 'color'),
      'strokeWidth': normalizedStrokeWidth,
      'curved': curved,
      'showPoints': showPoints,
      'showGrid': showGrid,
      'showArea': showArea,
      'maxPoints': _boundedInt(
        maxPoints,
        'maxPoints',
        minimum: 2,
        maximum: 500,
      ),
      if (semanticLabel != null)
        'semanticLabel': requiredWidgetString(semanticLabel, 'semanticLabel'),
      if (empty != null) 'empty': empty,
    },
  );
}

num _boundedNumber(
  num value,
  String name, {
  required num minimum,
  required num maximum,
}) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be between $minimum and $maximum.',
    );
  }
  return value;
}

int _boundedInt(
  int value,
  String name, {
  required int minimum,
  required int maximum,
}) {
  if (value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be between $minimum and $maximum.',
    );
  }
  return value;
}

num? _finiteOptionalNumber(num? value, String name) {
  if (value != null && !value.isFinite) {
    throw ArgumentError.value(value, name, 'Value must be finite.');
  }
  return value;
}

String _dottedField(String value, String name) {
  final normalized = requiredWidgetString(value, name);
  if (!_dottedFieldPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be a dotted field path.',
    );
  }
  return normalized;
}

final RegExp _dottedFieldPattern = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$',
);
