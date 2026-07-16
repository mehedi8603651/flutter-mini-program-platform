part of '../../../mp_screen_renderer.dart';

Never _unsupportedNode(String type, {required String path}) {
  _fail(
    'Unsupported Mp node type "$type".',
    path: '$path.type',
    details: <String, dynamic>{'nodeType': type},
  );
}

Never _unsupportedAction(String type, {required String path}) {
  _fail(
    'Unsupported Mp action type "$type".',
    path: '$path.type',
    details: <String, dynamic>{'actionType': type},
  );
}

Never _fail(
  String message, {
  required String path,
  Map<String, dynamic> details = const <String, dynamic>{},
}) {
  throw MiniProgramRenderException(
    message: 'Invalid Mp screen JSON: $message',
    details: <String, dynamic>{'path': path, ...details},
  );
}
