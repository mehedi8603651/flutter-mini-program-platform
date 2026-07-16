part of '../manifest_loader.dart';

extension _ManifestCacheLoading on ManifestLoader {
  Future<_ManifestLoadResult> _loadManifestWithCache({
    required String miniProgramId,
    required MiniProgramSource source,
    required ManifestCache manifestCache,
    required SdkLogger logger,
  }) async {
    final cachedManifest = await manifestCache.read(miniProgramId);

    try {
      final manifest = await source.loadManifest(miniProgramId);
      if (manifest.allowsManifestStaleCache) {
        await manifestCache.write(
          CachedManifestEntry(
            miniProgramId: miniProgramId,
            manifest: manifest,
            cachedAt: DateTime.now(),
          ),
        );
      } else {
        await manifestCache.remove(miniProgramId);
      }

      return _ManifestLoadResult(manifest: manifest);
    } catch (error, stackTrace) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;
      if (cachedManifest != null &&
          cachedManifest.manifest.allowsManifestStaleCache &&
          _isWithinMaxStaleAge(
            cachedAt: cachedManifest.cachedAt,
            maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
          ) &&
          _canUseStaleCache(sourceException)) {
        logger.warn(
          'Using stale cached manifest after backend load failure.',
          context: <String, Object?>{
            'miniProgramId': miniProgramId,
            'cachedAt': cachedManifest.cachedAt.toIso8601String(),
            'maxStaleSeconds':
                cachedManifest.manifest.manifestMaxStaleAge.inSeconds,
            'errorCode': sourceException?.errorCode ?? 'unknown',
          },
        );
        return _ManifestLoadResult(
          manifest: cachedManifest.manifest,
          usedStaleCache: true,
        );
      }

      logger.error(
        'Failed to load manifest.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': miniProgramId},
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode:
              sourceException?.errorCode ??
              MiniProgramErrorCodes.manifestParseFailure,
          message:
              sourceException?.message ??
              'Failed to load manifest for mini-program "$miniProgramId".',
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            if (cachedManifest != null) ...<String, dynamic>{
              'cachedManifestAt': cachedManifest.cachedAt.toIso8601String(),
              'manifestMaxStaleSeconds':
                  cachedManifest.manifest.manifestMaxStaleAge.inSeconds,
              'manifestCacheExpired': !_isWithinMaxStaleAge(
                cachedAt: cachedManifest.cachedAt,
                maxStaleAge: cachedManifest.manifest.manifestMaxStaleAge,
              ),
            },
            if (sourceException != null) ...sourceException.details,
          },
        ),
      );
    }
  }
}
