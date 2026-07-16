part of '../../../mp_screen_renderer.dart';

void _validateObjectKeys(
  Map<String, dynamic> json,
  Set<String> allowedKeys, {
  required String path,
}) {
  final unknownKeys = json.keys.where((key) => !allowedKeys.contains(key));
  if (unknownKeys.isNotEmpty) {
    _fail(
      'Mp JSON contains unsupported field(s): ${unknownKeys.join(', ')}.',
      path: path,
      details: <String, dynamic>{'unsupportedFields': unknownKeys.toList()},
    );
  }
}

void _validateNoProps(Map<String, dynamic> props, {required String path}) {
  if (props.isNotEmpty) {
    _fail('This Mp node or action does not support props.', path: path);
  }
}

void _validateNoChildren(List<_MpNode> children, {required String path}) {
  if (children.isNotEmpty) {
    _fail('This Mp node does not support children.', path: path);
  }
}

void _validateSingleChild(
  List<_MpNode> children, {
  required String nodeType,
  required String path,
}) {
  if (children.length != 1) {
    _fail('Mp $nodeType requires exactly one child.', path: '$path.children');
  }
}

void _validateNonEmptyChildren(
  List<_MpNode> children, {
  required String nodeType,
  required String path,
}) {
  if (children.isEmpty) {
    _fail('Mp $nodeType requires at least one child.', path: '$path.children');
  }
}

void _validateAvatarSource(Map<String, dynamic> props, {required String path}) {
  final sourceCount = <String>[
    'imageUrl',
    'initials',
    'icon',
  ].where(props.containsKey).length;
  if (sourceCount != 1) {
    _fail(
      'Mp avatar requires exactly one of imageUrl, initials, or icon.',
      path: path,
    );
  }
}

Map<String, dynamic> _optionalMap(Object? value, {required String path}) {
  if (value == null) {
    return <String, dynamic>{};
  }
  if (value is! Map) {
    _fail('Mp field must be an object.', path: path);
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _optionalChildren(
  Object? value, {
  required String path,
}) {
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }
  if (value is! List) {
    _fail('Mp children must be an array.', path: path);
  }
  return <Map<String, dynamic>>[
    for (final child in value)
      if (child is Map)
        Map<String, dynamic>.from(child)
      else
        throw MiniProgramRenderException(
          message: 'Invalid Mp screen JSON: child nodes must be objects.',
          details: <String, dynamic>{'path': path},
        ),
  ];
}
