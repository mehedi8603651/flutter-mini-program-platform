part of '../mini_program_discovery.dart';

/// Resolves list-level availability without fully opening the mini-program UI.
class MiniProgramDiscoveryResolver {
  const MiniProgramDiscoveryResolver({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Future<MiniProgramDiscoveryState> resolve({
    required String miniProgramId,
    required MiniProgramSource source,
    required ManifestCache manifestCache,
    required ScreenCache screenCache,
    required MiniProgramDiscoverySourceKind sourceKind,
  }) async {
    final cachedManifest = await manifestCache.read(miniProgramId);

    try {
      final manifest = await source.loadManifest(miniProgramId);
      if (sourceKind == MiniProgramDiscoverySourceKind.remote) {
        await _updateManifestCache(
          miniProgramId: miniProgramId,
          manifest: manifest,
          manifestCache: manifestCache,
        );
      }

      return MiniProgramDiscoveryState(
        miniProgramId: miniProgramId,
        status: switch (sourceKind) {
          MiniProgramDiscoverySourceKind.bundled =>
            MiniProgramDiscoveryStatus.cached,
          MiniProgramDiscoverySourceKind.remote =>
            MiniProgramDiscoveryStatus.live,
        },
        manifest: manifest,
      );
    } catch (error) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;
      final offlineState = await _resolveOfflineDiscoveryState(
        miniProgramId: miniProgramId,
        sourceKind: sourceKind,
        sourceException: sourceException,
        cachedManifest: cachedManifest,
        screenCache: screenCache,
      );
      if (offlineState != null) {
        return offlineState;
      }

      return MiniProgramDiscoveryState(
        miniProgramId: miniProgramId,
        status: MiniProgramDiscoveryStatus.unavailable,
        manifest: cachedManifest?.manifest,
        errorCode: sourceException?.errorCode,
        manifestCachedAt: cachedManifest?.cachedAt,
        message: _unavailableMessage(sourceKind, sourceException),
        details: <String, dynamic>{
          if (cachedManifest != null) ...<String, dynamic>{
            'manifestCacheExpired': !_isWithinMaxStaleAge(
              cachedAt: cachedManifest.cachedAt,
              maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
            ),
          },
          if (sourceException != null) ...sourceException.details,
        },
      );
    }
  }
}
