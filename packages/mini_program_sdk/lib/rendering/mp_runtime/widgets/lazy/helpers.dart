part of '../../../mp_screen_renderer.dart';

String _lazyChunkRegistryKey(
  String miniProgramId,
  String? screenId,
  String id,
) {
  return '$miniProgramId/${screenId ?? 'unknown'}/$id';
}

String _lazyChunkRuntimeKey(_MpLazyChunk widget) {
  final node = widget.node;
  final initialActions =
      node.props['initialActions'] as List<_MpAction>? ?? const <_MpAction>[];
  final loadMoreActions =
      node.props['loadMoreActions'] as List<_MpAction>? ?? const <_MpAction>[];
  return <String>[
    widget.bindings.screenId ?? '',
    _string(node, 'id'),
    _string(node, 'itemsState'),
    (node.props['cursorState'] as String?) ?? '',
    (node.props['hasMoreState'] as String?) ?? '',
    (node.props['statusState'] as String?) ?? '',
    (node.props['cacheKeyPrefix'] as String?) ?? '',
    _string(node, 'bucket'),
    _bool(node, 'once').toString(),
    _bool(node, 'refreshIfCached').toString(),
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    (node.props['ttlMs'] as int?)?.toString() ?? '',
    for (final action in initialActions) _lazyActionKey(action),
    for (final action in loadMoreActions) _lazyActionKey(action),
  ].join('|');
}

_MpLazyChunkPage _lazyChunkPageFromResult(Object? result) {
  final data = _lazyResultData(result);
  final map = data is Map
      ? Map<String, dynamic>.from(data)
      : const <String, dynamic>{};
  return _MpLazyChunkPage(
    items: _lazyChunkItems(map['items']),
    nextCursor: map['nextCursor'],
    hasMore: _lazyChunkBool(map['hasMore']),
    pageCount: map['pageCount'] is int ? map['pageCount'] as int : 1,
  );
}

_MpLazyChunkPage? _lazyChunkPageFromCache(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = Map<String, dynamic>.from(value);
  return _MpLazyChunkPage(
    items: _lazyChunkItems(map['items']),
    nextCursor: map['nextCursor'],
    hasMore: _lazyChunkBool(map['hasMore']),
    pageCount: map['pageCount'] is int ? map['pageCount'] as int : 1,
  );
}

List<Object?> _lazyChunkItems(Object? value) {
  return value is List ? List<Object?>.from(value) : const <Object?>[];
}

bool _lazyChunkBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

List<Object?> _lazyChunkMergedItems(
  List<Object?> existing,
  List<Object?> incoming,
) {
  if (_lazyChunkHasPrefix(incoming, existing)) {
    return List<Object?>.from(incoming);
  }
  return <Object?>[...existing, ...incoming];
}

List<Object?> _lazyChunkAppendedItems(
  List<Object?> existing,
  List<Object?> incoming,
  List<Object?> merged,
) {
  if (_lazyChunkHasPrefix(incoming, existing)) {
    return incoming.skip(existing.length).toList(growable: false);
  }
  return merged.skip(existing.length).toList(growable: false);
}

bool _lazyChunkHasPrefix(List<Object?> incoming, List<Object?> existing) {
  if (incoming.length < existing.length) {
    return false;
  }
  for (var index = 0; index < existing.length; index += 1) {
    if (!_lazyChunkSameValue(incoming[index], existing[index])) {
      return false;
    }
  }
  return true;
}

bool _lazyChunkSameValue(Object? a, Object? b) {
  try {
    return jsonEncode(a) == jsonEncode(b);
  } catch (_) {
    return a == b;
  }
}

Map<String, dynamic> _lazyChunkStatePayload({
  required List<Object?> items,
  required Object? nextCursor,
  required bool hasMore,
  required int pageCount,
}) {
  return <String, dynamic>{
    'items': items,
    'nextCursor': nextCursor,
    'hasMore': hasMore,
    'pageCount': pageCount,
  };
}

String _lazyChunkInitialCacheKey(String prefix) => '${prefix}__initial';

String _lazyChunkCursorCacheKey(String prefix, Object cursor) {
  final encoded = base64Url
      .encode(utf8.encode(cursor.toString()))
      .replaceAll('=', '');
  return '${prefix}__cursor_$encoded';
}

String _runtimeKey(_MpLazySection widget) {
  final node = widget.node;
  final actions =
      node.props['actions'] as List<_MpAction>? ?? const <_MpAction>[];
  return <String>[
    widget.bindings.screenId ?? '',
    _string(node, 'id'),
    (node.props['cacheKey'] as String?) ?? '',
    _string(node, 'bucket'),
    (node.props['targetState'] as String?) ?? '',
    (node.props['statusState'] as String?) ?? '',
    _bool(node, 'once').toString(),
    _bool(node, 'refreshIfCached').toString(),
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    (node.props['ttlMs'] as int?)?.toString() ?? '',
    for (final action in actions) _lazyActionKey(action),
  ].join('|');
}

String _lazyActionKey(_MpAction action) {
  final keys = action.props.keys.toList(growable: false)..sort();
  final propsKey = keys
      .map((key) => '$key=${_lazyStableValueKey(action.props[key])}')
      .join(',');
  return '${action.type}:$propsKey';
}

String _lazyStableValueKey(Object? value) {
  if (value is _MpAction) {
    return _lazyActionKey(value);
  }
  if (value is _MpNode) {
    return 'node:${value.type}';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '$key=${_lazyStableValueKey(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_lazyStableValueKey).join(',')}]';
  }
  return value.toString();
}

MiniProgramCacheBucket _lazyCacheBucket(_MpNode node) {
  return switch (_string(node, 'bucket')) {
    'memory' => MiniProgramCacheBucket.memory,
    'data' => MiniProgramCacheBucket.data,
    'image' => MiniProgramCacheBucket.image,
    'state' => MiniProgramCacheBucket.state,
    _ => MiniProgramCacheBucket.data,
  };
}

Duration? _lazyTtl(_MpNode node) {
  final ttlMs = node.props['ttlMs'] as int?;
  return ttlMs == null ? null : Duration(milliseconds: ttlMs);
}

bool _lazyActionFailed(Object? result) {
  if (result is HostActionResult) {
    return !result.isSuccess;
  }
  if (result is MiniProgramBackendResult) {
    return !result.isSuccess;
  }
  if (result is Map) {
    final status = result['status'];
    if (status == 'failed' || status == 'failure') {
      return true;
    }
    if (result['success'] == false) {
      return true;
    }
  }
  return false;
}

Object? _lazyResultData(Object? result) {
  if (result is MiniProgramBackendResult) {
    return result.data;
  }
  if (result is HostActionResult) {
    return result.data;
  }
  if (result is Map) {
    if (result.containsKey('data')) {
      return result['data'];
    }
    return Map<String, dynamic>.from(result);
  }
  return result;
}
