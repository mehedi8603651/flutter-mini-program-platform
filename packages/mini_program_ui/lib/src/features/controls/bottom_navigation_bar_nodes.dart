import '../../core/mp_action.dart';
import '../../core/mp_json.dart';
import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

/// One destination in a standalone bottom navigation bar.
final class MpBottomNavigationItem implements MpJsonEncodable {
  const MpBottomNavigationItem({
    required this.icon,
    required this.label,
    required this.action,
    this.selectedIcon,
    this.enabled = true,
  });

  /// Supported icon name. Icons are literal, never bindings.
  final String icon;

  /// Visible and accessible label; supports existing text bindings.
  final String label;

  /// Existing action to run on selection, including reselection.
  final MpAction action;

  /// Optional supported icon used while selected.
  final String? selectedIcon;

  /// Whether the destination accepts taps.
  final bool enabled;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'icon': widgetIconName(icon, 'icon'),
    'label': _label(label),
    'action': action.toJson(),
    'enabled': enabled,
    if (selectedIcon != null)
      'selectedIcon': widgetIconName(selectedIcon!, 'selectedIcon'),
  };

  static String _label(String value) {
    final label = requiredWidgetString(value, 'label');
    if (label.length > 512) {
      throw ArgumentError.value(value, 'label', 'Use at most 512 characters.');
    }
    return label;
  }
}

MpNode buildBottomNavigationBarNode({
  required List<MpBottomNavigationItem> items,
  Object selectedIndex = 0,
  String labelBehavior = 'alwaysShow',
  num height = 80,
  num elevation = 0,
  String? backgroundColor,
  String? indicatorColor,
  String? selectedItemColor,
  String? unselectedItemColor,
}) {
  if (items.length < 2 || items.length > 5) {
    throw ArgumentError.value(items, 'items', 'Use from two to five items.');
  }
  final Object selection;
  if (selectedIndex is int &&
      selectedIndex >= 0 &&
      selectedIndex < items.length) {
    selection = selectedIndex;
  } else if (selectedIndex is String && selectedIndex.length <= 512) {
    selection = widgetBindingExpression(selectedIndex, 'selectedIndex');
  } else {
    throw ArgumentError.value(
      selectedIndex,
      'selectedIndex',
      'Use an item index or a full binding.',
    );
  }
  if (!const {
    'alwaysShow',
    'onlyShowSelected',
    'alwaysHide',
  }.contains(labelBehavior)) {
    throw ArgumentError.value(
      labelBehavior,
      'labelBehavior',
      'Invalid label behavior.',
    );
  }
  return MpNode(
    'bottomNavigationBar',
    props: <String, Object?>{
      'items': items,
      'selectedIndex': selection,
      'labelBehavior': labelBehavior,
      'height': _bounded(height, 'height', 64, 128),
      'elevation': _bounded(elevation, 'elevation', 0, 24),
      for (final entry in <String, String?>{
        'backgroundColor': backgroundColor,
        'indicatorColor': indicatorColor,
        'selectedItemColor': selectedItemColor,
        'unselectedItemColor': unselectedItemColor,
      }.entries)
        if (entry.value != null)
          entry.key: widgetColor(entry.value!, entry.key),
    },
  );
}

num _bounded(num value, String name, num minimum, num maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Use a finite number between $minimum and $maximum.',
    );
  }
  return value;
}
