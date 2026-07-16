part of '../manifest_loader.dart';

extension _ScreenCacheLoading on ManifestLoader {
  Future<_ScreenLoadResult> _loadScreenWithCache({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required String screenId,
    required MiniProgramSource source,
    required ScreenCache screenCache,
    required SdkLogger logger,
  }) async {
    final cachedScreen = await screenCache.read(
      miniProgramId: miniProgramId,
      version: manifest.version,
      screenId: screenId,
    );

    try {
      final screenJson = await source.loadScreen(
        miniProgramId: miniProgramId,
        version: manifest.version,
        screenId: screenId,
      );

      if (screenJson.isEmpty) {
        throw FormatException('Screen JSON is empty for "$screenId".');
      }

      if (manifest.allowsEntryScreenStaleCache) {
        await screenCache.write(
          CachedScreenEntry(
            miniProgramId: miniProgramId,
            version: manifest.version,
            screenId: screenId,
            screenJson: Map<String, dynamic>.from(screenJson),
            cachedAt: DateTime.now(),
          ),
        );
      } else {
        await screenCache.remove(
          miniProgramId: miniProgramId,
          version: manifest.version,
          screenId: screenId,
        );
      }

      return _ScreenLoadResult(screenJson: screenJson);
    } catch (error, stackTrace) {
      final sourceException = error is MiniProgramSourceException
          ? error
          : null;
      if (cachedScreen != null &&
          manifest.allowsEntryScreenStaleCache &&
          _isWithinMaxStaleAge(
            cachedAt: cachedScreen.cachedAt,
            maxStaleAge: manifest.entryScreenMaxStaleAge,
          ) &&
          _canUseStaleCache(sourceException)) {
        logger.warn(
          'Using stale cached mini-program screen after backend load failure.',
          context: <String, Object?>{
            'miniProgramId': miniProgramId,
            'screenId': screenId,
            'cachedAt': cachedScreen.cachedAt.toIso8601String(),
            'maxStaleSeconds': manifest.entryScreenMaxStaleAge.inSeconds,
            'errorCode': sourceException?.errorCode ?? 'unknown',
          },
        );
        return _ScreenLoadResult(
          screenJson: cachedScreen.screenJson,
          usedStaleCache: true,
        );
      }

      logger.error(
        'Failed to load mini-program screen JSON.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': miniProgramId,
          'screenId': screenId,
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode:
              sourceException?.errorCode ??
              MiniProgramErrorCodes.manifestParseFailure,
          message:
              sourceException?.message ??
              'Failed to load screen "$screenId" for mini-program "${manifest.id}".',
          fallback: manifest.fallback,
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'screenId': screenId,
            if (cachedScreen != null) ...<String, dynamic>{
              'cachedScreenAt': cachedScreen.cachedAt.toIso8601String(),
              'screenMaxStaleSeconds':
                  manifest.entryScreenMaxStaleAge.inSeconds,
              'screenCacheExpired': !_isWithinMaxStaleAge(
                cachedAt: cachedScreen.cachedAt,
                maxStaleAge: manifest.entryScreenMaxStaleAge,
              ),
            },
            if (sourceException != null) ...sourceException.details,
          },
        ),
      );
    }
  }
}
