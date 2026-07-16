part of '../mini_program_discovery.dart';

extension _MiniProgramDiscoveryOfflineFallback on MiniProgramDiscoveryResolver {
  Future<MiniProgramDiscoveryState?> _resolveOfflineDiscoveryState({
    required String miniProgramId,
    required MiniProgramDiscoverySourceKind sourceKind,
    required MiniProgramSourceException? sourceException,
    required CachedManifestEntry? cachedManifest,
    required ScreenCache screenCache,
  }) async {
    if (sourceKind != MiniProgramDiscoverySourceKind.remote ||
        cachedManifest == null ||
        !cachedManifest.manifest.allowsManifestStaleCache ||
        !_isWithinMaxStaleAge(
          cachedAt: cachedManifest.cachedAt,
          maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
        ) ||
        !_canUseOfflineCache(sourceException)) {
      return null;
    }

    final cachedEntryScreen = await screenCache.read(
      miniProgramId: miniProgramId,
      version: cachedManifest.manifest.version,
      screenId: cachedManifest.manifest.entry,
    );

    if (cachedEntryScreen == null ||
        !cachedManifest.manifest.allowsEntryScreenStaleCache ||
        !_isWithinMaxStaleAge(
          cachedAt: cachedEntryScreen.cachedAt,
          maxStaleAge: cachedManifest.manifest.entryScreenMaxStaleAge,
        )) {
      return null;
    }

    return MiniProgramDiscoveryState(
      miniProgramId: miniProgramId,
      status: MiniProgramDiscoveryStatus.staleButAllowed,
      manifest: cachedManifest.manifest,
      errorCode: sourceException?.errorCode,
      manifestCachedAt: cachedManifest.cachedAt,
      entryScreenCachedAt: cachedEntryScreen.cachedAt,
      details: <String, dynamic>{
        'offlineFallback': true,
        if (sourceException != null) ...sourceException.details,
      },
    );
  }

  bool _canUseOfflineCache(MiniProgramSourceException? sourceException) {
    final errorCode = sourceException?.errorCode;
    return errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout;
  }
}
