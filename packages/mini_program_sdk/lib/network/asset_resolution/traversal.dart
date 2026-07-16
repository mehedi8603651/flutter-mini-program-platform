part of '../asset_resolver.dart';

extension _AssetResolverTraversal on AssetResolver {
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
}
