part of '../../mini_program_data_resource.dart';

int? _rankDataSearchRecord(
  _DataSearchRecord record,
  String query,
  List<String> queryTokens,
) {
  if (record.normalizedFields.any((field) => field == query)) {
    return 0;
  }
  final fieldTokens = record.normalizedFields
      .expand((field) => field.split(' '))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (queryTokens.every(
    (queryToken) => fieldTokens.any((token) => token.startsWith(queryToken)),
  )) {
    return 1;
  }
  if (queryTokens.every(
    (queryToken) =>
        record.normalizedFields.any((field) => field.contains(queryToken)),
  )) {
    return 2;
  }
  return null;
}

String _normalizeSearchText(String value) => removeDiacritics(
  value.toLowerCase(),
).replaceAll(RegExp(r'\s+'), ' ').trim();
