part of '../../mini_program_data_resource.dart';

_DataSearchIndex _buildDataSearchIndex(
  Object? root, {
  required List<String> fields,
  required String? itemsPath,
}) {
  final rawItems = itemsPath == null ? root : _readDataPath(root, itemsPath);
  if (rawItems is! List) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataSearchFailed,
      message: 'Data search source must resolve to a JSON list.',
    );
  }
  final records = <_DataSearchRecord>[];
  for (var index = 0; index < rawItems.length; index += 1) {
    final item = rawItems[index];
    if (item is! Map) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataSearchFailed,
        message: 'Every searchable data item must be a JSON object.',
      );
    }
    final normalizedItem = item.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final normalizedFields = fields
        .map((field) => _readDataPath(normalizedItem, field))
        .where((value) => value is String || value is num || value is bool)
        .map((value) => _normalizeSearchText(value.toString()))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    records.add(
      _DataSearchRecord(
        item: normalizedItem,
        sourceIndex: index,
        normalizedFields: normalizedFields,
      ),
    );
  }
  return _DataSearchIndex(records);
}

void _trimDataSearchIndexes(MiniProgramDataResourceManager manager) {
  while (manager._indexes.length > 8) {
    manager._indexes.remove(manager._indexes.keys.first);
  }
}

Object? _readDataPath(Object? root, String path) {
  Object? current = root;
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) {
      return null;
    }
    current = current[segment];
  }
  return current;
}
