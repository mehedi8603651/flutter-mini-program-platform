import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../cache/asset_cache.dart';
import '../observability/sdk_logger.dart';

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

/// Resolves standard Stac image widgets to local file-backed assets when the
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

  Future<Object?> _resolveValue({
    required Object? value,
    required MiniProgramManifest manifest,
    required String screenId,
    required AssetCache assetCache,
    required SdkLogger logger,
    required _AssetResolutionStats stats,
  }) async {
    if (value is List) {
      final resolved = <Object?>[];
      for (final item in value) {
        resolved.add(
          await _resolveValue(
            value: item,
            manifest: manifest,
            screenId: screenId,
            assetCache: assetCache,
            logger: logger,
            stats: stats,
          ),
        );
      }
      return resolved;
    }

    if (value is Map) {
      final json = value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
      if (_isNetworkImageWidget(json)) {
        return _resolveImageWidget(
          json: json,
          manifest: manifest,
          screenId: screenId,
          assetCache: assetCache,
          logger: logger,
          stats: stats,
        );
      }

      final resolved = <String, dynamic>{};
      for (final entry in json.entries) {
        resolved[entry.key] = await _resolveValue(
          value: entry.value,
          manifest: manifest,
          screenId: screenId,
          assetCache: assetCache,
          logger: logger,
          stats: stats,
        );
      }
      return resolved;
    }

    return value;
  }

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

  bool _isNetworkImageWidget(Map<String, dynamic> json) {
    if (json['type'] != 'image') {
      return false;
    }

    final sourceUri = json['src'];
    if (sourceUri is! String || !_looksLikeRemoteUrl(sourceUri)) {
      return false;
    }

    final imageType = json['imageType'];
    return imageType == null || imageType == 'network';
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

  bool _looksLikeRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String? _extensionFromSource(String sourceUri) {
    final uri = Uri.tryParse(sourceUri);
    if (uri == null) {
      return null;
    }

    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) {
      return '.png';
    }
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (path.endsWith('.webp')) {
      return '.webp';
    }
    if (path.endsWith('.svg')) {
      return '.svg';
    }
    if (path.endsWith('.gif')) {
      return '.gif';
    }
    return null;
  }
}

class _AssetResolutionStats {
  int cachedAssetCount = 0;
  int downloadedAssetCount = 0;
  int failedAssetCount = 0;
}
