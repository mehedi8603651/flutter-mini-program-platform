part of '../mini_program_discovery.dart';

extension _MiniProgramDiscoveryCache on MiniProgramDiscoveryResolver {
  Future<void> _updateManifestCache({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required ManifestCache manifestCache,
  }) async {
    if (manifest.allowsManifestStaleCache) {
      await manifestCache.write(
        CachedManifestEntry(
          miniProgramId: miniProgramId,
          manifest: manifest,
          cachedAt: _now(),
        ),
      );
      return;
    }

    await manifestCache.remove(miniProgramId);
  }

  bool _isWithinMaxStaleAge({
    required DateTime cachedAt,
    required Duration maxStaleAge,
  }) {
    return _now().difference(cachedAt) <= maxStaleAge;
  }
}
