import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

MpNode buildCardNode({required MpNode child}) {
  return MpNode('card', children: <MpNode>[child]);
}

MpNode buildAlertNode({
  required String title,
  String? message,
  String tone = 'info',
  String? icon,
}) {
  final normalizedTone = widgetTone(tone);
  return MpNode(
    'alert',
    props: <String, Object?>{
      'icon': widgetIconName(icon ?? _defaultAlertIcon(normalizedTone), 'icon'),
      if (message != null) 'message': requiredWidgetString(message, 'message'),
      'title': requiredWidgetString(title, 'title'),
      'tone': normalizedTone,
    },
  );
}

MpNode buildAvatarNode({
  String? imageUrl,
  String? initials,
  String? icon,
  num size = 40,
  String? semanticLabel,
}) {
  final sourceCount = <Object?>[
    imageUrl,
    initials,
    icon,
  ].where((value) => value != null).length;
  if (sourceCount != 1) {
    throw ArgumentError(
      'Provide exactly one of imageUrl, initials, or icon for Mp.avatar.',
    );
  }
  return MpNode(
    'avatar',
    props: <String, Object?>{
      if (icon != null) 'icon': widgetIconName(icon, 'icon'),
      if (imageUrl != null)
        'imageUrl': requiredWidgetString(imageUrl, 'imageUrl'),
      if (initials != null)
        'initials': requiredWidgetString(initials, 'initials'),
      if (semanticLabel != null)
        'semanticLabel': requiredWidgetString(semanticLabel, 'semanticLabel'),
      'size': positiveWidgetNumber(size, 'size'),
    },
  );
}

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

MpNode buildProgressNode({
  required num value,
  num max = 1,
  String? label,
  String tone = 'info',
}) {
  final normalizedValue = nonNegativeWidgetNumber(value, 'value');
  final normalizedMax = positiveWidgetNumber(max, 'max');
  if (normalizedValue > normalizedMax) {
    throw ArgumentError.value(
      value,
      'value',
      'Value must be less than or equal to max.',
    );
  }
  return MpNode(
    'progress',
    props: <String, Object?>{
      if (label != null) 'label': requiredWidgetString(label, 'label'),
      'max': normalizedMax,
      'tone': widgetTone(tone),
      'value': normalizedValue,
    },
  );
}

MpNode buildEmptyStateNode({
  required String title,
  String? message,
  String icon = 'info',
  String? actionLabel,
  MpAction? action,
}) {
  final normalizedActionLabel = pairedActionLabel(
    action: action,
    actionLabel: actionLabel,
    owner: 'emptyState',
  );
  return MpNode(
    'emptyState',
    props: <String, Object?>{
      if (action != null) 'action': action,
      if (normalizedActionLabel != null) 'actionLabel': normalizedActionLabel,
      'icon': widgetIconName(icon, 'icon'),
      if (message != null) 'message': requiredWidgetString(message, 'message'),
      'title': requiredWidgetString(title, 'title'),
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

String _defaultAlertIcon(String tone) {
  return switch (tone) {
    'success' => 'check',
    'warning' || 'danger' => 'warning',
    _ => 'info',
  };
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
