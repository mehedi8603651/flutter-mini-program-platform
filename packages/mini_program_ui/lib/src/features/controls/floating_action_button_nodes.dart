import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

/// Standalone floating action buttons positioned by the surrounding layout.
///
/// The default, [small], and [large] variants require an icon and accessible
/// description. [extended] displays a label and optionally an icon. These
/// helpers serialize JSON only; they do not import a rendering framework.
class MpFloatingActionButton {
  const MpFloatingActionButton();

  /// Creates a standard icon button.
  MpNode call({
    required String icon,
    required String semanticLabel,
    required MpAction action,
    bool enabled = true,
    String? backgroundColor,
    String? foregroundColor,
  }) => _build(
    variant: 'standard',
    icon: icon,
    semanticLabel: semanticLabel,
    action: action,
    enabled: enabled,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
  );

  /// Creates a small icon button.
  MpNode small({
    required String icon,
    required String semanticLabel,
    required MpAction action,
    bool enabled = true,
    String? backgroundColor,
    String? foregroundColor,
  }) => _build(
    variant: 'small',
    icon: icon,
    semanticLabel: semanticLabel,
    action: action,
    enabled: enabled,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
  );

  /// Creates a large icon button.
  MpNode large({
    required String icon,
    required String semanticLabel,
    required MpAction action,
    bool enabled = true,
    String? backgroundColor,
    String? foregroundColor,
  }) => _build(
    variant: 'large',
    icon: icon,
    semanticLabel: semanticLabel,
    action: action,
    enabled: enabled,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
  );

  /// Creates a text button with an optional icon.
  ///
  /// [semanticLabel] defaults to [label]. Text may use existing runtime
  /// bindings; wrap the button in a state builder for reactive state labels.
  MpNode extended({
    required String label,
    required MpAction action,
    String? icon,
    String? semanticLabel,
    bool enabled = true,
    String? backgroundColor,
    String? foregroundColor,
  }) => _build(
    variant: 'extended',
    icon: icon,
    label: label,
    semanticLabel: semanticLabel ?? label,
    action: action,
    enabled: enabled,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
  );

  static MpNode _build({
    required String variant,
    required String semanticLabel,
    required MpAction action,
    required bool enabled,
    String? icon,
    String? label,
    String? backgroundColor,
    String? foregroundColor,
  }) => MpNode(
    'floatingActionButton',
    props: <String, Object?>{
      'variant': variant,
      if (icon != null) 'icon': widgetIconName(icon, 'icon'),
      if (label != null) 'label': _text(label, 'label'),
      'semanticLabel': _text(semanticLabel, 'semanticLabel'),
      'action': action,
      'enabled': enabled,
      if (backgroundColor != null)
        'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
      if (foregroundColor != null)
        'foregroundColor': widgetColor(foregroundColor, 'foregroundColor'),
    },
  );

  static String _text(String value, String name) {
    final text = requiredWidgetString(value, name);
    if (text.length > 512) {
      throw ArgumentError.value(value, name, 'Use at most 512 characters.');
    }
    return text;
  }
}
