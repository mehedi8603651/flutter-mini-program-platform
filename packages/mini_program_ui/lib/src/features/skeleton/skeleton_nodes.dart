import '../../core/mp_node.dart';
import 'skeleton_node_builders.dart';

enum MpSkeletonVariant {
  box('box'),
  text('text'),
  circle('circle'),
  card('card'),
  list('list');

  const MpSkeletonVariant(this.wireName);

  final String wireName;
}

final class MpSkeleton {
  const MpSkeleton();

  MpNode box({
    double? width,
    double? height,
    double radius = 8,
    String? colorToken,
  }) => buildSkeletonNode(
    variant: MpSkeletonVariant.box.wireName,
    width: width,
    height: height,
    radius: radius,
    colorToken: colorToken,
  );

  MpNode text({
    double? width,
    double height = 14,
    double radius = 4,
    String? colorToken,
  }) => buildSkeletonNode(
    variant: MpSkeletonVariant.text.wireName,
    width: width,
    height: height,
    radius: radius,
    colorToken: colorToken,
  );

  MpNode circle({required double size, String? colorToken}) =>
      buildSkeletonNode(
        variant: MpSkeletonVariant.circle.wireName,
        size: size,
        colorToken: colorToken,
      );

  MpNode card({
    double? width,
    double height = 160,
    double radius = 12,
    String? colorToken,
  }) => buildSkeletonNode(
    variant: MpSkeletonVariant.card.wireName,
    width: width,
    height: height,
    radius: radius,
    colorToken: colorToken,
  );

  MpNode list({
    int count = 3,
    double? width,
    double itemHeight = 72,
    double spacing = 12,
    double radius = 8,
    String? colorToken,
  }) => buildSkeletonNode(
    variant: MpSkeletonVariant.list.wireName,
    count: count,
    width: width,
    itemHeight: itemHeight,
    spacing: spacing,
    radius: radius,
    colorToken: colorToken,
  );
}
