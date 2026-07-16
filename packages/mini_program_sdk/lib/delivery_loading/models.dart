part of '../manifest_loader.dart';

/// Fully resolved mini-program state ready for rendering.
class LoadedMiniProgram {
  const LoadedMiniProgram({
    required this.manifest,
    required this.entryScreenJson,
    this.publisherBackendContract,
    this.usedStaleManifestCache = false,
    this.usedStaleEntryScreenCache = false,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
  });

  final MiniProgramManifest manifest;
  final Map<String, dynamic> entryScreenJson;
  final MiniProgramPublisherBackendContract? publisherBackendContract;
  final bool usedStaleManifestCache;
  final bool usedStaleEntryScreenCache;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  bool get usedStaleCache =>
      usedStaleManifestCache || usedStaleEntryScreenCache;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;
}

/// Resolved screen JSON ready for rendering within an already-loaded mini-program.
class LoadedMiniProgramScreen {
  const LoadedMiniProgramScreen({
    required this.screenId,
    required this.screenJson,
    this.usedStaleCache = false,
  });

  final String screenId;
  final Map<String, dynamic> screenJson;
  final bool usedStaleCache;
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
