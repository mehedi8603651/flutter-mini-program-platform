import 'dart:convert';
import 'dart:math' as math;

import 'package:diacritic/diacritic.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;

import '../cache/runtime_cache.dart';
import '../network/mini_program_source.dart';
import '../network/mini_program_source_exception.dart';

const int miniProgramJsonAssetMaxBytes = 2 * 1024 * 1024;
const int miniProgramJsonAssetMaxDepth = 32;
const int miniProgramJsonAssetMaxMembers = 50000;
const int miniProgramJsonAssetPathMaxLength = 256;

/// A validated artifact-local JSON resource load result.
class MiniProgramDataResourceLoadResult {
  const MiniProgramDataResourceLoadResult({
    required this.id,
    required this.asset,
    required this.fromCache,
    required this.bytes,
  });

  final String id;
  final String asset;
  final bool fromCache;
  final int bytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'asset': asset,
    'fromCache': fromCache,
    'bytes': bytes,
  };
}

/// Stable failure raised while loading or searching local JSON data.
class MiniProgramDataException implements Exception {
  const MiniProgramDataException({
    required this.code,
    required this.message,
    this.details = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}

/// Owns validated JSON resources and bounded search indexes for one runtime.
class MiniProgramDataResourceManager {
  final Map<String, _LoadedDataResource> _resources =
      <String, _LoadedDataResource>{};
  final Map<String, _DataSearchIndex> _indexes = <String, _DataSearchIndex>{};
  final Map<String, int> _searchGenerations = <String, int>{};

  Future<MiniProgramDataResourceLoadResult> load({
    required String appId,
    required String version,
    required String resourceId,
    required String assetPath,
    required Duration ttl,
    required bool forceRefresh,
    required MiniProgramJsonAssetSource? source,
    required MiniProgramCacheManager cacheManager,
    required MiniProgramCachePolicy cachePolicy,
  }) async {
    _validateResourceId(resourceId);
    _validateJsonAssetPath(assetPath);
    _ensureDataCacheEnabled(cachePolicy);
    final resourceKey = _resourceKey(appId, version, resourceId);
    final cacheKey = _cacheKey(version, resourceId);
    final appCache = cacheManager.forApp(appId, policy: cachePolicy);

    if (!forceRefresh) {
      final cached = await appCache.get<Object?>(
        cacheKey,
        bucket: MiniProgramCacheBucket.data,
      );
      if (cached != null) {
        final encoded = utf8.encode(jsonEncode(cached));
        _validateJsonValue(cached, encoded.length, cachePolicy);
        _replaceResource(
          resourceKey,
          _LoadedDataResource(assetPath: assetPath, value: cached),
        );
        return MiniProgramDataResourceLoadResult(
          id: resourceId,
          asset: assetPath,
          fromCache: true,
          bytes: encoded.length,
        );
      }
    }

    if (source == null) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataAssetUnavailable,
        message: 'The active mini-program source cannot load JSON assets.',
      );
    }

    late final List<int> bytes;
    try {
      bytes = await source.loadJsonAsset(
        miniProgramId: appId,
        version: version,
        assetPath: assetPath,
      );
    } on MiniProgramSourceException catch (error) {
      if (error.statusCode == 404) {
        throw MiniProgramDataException(
          code: MiniProgramErrorCodes.dataResourceNotFound,
          message: 'JSON data asset "$assetPath" was not found.',
          details: <String, dynamic>{'asset': assetPath},
        );
      }
      if (error.errorCode == MiniProgramErrorCodes.dataAssetUnavailable) {
        throw MiniProgramDataException(
          code: MiniProgramErrorCodes.dataAssetUnavailable,
          message: error.message,
          details: error.details,
        );
      }
      rethrow;
    }
    if (bytes.length > _effectiveMaxBytes(cachePolicy)) {
      throw MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceTooLarge,
        message: 'JSON data asset exceeds the accepted size limit.',
        details: <String, dynamic>{
          'asset': assetPath,
          'actualBytes': bytes.length,
          'maxBytes': _effectiveMaxBytes(cachePolicy),
        },
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw MiniProgramDataException(
        code: MiniProgramErrorCodes.dataInvalidJson,
        message: 'JSON data asset "$assetPath" is malformed.',
        details: <String, dynamic>{'asset': assetPath},
      );
    }
    _validateJsonValue(decoded, bytes.length, cachePolicy);
    await appCache.set(
      cacheKey,
      decoded,
      bucket: MiniProgramCacheBucket.data,
      ttl: ttl,
      priority: MiniProgramCachePriority.normal,
    );
    _replaceResource(
      resourceKey,
      _LoadedDataResource(assetPath: assetPath, value: decoded),
    );
    return MiniProgramDataResourceLoadResult(
      id: resourceId,
      asset: assetPath,
      fromCache: false,
      bytes: bytes.length,
    );
  }

  Future<Map<String, dynamic>?> search({
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
    final generation = (_searchGenerations[searchKey] ?? 0) + 1;
    _searchGenerations[searchKey] = generation;
    await Future<void>.delayed(Duration.zero);
    if (_searchGenerations[searchKey] != generation) {
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
    final resource = _resources[resourceKey];
    if (resource == null) {
      throw MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceNotFound,
        message: 'Data resource "$resourceId" has not been loaded.',
        details: <String, dynamic>{'resourceId': resourceId},
      );
    }
    final indexKey =
        '$resourceKey\u0000${itemsPath ?? ''}\u0000${fields.join('|')}';
    final index = _indexes[indexKey] ??= _buildIndex(
      resource.value,
      fields: fields,
      itemsPath: itemsPath,
    );
    _trimIndexes();
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
    if (_searchGenerations[searchKey] != generation) {
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

  void clear() {
    _resources.clear();
    _indexes.clear();
    _searchGenerations.clear();
  }

  void _replaceResource(String key, _LoadedDataResource resource) {
    _resources[key] = resource;
    _indexes.removeWhere((indexKey, _) => indexKey.startsWith('$key\u0000'));
  }

  _DataSearchIndex _buildIndex(
    Object? root, {
    required List<String> fields,
    required String? itemsPath,
  }) {
    final rawItems = itemsPath == null ? root : _readPath(root, itemsPath);
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
          .map((field) => _readPath(normalizedItem, field))
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

  void _trimIndexes() {
    while (_indexes.length > 8) {
      _indexes.remove(_indexes.keys.first);
    }
  }
}

class _LoadedDataResource {
  const _LoadedDataResource({required this.assetPath, required this.value});

  final String assetPath;
  final Object? value;
}

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
    if (normalizedFields.any((field) => field == query)) {
      return 0;
    }
    final fieldTokens = normalizedFields
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
          normalizedFields.any((field) => field.contains(queryToken)),
    )) {
      return 2;
    }
    return null;
  }
}

class _RankedDataItem {
  const _RankedDataItem({required this.rank, required this.record});

  final int rank;
  final _DataSearchRecord record;
}

void _ensureDataCacheEnabled(MiniProgramCachePolicy policy) {
  if (!policy.enabled ||
      !policy.allowsMiniProgramBucket(MiniProgramCacheBucket.data)) {
    throw const MiniProgramDataException(
      code: 'cache_bucket_disabled',
      message: 'The data cache bucket is disabled by host policy.',
    );
  }
}

void _validateResourceId(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataAssetUnavailable,
      message: 'Data resource ID is invalid.',
    );
  }
}

void _validateJsonAssetPath(String value) {
  final valid =
      value.length <= miniProgramJsonAssetPathMaxLength &&
      RegExp(r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$').hasMatch(value) &&
      !value.contains('..');
  if (!valid) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataAssetUnavailable,
      message: 'JSON asset path is invalid or unsafe.',
    );
  }
}

void _validateJsonValue(
  Object? value,
  int bytes,
  MiniProgramCachePolicy policy,
) {
  final maxBytes = _effectiveMaxBytes(policy);
  if (bytes > maxBytes) {
    throw MiniProgramDataException(
      code: MiniProgramErrorCodes.dataResourceTooLarge,
      message: 'JSON data resource exceeds the accepted size limit.',
      details: <String, dynamic>{'actualBytes': bytes, 'maxBytes': maxBytes},
    );
  }
  if (value is! Map && value is! List) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataInvalidJson,
      message: 'JSON data resource root must be an object or list.',
    );
  }
  var members = 0;
  void visit(Object? current, int depth) {
    if (depth > miniProgramJsonAssetMaxDepth) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceTooLarge,
        message: 'JSON data resource exceeds the maximum nesting depth.',
      );
    }
    if (current is Map) {
      members += current.length;
      for (final entry in current.entries) {
        visit(entry.value, depth + 1);
      }
    } else if (current is List) {
      members += current.length;
      for (final item in current) {
        visit(item, depth + 1);
      }
    }
    if (members > miniProgramJsonAssetMaxMembers) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceTooLarge,
        message: 'JSON data resource contains too many values.',
      );
    }
  }

  visit(value, 1);
}

int _effectiveMaxBytes(MiniProgramCachePolicy policy) => math.min(
  miniProgramJsonAssetMaxBytes,
  math.min(policy.maxDataBytes, policy.maxBytes),
);

String _cacheKey(String version, String resourceId) =>
    '_sdk_json_${version.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}_$resourceId';

String _resourceKey(String appId, String version, String resourceId) =>
    '$appId\u0000$version\u0000$resourceId';

Object? _readPath(Object? root, String path) {
  Object? current = root;
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) {
      return null;
    }
    current = current[segment];
  }
  return current;
}

String _normalizeSearchText(String value) => removeDiacritics(
  value.toLowerCase(),
).replaceAll(RegExp(r'\s+'), ' ').trim();
