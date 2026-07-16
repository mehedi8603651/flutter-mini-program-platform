part of '../../mp_screen_renderer.dart';

class _NoopListenable implements Listenable {
  const _NoopListenable();

  static const instance = _NoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

String _string(_MpNode node, String key) => node.props[key] as String;

bool _bool(_MpNode node, String key) => node.props[key] == true;

int _int(_MpNode node, String key, {required int fallback}) {
  return node.props[key] as int? ?? fallback;
}

Duration? _duration(_MpNode node, String key) {
  final seconds = node.props[key] as int?;
  return seconds == null ? null : Duration(seconds: seconds);
}

String? _optionalResolvedString(
  _MpNode node,
  _MpRenderBindings bindings,
  String key,
) {
  final value = node.props[key] as String?;
  return value == null ? null : bindings.resolveString(value);
}

double _double(_MpNode node, String key, {required double fallback}) {
  return (node.props[key] as num?)?.toDouble() ?? fallback;
}

double? _optionalDouble(_MpNode node, String key) {
  return (node.props[key] as num?)?.toDouble();
}

double _mapDouble(Map<String, dynamic>? map, String key) {
  return (map?[key] as num?)?.toDouble() ?? 0;
}
