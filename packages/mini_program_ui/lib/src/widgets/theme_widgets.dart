import '../mp_node.dart';
import 'widget_props.dart';

MpNode buildThemeNode({
  required MpNode child,
  Map<String, String>? colors,
  Map<String, Map<String, Object?>>? typography,
}) {
  final normalizedColors = _themeColors(colors);
  final normalizedTypography = _themeTypography(typography);
  return MpNode(
    'theme',
    props: <String, Object?>{
      if (normalizedColors.isNotEmpty) 'colors': normalizedColors,
      if (normalizedTypography.isNotEmpty) 'typography': normalizedTypography,
    },
    children: <MpNode>[child],
  );
}

Map<String, Object?> _themeColors(Map<String, String>? colors) {
  if (colors == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    for (final entry in colors.entries)
      themeTokenName(entry.key, 'colors.key'): widgetColor(
        entry.value,
        'colors.${entry.key}',
      ),
  };
}

Map<String, Object?> _themeTypography(
  Map<String, Map<String, Object?>>? typography,
) {
  if (typography == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    for (final entry in typography.entries)
      themeTokenName(entry.key, 'typography.key'): _themeTypographyStyle(
        entry.key,
        entry.value,
      ),
  };
}

Map<String, Object?> _themeTypographyStyle(
  String variant,
  Map<String, Object?> style,
) {
  final normalized = <String, Object?>{};
  for (final entry in style.entries) {
    switch (entry.key) {
      case 'size':
        final value = entry.value;
        if (value is! num) {
          throw ArgumentError.value(
            value,
            'typography.$variant.size',
            'Typography size must be numeric.',
          );
        }
        normalized['size'] = positiveWidgetNumber(
          value,
          'typography.$variant.size',
        );
        break;
      case 'weight':
        final value = entry.value;
        if (value is! String) {
          throw ArgumentError.value(
            value,
            'typography.$variant.weight',
            'Typography weight must be a string.',
          );
        }
        normalized['weight'] = widgetTextWeight(value);
        break;
      case 'lineHeight':
        final value = entry.value;
        if (value is! num) {
          throw ArgumentError.value(
            value,
            'typography.$variant.lineHeight',
            'Typography lineHeight must be numeric.',
          );
        }
        normalized['lineHeight'] = positiveWidgetNumber(
          value,
          'typography.$variant.lineHeight',
        );
        break;
      case 'color':
        final value = entry.value;
        if (value is! String) {
          throw ArgumentError.value(
            value,
            'typography.$variant.color',
            'Typography color must be a string.',
          );
        }
        normalized['color'] = themeTypographyColor(value);
        break;
      default:
        throw ArgumentError.value(
          entry.key,
          'typography.$variant',
          'Unsupported typography field.',
        );
    }
  }
  return normalized;
}
