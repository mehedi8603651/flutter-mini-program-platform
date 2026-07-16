part of '../../mp_screen_renderer.dart';

extension _MpSharedValidation on MpScreenValidator {
  List<_MpAction> _parseLazyActions(Object? value, {required String path}) {
    if (value == null) {
      return const <_MpAction>[];
    }
    if (value is! List) {
      _fail('Mp lazy actions must be an array.', path: path);
    }
    return <_MpAction>[
      for (var index = 0; index < value.length; index += 1)
        _parseAction(value[index], path: '$path[$index]'),
    ];
  }

  List<_MpAction> _parseRequiredLazyActions(
    Object? value, {
    required String name,
    required String path,
  }) {
    final actions = _parseLazyActions(value, path: path);
    if (actions.isEmpty) {
      _fail('Mp lazyChunk requires non-empty $name.', path: path);
    }
    return actions;
  }

  _MpAction _parseNoPropsAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateNoProps(props, path: '$path.props');
    return _MpAction(type: type, props: const <String, dynamic>{});
  }

  Map<String, dynamic> _parseTemplateProps(
    Map<String, dynamic> props,
    Set<String> names, {
    required String path,
    required int depth,
    required _MpValidationState state,
  }) {
    final parsed = <String, dynamic>{};
    for (final name in names) {
      if (!props.containsKey(name)) {
        continue;
      }
      final value = props[name];
      if (value is! Map) {
        _fail(
          'Mp "$name" template must be a node object.',
          path: '$path.$name',
        );
      }
      parsed[name] = _parseNode(
        Map<String, dynamic>.from(value),
        path: '$path.$name',
        depth: depth + 1,
        state: state,
      );
    }
    return parsed;
  }
}
