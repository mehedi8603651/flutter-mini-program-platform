part of '../../mini_program_data_resource.dart';

class _DataSearchIndex {
  const _DataSearchIndex(this.records);

  final List<_DataSearchRecord> records;
}

class _DataSearchRecord {
  const _DataSearchRecord({
    required this.item,
    required this.sourceIndex,
    required this.normalizedFields,
  });

  final Map<String, dynamic> item;
  final int sourceIndex;
  final List<String> normalizedFields;

  int? rank(String query, List<String> queryTokens) {
    return _rankDataSearchRecord(this, query, queryTokens);
  }
}

class _RankedDataItem {
  const _RankedDataItem({required this.rank, required this.record});

  final int rank;
  final _DataSearchRecord record;
}
