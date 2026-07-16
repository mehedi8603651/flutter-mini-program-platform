import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

MpNode buildListTileNode({
  required String title,
  String? subtitle,
  String? leadingIcon,
  String? trailingIcon,
  String? badge,
  MpAction? action,
}) {
  return MpNode(
    'listTile',
    props: <String, Object?>{
      if (action != null) 'action': action,
      if (badge != null) 'badge': requiredWidgetString(badge, 'badge'),
      if (leadingIcon != null)
        'leadingIcon': widgetIconName(leadingIcon, 'leadingIcon'),
      if (subtitle != null)
        'subtitle': requiredWidgetString(subtitle, 'subtitle'),
      'title': requiredWidgetString(title, 'title'),
      if (trailingIcon != null)
        'trailingIcon': widgetIconName(trailingIcon, 'trailingIcon'),
    },
  );
}
