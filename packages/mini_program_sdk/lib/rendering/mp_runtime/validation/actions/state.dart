part of '../../../mp_screen_renderer.dart';

extension _MpStateActionValidation on MpScreenValidator {
  _MpAction _parseStateSetAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp $type requires a value.', path: '$path.props.value');
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
      },
    );
  }

  _MpAction _parseStatePatchAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'values',
      'remove',
    }, path: '$path.props');
    final rawValues = props['values'];
    if (rawValues != null && rawValues is! Map) {
      _fail(
        'Mp state.patch values must be an object.',
        path: '$path.props.values',
      );
    }
    final values = rawValues == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawValues as Map);
    final normalizedValues = <String, dynamic>{};
    for (final entry in values.entries) {
      final key = _validateStateKey(
        entry.key,
        path: '$path.props.values.${entry.key}',
      );
      normalizedValues[key] = entry.value;
    }

    final rawRemove = props['remove'];
    if (rawRemove != null && rawRemove is! List) {
      _fail(
        'Mp state.patch remove must be an array.',
        path: '$path.props.remove',
      );
    }
    final remove = <String>[];
    if (rawRemove is List) {
      for (var index = 0; index < rawRemove.length; index += 1) {
        final rawKey = rawRemove[index];
        if (rawKey is! String) {
          _fail(
            'Mp state.patch remove paths must be strings.',
            path: '$path.props.remove[$index]',
          );
        }
        remove.add(
          _validateStateKey(rawKey, path: '$path.props.remove[$index]'),
        );
      }
    }
    if (normalizedValues.isEmpty && remove.isEmpty) {
      _fail(
        'Mp state.patch requires values or remove paths.',
        path: '$path.props',
      );
    }
    final paths = <String>[...normalizedValues.keys, ...remove];
    for (var left = 0; left < paths.length; left += 1) {
      for (var right = left + 1; right < paths.length; right += 1) {
        if (_statePatchPathsOverlap(paths[left], paths[right])) {
          _fail(
            'Mp state.patch paths cannot duplicate or overlap.',
            path: '$path.props',
            details: <String, dynamic>{
              'left': paths[left],
              'right': paths[right],
            },
          );
        }
      }
    }
    remove.sort();
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        if (normalizedValues.isNotEmpty) 'values': normalizedValues,
        if (remove.isNotEmpty) 'remove': remove,
      },
    );
  }

  _MpAction _parseStateNumberMutationAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'by',
      'defaultValue',
      'min',
      'max',
    }, path: '$path.props');
    final by = props['by'] ?? 1;
    _validateFiniteNumberOrBinding(by, path: '$path.props.by');
    final defaultValue = _optionalFiniteNumber(
      props['defaultValue'],
      fallback: 0,
      path: '$path.props.defaultValue',
    );
    final min = _optionalFiniteNumber(props['min'], path: '$path.props.min');
    final max = _optionalFiniteNumber(props['max'], path: '$path.props.max');
    if (min != null && max != null && min > max) {
      _fail(
        'Mp $type min cannot be greater than max.',
        path: '$path.props.min',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'by': by,
        'defaultValue': defaultValue,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      },
    );
  }

  _MpAction _parseStateCopyAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'from',
      'to',
      'convertTo',
    }, path: '$path.props');
    final convertTo = props['convertTo'] ?? 'value';
    if (convertTo is! String ||
        !const <String>{'value', 'text', 'number'}.contains(convertTo)) {
      _fail(
        'Mp state.copy convertTo must be value, text, or number.',
        path: '$path.props.convertTo',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'from': _requiredStateKey(props, 'from', path: '$path.props'),
        'to': _requiredStateKey(props, 'to', path: '$path.props'),
        'convertTo': convertTo,
      },
    );
  }

  _MpAction _parseStateToggleAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'defaultValue',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'defaultValue':
            _optionalBool(
              props['defaultValue'],
              path: '$path.props.defaultValue',
            ) ??
            false,
      },
    );
  }

  void _validateFiniteNumberOrBinding(Object? value, {required String path}) {
    if (value is num && value.isFinite ||
        value is String &&
            _MpBindingResolver.isSingleBindingExpression(value)) {
      return;
    }
    _fail(
      'Mp state numeric operand must be a finite number or full binding.',
      path: path,
    );
  }

  num? _optionalFiniteNumber(
    Object? value, {
    num? fallback,
    required String path,
  }) {
    if (value == null) {
      return fallback;
    }
    if (value is num && value.isFinite) {
      return value;
    }
    _fail('Mp state numeric option must be finite.', path: path);
  }

  _MpAction _parseStateAppendTextAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'text',
      'maxLength',
    }, path: '$path.props');
    final text = _requiredString(props, 'text', path: '$path.props');
    final maxLength =
        _optionalPositiveInt(
          props['maxLength'],
          path: '$path.props.maxLength',
        ) ??
        4096;
    if (maxLength > _maxStateTextLength) {
      _fail(
        'Mp state.appendText maxLength cannot exceed $_maxStateTextLength.',
        path: '$path.props.maxLength',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'text': text,
        'maxLength': maxLength,
      },
    );
  }

  _MpAction _parseStateBackspaceAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'count',
    }, path: '$path.props');
    final count =
        _optionalPositiveInt(props['count'], path: '$path.props.count') ?? 1;
    if (count > _maxStateTextLength) {
      _fail(
        'Mp state.backspace count cannot exceed $_maxStateTextLength.',
        path: '$path.props.count',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'count': count,
      },
    );
  }

  _MpAction _parseStateListAddAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
      'maxItems',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp $type requires a value.', path: '$path.props.value');
    }
    final maxItems = _optionalPositiveInt(
      props['maxItems'],
      path: '$path.props.maxItems',
    );
    if (maxItems != null && maxItems > _maxStateListItems) {
      _fail(
        'Mp state list maxItems cannot exceed $_maxStateListItems.',
        path: '$path.props.maxItems',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
        if (maxItems != null) 'maxItems': maxItems,
      },
    );
  }

  _MpAction _parseStateListInsertAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'index',
      'value',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail('Mp state.listInsert requires a value.', path: '$path.props.value');
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'index': _requiredIntegerOrBinding(
          props['index'],
          path: '$path.props.index',
        ),
        'value': props['value'],
      },
    );
  }

  _MpAction _parseStateListRemoveAtAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'index',
    }, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'index': _requiredIntegerOrBinding(
          props['index'],
          path: '$path.props.index',
        ),
      },
    );
  }

  _MpAction _parseStateListRemoveValueAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{
      'key',
      'value',
      'all',
    }, path: '$path.props');
    if (!props.containsKey('value')) {
      _fail(
        'Mp state.listRemoveValue requires a value.',
        path: '$path.props.value',
      );
    }
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
        'value': props['value'],
        'all': _optionalBool(props['all'], path: '$path.props.all') ?? false,
      },
    );
  }

  _MpAction _parseStateRemoveAction(
    String type,
    Map<String, dynamic> props,
    String path,
  ) {
    _validateObjectKeys(props, const <String>{'key'}, path: '$path.props');
    return _MpAction(
      type: type,
      props: <String, dynamic>{
        'key': _requiredStateKey(props, 'key', path: '$path.props'),
      },
    );
  }
}
