import 'entry.dart';

abstract interface class AssetCache {
  Future<CachedAssetEntry?> read(String sourceUri);

  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  });

  Future<void> remove(String sourceUri);

  Future<void> clear();
}
