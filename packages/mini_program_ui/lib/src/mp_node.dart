import 'mp_json.dart';

/// Serializable Mp widget node.
final class MpNode implements MpJsonEncodable {
  /// Creates a serializable Mp widget node.
  MpNode(
    String type, {
    Map<String, Object?> props = const <String, Object?>{},
    List<MpNode> children = const <MpNode>[],
  }) : type = _normalizeType(type),
       props = Map<String, Object?>.unmodifiable(encodeMpMap(props)),
       children = List<MpNode>.unmodifiable(children);

  /// Stable node type, for example `column` or `primaryButton`.
  final String type;

  /// Serializable node properties.
  final Map<String, Object?> props;

  /// Child nodes rendered below this node.
  final List<MpNode> children;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'props': props,
    'children': children.map((child) => child.toJson()).toList(growable: false),
  };

  static String _normalizeType(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'type', 'Node type cannot be empty.');
    }
    return normalized;
  }
}
