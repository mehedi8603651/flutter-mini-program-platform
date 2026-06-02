abstract interface class MpJsonEncodable {
  Map<String, Object?> toJson();
}

Map<String, Object?> encodeMpMap(Map<String, Object?> values) {
  final keys = values.keys.toList()..sort();
  return <String, Object?>{
    for (final key in keys) key: encodeMpValue(values[key]),
  };
}

Object? encodeMpValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }

  if (value is MpJsonEncodable) {
    return value.toJson();
  }

  if (value is Iterable) {
    return value.map(encodeMpValue).toList(growable: false);
  }

  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'key',
          'Mp JSON map keys must be strings.',
        );
      }
      normalized[key] = entry.value;
    }
    return encodeMpMap(normalized);
  }

  throw ArgumentError.value(value, 'value', 'Unsupported Mp JSON value.');
}
