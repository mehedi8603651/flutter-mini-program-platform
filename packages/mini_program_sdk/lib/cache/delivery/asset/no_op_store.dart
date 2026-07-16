import 'entry.dart';
import 'store.dart';

class NoOpAssetCache implements AssetCache {
  const NoOpAssetCache();

  static const NoOpAssetCache shared = NoOpAssetCache();

  @override
  Future<CachedAssetEntry?> read(String sourceUri) async => null;

  @override
  Future<CachedAssetEntry?> write({
    required String sourceUri,
    required List<int> bytes,
    required DateTime cachedAt,
    String? contentType,
    String? suggestedFileExtension,
  }) async {
    return null;
  }

  @override
  Future<void> remove(String sourceUri) async {}

  @override
  Future<void> clear() async {}
}
