import 'mp_json.dart';

/// Serializable action descriptor used by Mp widgets.
final class MpAction implements MpJsonEncodable {
  /// Creates a serializable action descriptor.
  MpAction(
    String type, {
    Map<String, Object?> props = const <String, Object?>{},
  }) : type = _normalizeType(type),
       props = Map<String, Object?>.unmodifiable(encodeMpMap(props));

  /// Stable action type, for example `auth.showEmailAuth`.
  final String type;

  /// Serializable action properties.
  final Map<String, Object?> props;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'props': props,
  };

  static String _normalizeType(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'type', 'Action type cannot be empty.');
    }
    return normalized;
  }
}
