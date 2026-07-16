import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

MpNode buildSkeletonNode({
  required String variant,
  num? width,
  num? height,
  num? radius,
  num? size,
  int? count,
  num? itemHeight,
  num? spacing,
  String? colorToken,
}) {
  final props = <String, Object?>{'variant': variant};
  switch (variant) {
    case 'box':
      props.addAll(<String, Object?>{
        'radius': nonNegativeWidgetNumber(radius ?? 8, 'radius'),
        if (height != null) 'height': positiveWidgetNumber(height, 'height'),
        if (width != null) 'width': positiveWidgetNumber(width, 'width'),
      });
      break;
    case 'text':
      props.addAll(<String, Object?>{
        'height': positiveWidgetNumber(height ?? 14, 'height'),
        'radius': nonNegativeWidgetNumber(radius ?? 4, 'radius'),
        if (width != null) 'width': positiveWidgetNumber(width, 'width'),
      });
      break;
    case 'circle':
      if (size == null) {
        throw ArgumentError.value(size, 'size', 'Size is required.');
      }
      props['size'] = positiveWidgetNumber(size, 'size');
      break;
    case 'card':
      props.addAll(<String, Object?>{
        'height': positiveWidgetNumber(height ?? 160, 'height'),
        'radius': nonNegativeWidgetNumber(radius ?? 12, 'radius'),
        if (width != null) 'width': positiveWidgetNumber(width, 'width'),
      });
      break;
    case 'list':
      props.addAll(<String, Object?>{
        'count': positiveWidgetInt(count ?? 3, 'count'),
        'itemHeight': positiveWidgetNumber(itemHeight ?? 72, 'itemHeight'),
        'radius': nonNegativeWidgetNumber(radius ?? 8, 'radius'),
        'spacing': nonNegativeWidgetNumber(spacing ?? 12, 'spacing'),
        if (width != null) 'width': positiveWidgetNumber(width, 'width'),
      });
      break;
    default:
      throw ArgumentError.value(
        variant,
        'variant',
        'Unsupported skeleton variant.',
      );
  }
  if (colorToken != null) {
    props['colorToken'] = themeTokenName(colorToken, 'colorToken');
  }
  return MpNode('skeleton', props: props);
}
