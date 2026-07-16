part of '../../mp_screen_renderer.dart';

bool _stateValuesEqual(Object? left, Object? right) {
  if (identical(left, right) || left == right) {
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_stateValuesEqual(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_stateValuesEqual(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

abstract final class _MpStateActionHandler {
  static Future<HostActionResult> _setState(
    MiniProgramSdkScope scope,
    String actionName,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    state.set(_stringProp(props, 'key'), props['value']);
    return HostActionResult.success(actionName: actionName);
  }

  static Future<HostActionResult> _setDefaultState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.setDefault');
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null) {
      return HostActionResult.success(
        actionName: 'state.setDefault',
        data: <String, dynamic>{'changed': false, 'value': current},
      );
    }
    final value = props['value'];
    state.set(key, value);
    return HostActionResult.success(
      actionName: 'state.setDefault',
      data: <String, dynamic>{'changed': true, 'value': value},
    );
  }

  static Future<HostActionResult> _patchState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.patch';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final values = props['values'] is Map
        ? Map<String, dynamic>.from(props['values'] as Map)
        : <String, dynamic>{};
    final remove = props['remove'] is List
        ? List<String>.from(props['remove'] as List)
        : <String>[];
    final changedKeys = <String>[];
    final removedKeys = <String>[];
    for (final entry in values.entries) {
      if (!state.contains(entry.key) ||
          !_stateValuesEqual(state.get<Object?>(entry.key), entry.value)) {
        changedKeys.add(entry.key);
      }
    }
    for (final key in remove) {
      if (state.contains(key)) {
        removedKeys.add(key);
      }
    }
    state.batchUpdates(() {
      for (final key in remove) {
        state.remove(key);
      }
      for (final entry in values.entries) {
        state.set(entry.key, entry.value);
      }
    });
    changedKeys.sort();
    removedKeys.sort();
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'changedKeys': changedKeys,
        'removedKeys': removedKeys,
      },
    );
  }

  static Future<HostActionResult> _mutateNumberState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool subtract,
  }) async {
    final actionName = subtract ? 'state.decrement' : 'state.increment';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    final by = props['by'];
    final defaultValue = props['defaultValue'] ?? 0;
    if (current != null && (current is! num || !current.isFinite) ||
        by is! num ||
        !by.isFinite ||
        defaultValue is! num ||
        !defaultValue.isFinite) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Mp $actionName requires finite numeric values.',
        errorCode: MiniProgramErrorCodes.stateInvalidValue,
      );
    }
    final previous = current as num? ?? defaultValue;
    var next = subtract ? previous - by : previous + by;
    if (!next.isFinite) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Mp $actionName result must be finite.',
        errorCode: MiniProgramErrorCodes.stateInvalidValue,
      );
    }
    var clamped = false;
    final min = props['min'];
    final max = props['max'];
    if (min is num && next < min) {
      next = min;
      clamped = true;
    }
    if (max is num && next > max) {
      next = max;
      clamped = true;
    }
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'previousValue': previous,
        'by': by,
        'value': next,
        'clamped': clamped,
      },
    );
  }

  static Future<HostActionResult> _copyState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.copy';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final source = state.get<Object?>(_stringProp(props, 'from'));
    final convertTo = _stringProp(props, 'convertTo');
    final Object? value;
    switch (convertTo) {
      case 'value':
        value = source;
        break;
      case 'text':
        if (source is! String && source is! num && source is! bool) {
          return _stateConversionFailure(actionName, convertTo);
        }
        if (source is num && !source.isFinite) {
          return _stateConversionFailure(actionName, convertTo);
        }
        value = source.toString();
        break;
      case 'number':
        if (source is num && source.isFinite) {
          value = source;
        } else if (source is String) {
          final parsed = num.tryParse(source.trim());
          if (parsed == null || !parsed.isFinite) {
            return _stateConversionFailure(actionName, convertTo);
          }
          value = parsed;
        } else {
          return _stateConversionFailure(actionName, convertTo);
        }
        break;
      default:
        return _stateConversionFailure(actionName, convertTo);
    }
    state.set(_stringProp(props, 'to'), value);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'value': value, 'convertTo': convertTo},
    );
  }

  static Future<HostActionResult> _toggleState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.toggle';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! bool) {
      return _stateTypeFailure(actionName, 'boolean');
    }
    final previous = current as bool? ?? _boolProp(props, 'defaultValue');
    final next = !previous;
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'previousValue': previous, 'value': next},
    );
  }

  static Future<HostActionResult> _appendStateText(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.appendText';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! String) {
      return _stateTypeFailure(actionName, 'string');
    }
    final text = _stringProp(props, 'text');
    final maxLength = _intProp(props, 'maxLength', fallback: 4096);
    final next = '${current as String? ?? ''}$text';
    final length = next.runes.length;
    if (length > maxLength || length > _maxStateTextLength) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Mp state.appendText exceeds the configured text limit.',
        errorCode: MiniProgramErrorCodes.stateLimitExceeded,
        data: <String, dynamic>{'length': length, 'maxLength': maxLength},
      );
    }
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'value': next, 'length': length},
    );
  }

  static Future<HostActionResult> _backspaceStateText(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.backspace';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! String) {
      return _stateTypeFailure(actionName, 'string');
    }
    final runes = (current as String? ?? '').runes.toList(growable: false);
    final count = _intProp(props, 'count', fallback: 1);
    final keep = math.max(0, runes.length - count);
    final next = String.fromCharCodes(runes.take(keep));
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'value': next, 'length': keep},
    );
  }

  static Future<HostActionResult> _addStateListValue(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props, {
    required bool prepend,
  }) async {
    final actionName = prepend ? 'state.listPrepend' : 'state.listAppend';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! List) {
      return _stateTypeFailure(actionName, 'list');
    }
    final next = current == null
        ? <Object?>[]
        : List<Object?>.from(current as List);
    if (prepend) {
      next.insert(0, props['value']);
    } else {
      next.add(props['value']);
    }
    final maxItems = _optionalIntProp(props, 'maxItems');
    if (maxItems != null && next.length > maxItems) {
      if (prepend) {
        next.removeRange(maxItems, next.length);
      } else {
        next.removeRange(0, next.length - maxItems);
      }
    }
    if (next.length > _maxStateListItems) {
      return _stateListLimitFailure(actionName, next.length);
    }
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'value': next, 'length': next.length},
    );
  }

  static Future<HostActionResult> _insertStateListValue(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.listInsert';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! List) {
      return _stateTypeFailure(actionName, 'list');
    }
    final next = current == null
        ? <Object?>[]
        : List<Object?>.from(current as List);
    final index = _optionalIntProp(props, 'index');
    if (index == null) {
      return _stateIntegerFailure(actionName, 'index');
    }
    if (index < 0 || index > next.length) {
      return _stateIndexFailure(actionName, index, next.length);
    }
    if (next.length >= _maxStateListItems) {
      return _stateListLimitFailure(actionName, next.length + 1);
    }
    next.insert(index, props['value']);
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{'value': next, 'length': next.length},
    );
  }

  static Future<HostActionResult> _removeStateListAt(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.listRemoveAt';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current == null) {
      return HostActionResult.success(
        actionName: actionName,
        data: const <String, dynamic>{'removed': false},
      );
    }
    if (current is! List) {
      return _stateTypeFailure(actionName, 'list');
    }
    final next = List<Object?>.from(current);
    final index = _optionalIntProp(props, 'index');
    if (index == null) {
      return _stateIntegerFailure(actionName, 'index');
    }
    if (index < 0 || index >= next.length) {
      return _stateIndexFailure(actionName, index, next.length);
    }
    final removed = next.removeAt(index);
    state.set(key, next);
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'removed': true,
        'removedValue': removed,
        'value': next,
        'length': next.length,
      },
    );
  }

  static Future<HostActionResult> _removeStateListValue(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'state.listRemoveValue';
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current == null) {
      return HostActionResult.success(
        actionName: actionName,
        data: const <String, dynamic>{'removed': false, 'removedCount': 0},
      );
    }
    if (current is! List) {
      return _stateTypeFailure(actionName, 'list');
    }
    final next = List<Object?>.from(current);
    final value = props['value'];
    var removedCount = 0;
    if (_boolProp(props, 'all')) {
      next.removeWhere((item) {
        final matches = _stateValuesEqual(item, value);
        if (matches) {
          removedCount += 1;
        }
        return matches;
      });
    } else {
      final index = next.indexWhere((item) => _stateValuesEqual(item, value));
      if (index >= 0) {
        next.removeAt(index);
        removedCount = 1;
      }
    }
    if (removedCount > 0) {
      state.set(key, next);
    }
    return HostActionResult.success(
      actionName: actionName,
      data: <String, dynamic>{
        'removed': removedCount > 0,
        'removedCount': removedCount,
        'value': next,
        'length': next.length,
      },
    );
  }

  static Future<HostActionResult> _removeState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.remove');
    }
    state.remove(_stringProp(props, 'key'));
    return HostActionResult.success(actionName: 'state.remove');
  }

  static Future<HostActionResult> _clearState(MiniProgramSdkScope scope) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.clear');
    }
    state.clear();
    return HostActionResult.success(actionName: 'state.clear');
  }

  static HostActionResult _stateUnavailable(
    String actionName, {
    String? requestId,
  }) {
    return HostActionResult.failed(
      requestId: requestId,
      actionName: actionName,
      message: 'Mp state manager is unavailable.',
      errorCode: 'state_unavailable',
    );
  }

  static HostActionResult _stateTypeFailure(
    String actionName,
    String expectedType,
  ) => HostActionResult.failed(
    actionName: actionName,
    message: 'Mp $actionName requires an existing $expectedType state value.',
    errorCode: MiniProgramErrorCodes.stateInvalidValue,
  );

  static HostActionResult _stateConversionFailure(
    String actionName,
    String convertTo,
  ) => HostActionResult.failed(
    actionName: actionName,
    message: 'Mp $actionName cannot convert the source to $convertTo.',
    errorCode: MiniProgramErrorCodes.stateInvalidValue,
  );

  static HostActionResult _stateListLimitFailure(
    String actionName,
    int length,
  ) => HostActionResult.failed(
    actionName: actionName,
    message: 'Mp state lists cannot exceed $_maxStateListItems items.',
    errorCode: MiniProgramErrorCodes.stateLimitExceeded,
    data: <String, dynamic>{'length': length, 'maxItems': _maxStateListItems},
  );

  static HostActionResult _stateIndexFailure(
    String actionName,
    int index,
    int length,
  ) => HostActionResult.failed(
    actionName: actionName,
    message: 'Mp $actionName index is outside the list range.',
    errorCode: MiniProgramErrorCodes.stateIndexOutOfRange,
    data: <String, dynamic>{'index': index, 'length': length},
  );

  static HostActionResult _stateIntegerFailure(
    String actionName,
    String name,
  ) => HostActionResult.failed(
    actionName: actionName,
    message: 'Mp $actionName $name must resolve to an integer.',
    errorCode: MiniProgramErrorCodes.stateInvalidValue,
  );
}
