import '../mp_action.dart';
import '../mp_node.dart';
import 'widget_props.dart';

MpNode buildIconNode(
  String name, {
  num size = 20,
  String? color,
  String? semanticLabel,
}) {
  return MpNode(
    'icon',
    props: <String, Object?>{
      if (color != null) 'color': widgetColor(color, 'color'),
      'name': widgetIconName(name, 'name'),
      if (semanticLabel != null)
        'semanticLabel': requiredWidgetString(semanticLabel, 'semanticLabel'),
      'size': nonNegativeWidgetNumber(size, 'size'),
    },
  );
}

MpNode buildChipNode({
  required String label,
  String tone = 'neutral',
  String? leadingIcon,
  MpAction? action,
}) {
  return MpNode(
    'chip',
    props: <String, Object?>{
      if (action != null) 'action': action,
      'label': requiredWidgetString(label, 'label'),
      if (leadingIcon != null)
        'leadingIcon': widgetIconName(leadingIcon, 'leadingIcon'),
      'tone': widgetTone(tone),
    },
  );
}

MpNode buildBadgeNode({required String label, String tone = 'info'}) {
  return MpNode(
    'badge',
    props: <String, Object?>{
      'label': requiredWidgetString(label, 'label'),
      'tone': widgetTone(tone),
    },
  );
}
