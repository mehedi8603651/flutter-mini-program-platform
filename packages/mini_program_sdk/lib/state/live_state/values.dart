part of '../mp_state.dart';

Object? _normalizeStateValue(Object? value) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'value',
        'Mp state numbers must be finite.',
      );
    }
    return value;
  }
  if (value is List) {
    return value.map(_normalizeStateValue).toList(growable: false);
  }
  if (value is Map) {
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'key',
          'Mp state map keys must be non-empty strings.',
        );
      }
      normalized[key] = _normalizeStateValue(entry.value);
    }
    return normalized;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported Mp state value.');
}

Object? _cloneStateValue(Object? value) {
  if (value is List) {
    return value.map(_cloneStateValue).toList(growable: false);
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _cloneStateValue(entry.value),
    };
  }
  return value;
}

Map<String, dynamic> _cloneStateMap(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(_cloneStateValue(value) as Map);
}
