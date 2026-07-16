part of '../../../mp_screen_renderer.dart';

MiniProgramBackendQuery _backendQuery(
  _MpNode node,
  _MpRenderBindings bindings,
) {
  return MiniProgramBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    method: _string(node, 'method'),
    body: Map<String, dynamic>.from(
      bindings.resolveValue(node.props['body']) as Map? ??
          const <String, dynamic>{},
    ),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

String _searchEndpoint(
  _MpNode node, {
  required String query,
  required int limit,
}) {
  final parsed = Uri.parse(_string(node, 'endpoint'));
  final params = <String, String>{
    ...parsed.queryParameters,
    _string(node, 'queryParam'): query,
    _string(node, 'limitParam'): limit.toString(),
  };
  return parsed.replace(queryParameters: params).toString();
}

Map<String, dynamic> _searchBody(
  _MpNode node,
  _MpRenderBindings bindings, {
  required String query,
  required int limit,
}) {
  final resolvedBody = Map<String, dynamic>.from(
    bindings.resolveValue(node.props['body']) as Map? ??
        const <String, dynamic>{},
  );
  return <String, dynamic>{
    ...resolvedBody,
    _string(node, 'queryParam'): query,
    _string(node, 'limitParam'): limit,
  };
}

Map<String, dynamic> _normalizeSearchData(Map<String, dynamic> data) {
  if (data.isEmpty) {
    return const <String, dynamic>{'items': <Object?>[]};
  }
  return Map<String, dynamic>.from(data);
}

bool _searchDataIsEmpty(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is List) {
    return items.isEmpty;
  }
  return data.isEmpty;
}

MiniProgramPagedBackendQuery _pagedQuery(_MpNode node) {
  return MiniProgramPagedBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    limit: _int(node, 'limit', fallback: 20),
    initialCursor: node.props['initialCursor'] as String?,
    cursorParam: _string(node, 'cursorParam'),
    limitParam: _string(node, 'limitParam'),
    itemsPath: _string(node, 'itemsPath'),
    nextCursorPath: _string(node, 'nextCursorPath'),
    hasMorePath: _string(node, 'hasMorePath'),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

String _queryKey(_MpNode node) {
  return jsonEncode(
    node.props.map<String, Object?>((key, value) {
      if (value is _MpNode) {
        return MapEntry<String, Object?>(key, value.type);
      }
      return MapEntry<String, Object?>(key, value);
    }),
  );
}
