import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'cache/manifest_cache.dart';
import 'cache/screen_cache.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'mini_program_failure.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'version_validator.dart';

/// Fully resolved mini-program state ready for rendering.
class LoadedMiniProgram {
  const LoadedMiniProgram({
    required this.manifest,
    required this.entryScreenJson,
    this.usedStaleManifestCache = false,
    this.usedStaleEntryScreenCache = false,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
  });

  final MiniProgramManifest manifest;
  final Map<String, dynamic> entryScreenJson;
  final bool usedStaleManifestCache;
  final bool usedStaleEntryScreenCache;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  bool get usedStaleCache =>
      usedStaleManifestCache || usedStaleEntryScreenCache;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;
}

/// Loads, validates, and resolves the entry screen for a mini-program.
class ManifestLoader {
  const ManifestLoader({this.versionValidator = const VersionValidator()});

  final VersionValidator versionValidator;

  Future<LoadedMiniProgram> load({
    required String miniProgramId,
    required String sdkVersion,
    required MiniProgramSource source,
    required ManifestCache manifestCache,
    required ScreenCache screenCache,
    required CapabilityRegistry capabilityRegistry,
    required FeatureFlagEvaluator featureFlagEvaluator,
    required SdkLogger logger,
  }) async {
    final manifestResult = await _loadManifestWithCache(
      miniProgramId: miniProgramId,
      source: source,
      manifestCache: manifestCache,
      logger: logger,
    );
    final manifest = manifestResult.manifest;

    final versionFailure = versionValidator.validate(
      manifest: manifest,
      sdkVersion: sdkVersion,
    );
    if (versionFailure != null) {
      logger.warn(
        'Manifest rejected by SDK version validation.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'sdkVersionRange': manifest.sdkVersionRange.value,
          'hostSdkVersion': sdkVersion,
        },
      );
      throw MiniProgramLoadException(versionFailure);
    }

    final missingCapabilities = capabilityRegistry.missingCapabilities(
      manifest.requiredCapabilities,
    );
    if (missingCapabilities.isNotEmpty) {
      final missingWireValues =
          missingCapabilities.map((capability) => capability.wireValue).toList()
            ..sort();

      logger.warn(
        'Manifest rejected because required capabilities are missing.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'missingCapabilities': missingWireValues.join(', '),
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode: MiniProgramErrorCodes.unsupportedCapability,
          message:
              'Host app does not support required capabilities: ${missingWireValues.join(', ')}.',
          fallback: manifest.fallback,
          details: <String, dynamic>{
            'miniProgramId': manifest.id,
            'missingCapabilities': missingWireValues,
          },
        ),
      );
    }

    final disabledFlags =
        manifest.featureFlags
            .where((flag) => !featureFlagEvaluator.isEnabled(flag))
            .toList()
          ..sort();
    if (disabledFlags.isNotEmpty) {
      logger.warn(
        'Manifest rejected because required feature flags are disabled.',
        context: <String, Object?>{
          'miniProgramId': manifest.id,
          'disabledFeatureFlags': disabledFlags.join(', '),
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          message:
              'Required feature flags are disabled: ${disabledFlags.join(', ')}.',
          fallback: manifest.fallback,
          details: <String, dynamic>{
            'miniProgramId': manifest.id,
            'disabledFeatureFlags': disabledFlags,
          },
        ),
      );
    }

    final screenResult = await _loadEntryScreenWithCache(
      miniProgramId: miniProgramId,
      manifest: manifest,
      source: source,
      screenCache: screenCache,
      logger: logger,
    );

    return LoadedMiniProgram(
      manifest: manifest,
      entryScreenJson: screenResult.screenJson,
      usedStaleManifestCache: manifestResult.usedStaleCache,
      usedStaleEntryScreenCache: screenResult.usedStaleCache,
    );
  }

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

  Future<_ScreenLoadResult> _loadEntryScreenWithCache({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required MiniProgramSource source,
    required ScreenCache screenCache,
    required SdkLogger logger,
  }) async {
    final cachedScreen = await screenCache.read(
      miniProgramId: miniProgramId,
      version: manifest.version,
      screenId: manifest.entry,
    );

    try {
      final entryScreenJson = await source.loadScreen(
        miniProgramId: miniProgramId,
        version: manifest.version,
        screenId: manifest.entry,
      );

      if (entryScreenJson.isEmpty) {
        throw const FormatException('Entry screen JSON is empty.');
      }

      if (manifest.allowsEntryScreenStaleCache) {
        await screenCache.write(
          CachedScreenEntry(
            miniProgramId: miniProgramId,
            version: manifest.version,
            screenId: manifest.entry,
            screenJson: Map<String, dynamic>.from(entryScreenJson),
            cachedAt: DateTime.now(),
          ),
        );
      } else {
        await screenCache.remove(
          miniProgramId: miniProgramId,
          version: manifest.version,
          screenId: manifest.entry,
        );
      }

      return _ScreenLoadResult(screenJson: entryScreenJson);
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
          'Using stale cached entry screen after backend load failure.',
          context: <String, Object?>{
            'miniProgramId': miniProgramId,
            'entryScreen': manifest.entry,
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
        'Failed to load entry screen JSON.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': miniProgramId,
          'entryScreen': manifest.entry,
        },
      );
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode:
              sourceException?.errorCode ??
              MiniProgramErrorCodes.manifestParseFailure,
          message:
              sourceException?.message ??
              'Failed to load entry screen "${manifest.entry}" for mini-program "${manifest.id}".',
          fallback: manifest.fallback,
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'entryScreen': manifest.entry,
            if (cachedScreen != null) ...<String, dynamic>{
              'cachedEntryScreenAt': cachedScreen.cachedAt.toIso8601String(),
              'entryScreenMaxStaleSeconds':
                  manifest.entryScreenMaxStaleAge.inSeconds,
              'entryScreenCacheExpired': !_isWithinMaxStaleAge(
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

  bool _canUseStaleCache(MiniProgramSourceException? sourceException) {
    final errorCode = sourceException?.errorCode;
    return errorCode == MiniProgramErrorCodes.backendUnreachable ||
        errorCode == MiniProgramErrorCodes.backendTimeout;
  }

  bool _isWithinMaxStaleAge({
    required DateTime cachedAt,
    required Duration maxStaleAge,
  }) {
    return DateTime.now().difference(cachedAt) <= maxStaleAge;
  }
}

class _ManifestLoadResult {
  const _ManifestLoadResult({
    required this.manifest,
    this.usedStaleCache = false,
  });

  final MiniProgramManifest manifest;
  final bool usedStaleCache;
}

class _ScreenLoadResult {
  const _ScreenLoadResult({
    required this.screenJson,
    this.usedStaleCache = false,
  });

  final Map<String, dynamic> screenJson;
  final bool usedStaleCache;
}
