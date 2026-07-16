part of '../asset_resolver.dart';

extension _AssetResolverImageResolution on AssetResolver {
  Future<Map<String, dynamic>> _resolveImageWidget({
    required Map<String, dynamic> json,
    required MiniProgramManifest manifest,
    required String screenId,
    required AssetCache assetCache,
    required SdkLogger logger,
    required _AssetResolutionStats stats,
  }) async {
    final sourceUri = json['src'] as String;
    final cachedAsset = await assetCache.read(sourceUri);
    if (_canReuseCachedAsset(entry: cachedAsset, manifest: manifest)) {
      stats.cachedAssetCount++;
      return _toFileImage(json, cachedAsset!.filePath);
    }

    try {
      final response = await _client.get(Uri.parse(sourceUri));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final writtenAsset = await assetCache.write(
          sourceUri: sourceUri,
          bytes: response.bodyBytes,
          cachedAt: DateTime.now(),
          contentType: response.headers['content-type'],
          suggestedFileExtension: _extensionFromSource(sourceUri),
        );
        if (writtenAsset != null) {
          stats.downloadedAssetCount++;
          return _toFileImage(json, writtenAsset.filePath);
        }
      }
    } on TimeoutException catch (error, stackTrace) {
      logger.warn(
        'Timed out while resolving image asset for mini-program screen.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'screenId': screenId,
          'assetUrl': sourceUri,
        },
      );
      logger.error(
        'Asset resolution timeout details.',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      logger.warn(
        'Failed to download image asset for mini-program screen.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'screenId': screenId,
          'assetUrl': sourceUri,
        },
      );
      logger.error(
        'Asset resolution failure details.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final staleCachedAsset = await assetCache.read(sourceUri);
    if (_canReuseCachedAsset(entry: staleCachedAsset, manifest: manifest)) {
      stats.cachedAssetCount++;
      return _toFileImage(json, staleCachedAsset!.filePath);
    }

    stats.failedAssetCount++;
    return json;
  }

  bool _canReuseCachedAsset({
    required CachedAssetEntry? entry,
    required MiniProgramManifest manifest,
  }) {
    if (entry == null) {
      return false;
    }

    return DateTime.now().difference(entry.cachedAt) <=
        manifest.entryScreenMaxStaleAge;
  }

  Map<String, dynamic> _toFileImage(
    Map<String, dynamic> json,
    String filePath,
  ) {
    return <String, dynamic>{...json, 'imageType': 'file', 'src': filePath};
  }
}
