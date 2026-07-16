part of '../../mini_program_data_resource.dart';

Future<Map<String, dynamic>?> _searchDataResource(
  MiniProgramDataResourceManager manager, {
  required String appId,
  required String version,
  required String resourceId,
  required String query,
  required List<String> fields,
  required String? itemsPath,
  required int minQueryLength,
  required int limit,
  required String targetState,
}) async {
  final trimmedQuery = query.trim();
  if (query.length > 256) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataInvalidQuery,
      message: 'Data search query cannot exceed 256 characters.',
    );
  }
  final searchKey = '$appId\u0000$resourceId\u0000$targetState';
  final generation = (manager._searchGenerations[searchKey] ?? 0) + 1;
  manager._searchGenerations[searchKey] = generation;
  await Future<void>.delayed(Duration.zero);
  if (manager._searchGenerations[searchKey] != generation) {
    return null;
  }
  if (trimmedQuery.isEmpty || trimmedQuery.length < minQueryLength) {
    return <String, dynamic>{
      'query': trimmedQuery,
      'items': <Object?>[],
      'matchCount': 0,
      'truncated': false,
    };
  }

  final resourceKey = _resourceKey(appId, version, resourceId);
  final resource = manager._resources[resourceKey];
  if (resource == null) {
    throw MiniProgramDataException(
      code: MiniProgramErrorCodes.dataResourceNotFound,
      message: 'Data resource "$resourceId" has not been loaded.',
      details: <String, dynamic>{'resourceId': resourceId},
    );
  }
  final indexKey =
      '$resourceKey\u0000${itemsPath ?? ''}\u0000${fields.join('|')}';
  final index = manager._indexes[indexKey] ??= _buildDataSearchIndex(
    resource.value,
    fields: fields,
    itemsPath: itemsPath,
  );
  _trimDataSearchIndexes(manager);
  final normalizedQuery = _normalizeSearchText(trimmedQuery);
  final queryTokens = normalizedQuery
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  final matches = <_RankedDataItem>[];
  for (final record in index.records) {
    final rank = record.rank(normalizedQuery, queryTokens);
    if (rank != null) {
      matches.add(_RankedDataItem(rank: rank, record: record));
    }
  }
  matches.sort((left, right) {
    final rankOrder = left.rank.compareTo(right.rank);
    return rankOrder != 0
        ? rankOrder
        : left.record.sourceIndex.compareTo(right.record.sourceIndex);
  });
  if (manager._searchGenerations[searchKey] != generation) {
    return null;
  }
  final selected = matches.take(limit).map((match) => match.record.item);
  return <String, dynamic>{
    'query': trimmedQuery,
    'items': selected.toList(growable: false),
    'matchCount': matches.length,
    'truncated': matches.length > limit,
  };
}
