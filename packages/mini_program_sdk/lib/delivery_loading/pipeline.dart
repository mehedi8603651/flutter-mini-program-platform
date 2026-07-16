part of '../manifest_loader.dart';

extension _ManifestLoadingPipeline on ManifestLoader {
  Future<LoadedMiniProgram> _loadMiniProgram({
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

    _validateManifestForHost(
      manifest: manifest,
      sdkVersion: sdkVersion,
      capabilityRegistry: capabilityRegistry,
      featureFlagEvaluator: featureFlagEvaluator,
      logger: logger,
    );

    final screenResult = await loadScreen(
      miniProgramId: miniProgramId,
      manifest: manifest,
      screenId: manifest.entry,
      source: source,
      screenCache: screenCache,
      logger: logger,
    );
    final publisherBackendContract = await _loadPublisherBackendContract(
      miniProgramId: miniProgramId,
      manifest: manifest,
      source: source,
      logger: logger,
    );

    return LoadedMiniProgram(
      manifest: manifest,
      entryScreenJson: screenResult.screenJson,
      publisherBackendContract: publisherBackendContract,
      usedStaleManifestCache: manifestResult.usedStaleCache,
      usedStaleEntryScreenCache: screenResult.usedStaleCache,
    );
  }

  Future<LoadedMiniProgramScreen> _loadResolvedScreen({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required String screenId,
    required MiniProgramSource source,
    required ScreenCache screenCache,
    required SdkLogger logger,
  }) async {
    final screenResult = await _loadScreenWithCache(
      miniProgramId: miniProgramId,
      manifest: manifest,
      screenId: screenId,
      source: source,
      screenCache: screenCache,
      logger: logger,
    );

    return LoadedMiniProgramScreen(
      screenId: screenId,
      screenJson: screenResult.screenJson,
      usedStaleCache: screenResult.usedStaleCache,
    );
  }
}
