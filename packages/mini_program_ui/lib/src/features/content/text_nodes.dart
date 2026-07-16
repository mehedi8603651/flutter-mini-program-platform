import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

MpNode buildTextNode(
  String data, {
  num? size,
  String? color,
  String weight = 'regular',
  String align = 'start',
  int? maxLines,
  String overflow = 'clip',
  bool softWrap = true,
  num? lineHeight,
  String textDirection = 'auto',
  String? locale,
  String? variant,
}) {
  return MpNode(
    'text',
    props: _textProps(
      data: data,
      defaultWeight: 'regular',
      size: size,
      color: color,
      weight: weight,
      align: align,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      lineHeight: lineHeight,
      textDirection: textDirection,
      locale: locale,
      variant: variant,
    ),
  );
}

MpNode buildHeadingNode(
  String data, {
  int level = 1,
  num? size,
  String? color,
  String weight = 'bold',
  String align = 'start',
  int? maxLines,
  String overflow = 'clip',
  bool softWrap = true,
  num? lineHeight,
  String textDirection = 'auto',
  String? locale,
  String? variant,
}) {
  final normalizedLevel = headingLevel(level);
  return MpNode(
    'heading',
    props: <String, Object?>{
      ..._textProps(
        data: data,
        defaultWeight: 'bold',
        size: size,
        color: color,
        weight: weight,
        align: align,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        lineHeight: lineHeight,
        textDirection: textDirection,
        locale: locale,
        variant: variant,
      ),
      if (normalizedLevel != 1) 'level': normalizedLevel,
    },
  );
}

Map<String, Object?> _textProps({
  required String data,
  required String defaultWeight,
  required num? size,
  required String? color,
  required String weight,
  required String align,
  required int? maxLines,
  required String overflow,
  required bool softWrap,
  required num? lineHeight,
  required String textDirection,
  required String? locale,
  required String? variant,
}) {
  final normalizedWeight = widgetTextWeight(weight);
  final normalizedAlign = widgetTextAlign(align);
  final normalizedOverflow = widgetTextOverflow(overflow);
  final normalizedDirection = widgetTextDirection(textDirection);
  return <String, Object?>{
    'data': requiredWidgetString(data, 'data'),
    if (normalizedAlign != 'start') 'align': normalizedAlign,
    if (color != null) 'color': widgetColor(color, 'color'),
    if (lineHeight != null)
      'lineHeight': positiveWidgetNumber(lineHeight, 'lineHeight'),
    if (locale != null) 'locale': widgetLocale(locale),
    if (maxLines != null) 'maxLines': positiveWidgetInt(maxLines, 'maxLines'),
    if (normalizedOverflow != 'clip') 'overflow': normalizedOverflow,
    if (size != null) 'size': positiveWidgetNumber(size, 'size'),
    if (!softWrap) 'softWrap': false,
    if (normalizedDirection != 'auto') 'textDirection': normalizedDirection,
    if (variant != null) 'variant': requiredWidgetString(variant, 'variant'),
    if (normalizedWeight != defaultWeight) 'weight': normalizedWeight,
  };
}
