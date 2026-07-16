part of '../../../mp_screen_renderer.dart';

String _initializeRuntimeKey(_MpInitialize widget) {
  final node = widget.node;
  final actions = node.props['actions'] as List<_MpAction>;
  return <String>[
    widget.bindings.screenId ?? '',
    (node.props['statusState'] as String?) ?? '',
    (node.props['errorState'] as String?) ?? '',
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    for (final action in actions) _lazyActionKey(action),
  ].join('|');
}
