part of '../asset_resolver.dart';

/// Resolves standard Mp image nodes to local file-backed assets when the
/// manifest allows entry-screen caching.
class AssetResolver {
  AssetResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AssetResolutionResult> resolveEntryScreenAssets({
    required MiniProgramManifest manifest,
    required Map<String, dynamic> screenJson,
    required AssetCache assetCache,
    required SdkLogger logger,
  }) async {
    return resolveScreenAssets(
      manifest: manifest,
      screenId: manifest.entry,
      screenJson: screenJson,
      assetCache: assetCache,
      logger: logger,
    );
  }

  Future<AssetResolutionResult> resolveScreenAssets({
    required MiniProgramManifest manifest,
    required String screenId,
    required Map<String, dynamic> screenJson,
    required AssetCache assetCache,
    required SdkLogger logger,
  }) async {
    if (!manifest.allowsEntryScreenStaleCache) {
      return AssetResolutionResult(
        screenJson: Map<String, dynamic>.from(screenJson),
      );
    }

    final stats = _AssetResolutionStats();
    final resolved = await _resolveValue(
      value: screenJson,
      manifest: manifest,
      screenId: screenId,
      assetCache: assetCache,
      logger: logger,
      stats: stats,
    );

    return AssetResolutionResult(
      screenJson: Map<String, dynamic>.from(resolved as Map),
      cachedAssetCount: stats.cachedAssetCount,
      downloadedAssetCount: stats.downloadedAssetCount,
      failedAssetCount: stats.failedAssetCount,
    );
  }
}
