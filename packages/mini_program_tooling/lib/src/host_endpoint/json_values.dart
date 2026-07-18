import 'dart:convert';

Map<String, Object?> hostJsonObjectOrEmpty(Object? value) {
  if (value is! Map) {
    return <String, Object?>{};
  }
  return deepHostJsonObjectCopy(value);
}

Map<String, Object?> deepHostJsonObjectCopy(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    result[entry.key.toString()] = deepHostJsonValueCopy(entry.value);
  }
  return result;
}

Object? deepHostJsonValueCopy(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return deepHostJsonObjectCopy(value);
  }
  if (value is List) {
    return value.map(deepHostJsonValueCopy).toList(growable: false);
  }
  return value.toString();
}

Map<String, Object?> sortedHostJsonObject(Map<String, Object?> value) {
  final entries = value.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return <String, Object?>{for (final entry in entries) entry.key: entry.value};
}

int? positiveHostInt(Object? value) {
  if (value is int && value > 0) {
    return value;
  }
  if (value is num && value > 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

String hostDartString(String value) => jsonEncode(value);
