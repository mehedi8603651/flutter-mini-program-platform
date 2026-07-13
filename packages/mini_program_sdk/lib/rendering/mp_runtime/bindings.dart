part of '../mp_screen_renderer.dart';

class _MpRenderBindings {
  const _MpRenderBindings({
    this.scope,
    this.screenId,
    this.item,
    this.index,
    this.form,
    this.theme,
  });

  static final RegExp _bindingPattern = RegExp(r'\{\{\s*([^}]+?)\s*\}\}');

  final MiniProgramSdkScope? scope;
  final String? screenId;
  final Map<String, dynamic>? item;
  final int? index;
  final Map<String, dynamic>? form;
  final _MpThemeData? theme;

  _MpRenderBindings copyWith({
    MiniProgramSdkScope? scope,
    String? screenId,
    Map<String, dynamic>? item,
    int? index,
    Map<String, dynamic>? form,
    _MpThemeData? theme,
  }) {
    return _MpRenderBindings(
      scope: scope ?? this.scope,
      screenId: screenId ?? this.screenId,
      item: item ?? this.item,
      index: index ?? this.index,
      form: form ?? this.form,
      theme: theme ?? this.theme,
    );
  }

  Object? resolveValue(Object? value) {
    if (value is String) {
      return resolveStringValue(value);
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, nestedValue) =>
            MapEntry(key.toString(), resolveValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(resolveValue).toList(growable: false);
    }
    return value;
  }

  Map<String, dynamic> resolveMap(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(resolveValue(value) as Map);
  }

  String resolveString(String value) {
    final resolved = resolveStringValue(value);
    return _stringify(resolved);
  }

  Object? resolveStringValue(String value) {
    final matches = _bindingPattern.allMatches(value).toList();
    if (matches.isEmpty) {
      return value;
    }

    if (matches.length == 1 && matches.single.group(0) == value) {
      return _readPath(_bindingData(), matches.single.group(1)!.trim()) ?? '';
    }

    var resolvedValue = value;
    for (final match in matches) {
      final raw = match.group(0)!;
      final path = match.group(1)!.trim();
      resolvedValue = resolvedValue.replaceAll(
        raw,
        _stringify(_readPath(_bindingData(), path)),
      );
    }
    return resolvedValue;
  }

  Map<String, dynamic> _bindingData() {
    final activeScope = scope;
    final authSnapshot = activeScope?.authController?.snapshot(
      activeScope.miniProgramId,
    );
    return <String, dynamic>{
      'backend':
          activeScope?.backendStore.toBindingData() ?? <String, dynamic>{},
      'route': activeScope?.routeParams ?? <String, dynamic>{},
      'state':
          activeScope?.stateManager?.toBindingData() ?? <String, dynamic>{},
      if (item != null) 'item': item!,
      if (index != null) 'index': index!,
      if (form != null) 'form': form!,
      if (authSnapshot != null) 'auth': authSnapshot.toBindingData(),
    };
  }
}

abstract final class _MpBindingResolver {
  static final RegExp _bindingPattern = _MpRenderBindings._bindingPattern;
  static const Set<String> _allowedRoots = <String>{
    'auth',
    'backend',
    'form',
    'index',
    'item',
    'route',
    'state',
  };
  static const Set<String> _blockedSegments = <String>{
    'authorization',
    'credential',
    'idtoken',
    'password',
    'refreshtoken',
    'secret',
    'token',
  };

  static bool containsBinding(String value) {
    return _bindingPattern.hasMatch(value);
  }

  static bool isSingleBindingExpression(String value) {
    final matches = _bindingPattern.allMatches(value).toList();
    return matches.length == 1 && matches.single.group(0) == value;
  }

  static void validateSafeBindings(Object? value, {required String path}) {
    if (value is String) {
      _validateStringBindings(value, path: path);
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        validateSafeBindings(entry.value, path: '$path.${entry.key}');
      }
      return;
    }
    if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        validateSafeBindings(value[index], path: '$path[$index]');
      }
    }
  }

  static void _validateStringBindings(String value, {required String path}) {
    for (final match in _bindingPattern.allMatches(value)) {
      final bindingPath = match.group(1)!.trim();
      final segments = bindingPath
          .split('.')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty || !_allowedRoots.contains(segments.first)) {
        throw MiniProgramRenderException(
          message: 'Invalid Mp screen JSON: unsupported binding path.',
          details: <String, dynamic>{'path': path, 'bindingPath': bindingPath},
        );
      }
      for (final segment in segments) {
        final normalized = segment
            .replaceAll(RegExp(r'\[\d+\]'), '')
            .replaceAll('_', '')
            .toLowerCase();
        if (_blockedSegments.contains(normalized)) {
          throw MiniProgramRenderException(
            message: 'Invalid Mp screen JSON: unsafe binding path.',
            details: <String, dynamic>{
              'path': path,
              'bindingPath': bindingPath,
            },
          );
        }
      }
    }
  }
}

Object? _readPath(Object? source, String path) {
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

Set<String> _stateBindingPaths(Object? value) {
  if (value is! String) {
    return const <String>{};
  }
  final paths = <String>{};
  for (final match in _MpRenderBindings._bindingPattern.allMatches(value)) {
    final bindingPath = match.group(1)!.trim();
    if (!bindingPath.startsWith('state.')) {
      continue;
    }
    var statePath = bindingPath.substring('state.'.length);
    final listIndex = statePath.indexOf('[');
    if (listIndex >= 0) {
      statePath = statePath.substring(0, listIndex);
    }
    if (statePath.isNotEmpty) {
      paths.add(statePath);
    }
  }
  return paths;
}
