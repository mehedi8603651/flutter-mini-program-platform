part of '../asset_resolver.dart';

class AssetResolutionResult {
  const AssetResolutionResult({
    required this.screenJson,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
  });

  final Map<String, dynamic> screenJson;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;
}

class _AssetResolutionStats {
  int cachedAssetCount = 0;
  int downloadedAssetCount = 0;
  int failedAssetCount = 0;
}
