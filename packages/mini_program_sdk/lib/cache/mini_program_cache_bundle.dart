import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'asset_cache.dart';
import 'manifest_cache.dart';
import 'runtime_file_cache.dart';
import 'runtime_cache.dart';
import 'screen_cache.dart';

/// Cache bundle used by hosts to pass both manifest and screen cache stores.
@immutable
class MiniProgramCacheBundle {
  const MiniProgramCacheBundle({
    required this.manifestCache,
    required this.screenCache,
    required this.assetCache,
    required this.runtimeCache,
  });

  factory MiniProgramCacheBundle.inMemory() {
    return MiniProgramCacheBundle(
      manifestCache: InMemoryManifestCache(),
      screenCache: InMemoryScreenCache(),
      assetCache: NoOpAssetCache.shared,
      runtimeCache: MiniProgramCacheManager.inMemory(),
    );
  }

  factory MiniProgramCacheBundle.fileBacked({
    required Directory rootDirectory,
  }) {
    return MiniProgramCacheBundle(
      manifestCache: FileManifestCache(
        directory: Directory(p.join(rootDirectory.path, 'manifests')),
      ),
      screenCache: FileScreenCache(
        directory: Directory(p.join(rootDirectory.path, 'screens')),
      ),
      assetCache: FileAssetCache(
        directory: Directory(p.join(rootDirectory.path, 'assets')),
      ),
      runtimeCache: MiniProgramCacheManager(
        store: FileMiniProgramCacheStore(
          directory: Directory(p.join(rootDirectory.path, 'runtime')),
        ),
      ),
    );
  }

  final ManifestCache manifestCache;
  final ScreenCache screenCache;
  final AssetCache assetCache;
  final MiniProgramCacheManager runtimeCache;
}
