import 'dart:convert';

import '../network/mini_program_backend_store.dart';

class MiniProgramBackendBindingResolver {
  const MiniProgramBackendBindingResolver();

  static final RegExp _bindingPattern = RegExp(r'\{\{\s*([^}]+?)\s*\}\}');

  dynamic resolveTemplate(
    dynamic template, {
    required MiniProgramBackendStore store,
    Map<String, dynamic>? item,
    Map<String, dynamic> bindings = const <String, dynamic>{},
  }) {
    final data = <String, dynamic>{
      'backend': store.toBindingData(),
      if (item != null) 'item': item,
      ...bindings,
    };
    return _resolveValue(template, data);
  }

  Object? readPath(Object? source, String path) {
    Object? current = source;
    for (final rawSegment in path.split('.')) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) {
        return null;
      }
      current = _readSegment(current, segment);
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  dynamic _resolveValue(dynamic value, Map<String, dynamic> data) {
    if (value is String) {
      return _resolveString(value, data);
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, nestedValue) =>
            MapEntry(key.toString(), _resolveValue(nestedValue, data)),
      );
    }
    if (value is List) {
      return value.map((item) => _resolveValue(item, data)).toList();
    }
    return value;
  }

  dynamic _resolveString(String value, Map<String, dynamic> data) {
    final matches = _bindingPattern.allMatches(value).toList();
    if (matches.isEmpty) {
      return value;
    }

    if (matches.length == 1 && matches.single.group(0) == value) {
      final resolved = readPath(data, matches.single.group(1)!.trim());
      return resolved ?? '';
    }

    var resolvedValue = value;
    for (final match in matches) {
      final raw = match.group(0)!;
      final path = match.group(1)!.trim();
      resolvedValue = resolvedValue.replaceAll(
        raw,
        _stringify(readPath(data, path)),
      );
    }
    return resolvedValue;
  }

  Object? _readSegment(Object? source, String segment) {
    final indexMatch = RegExp(r'^([^\[]+)\[(\d+)\]$').firstMatch(segment);
    if (indexMatch != null) {
      final key = indexMatch.group(1)!;
      final index = int.parse(indexMatch.group(2)!);
      return _readIndex(_readSegment(source, key), index);
    }

    if (source is Map) {
      return source[segment];
    }
    if (source is List) {
      final index = int.tryParse(segment);
      if (index == null) {
        return null;
      }
      return _readIndex(source, index);
    }
    return null;
  }

  Object? _readIndex(Object? source, int index) {
    if (source is! List || index < 0 || index >= source.length) {
      return null;
    }
    return source[index];
  }

  String _stringify(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return jsonEncode(value);
  }
}
