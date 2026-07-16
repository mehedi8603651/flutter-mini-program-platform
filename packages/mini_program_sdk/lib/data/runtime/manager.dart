part of '../mini_program_data_resource.dart';

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
  }) {
    return _loadDataResource(
      this,
      appId: appId,
      version: version,
      resourceId: resourceId,
      assetPath: assetPath,
      ttl: ttl,
      forceRefresh: forceRefresh,
      source: source,
      cacheManager: cacheManager,
      cachePolicy: cachePolicy,
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
  }) {
    return _searchDataResource(
      this,
      appId: appId,
      version: version,
      resourceId: resourceId,
      query: query,
      fields: fields,
      itemsPath: itemsPath,
      minQueryLength: minQueryLength,
      limit: limit,
      targetState: targetState,
    );
  }

  void clear() {
    _resources.clear();
    _indexes.clear();
    _searchGenerations.clear();
  }
}
