import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/cache/asset_cache.dart' as asset;
import 'package:mini_program_sdk/cache/manifest_cache.dart' as manifest;
import 'package:mini_program_sdk/cache/runtime_file_cache.dart' as file_runtime;
import 'package:mini_program_sdk/cache/runtime_shared_preferences_cache.dart'
    as preferences_runtime;
import 'package:mini_program_sdk/cache/screen_cache.dart' as screen;

void main() {
  test('historical cache import paths retain their public declarations', () {
    expect(asset.AssetCache, isNotNull);
    expect(asset.CachedAssetEntry, isNotNull);
    expect(asset.FileAssetCache, isNotNull);
    expect(asset.NoOpAssetCache, isNotNull);

    expect(manifest.ManifestCache, isNotNull);
    expect(manifest.CachedManifestEntry, isNotNull);
    expect(manifest.FileManifestCache, isNotNull);
    expect(manifest.InMemoryManifestCache, isNotNull);

    expect(screen.ScreenCache, isNotNull);
    expect(screen.CachedScreenEntry, isNotNull);
    expect(screen.FileScreenCache, isNotNull);
    expect(screen.InMemoryScreenCache, isNotNull);
    expect(
      screen.buildScreenCacheKey(
        miniProgramId: 'app',
        version: '1',
        screenId: 'home',
      ),
      'app::1::home',
    );

    expect(file_runtime.FileMiniProgramCacheStore, isNotNull);
    expect(
      preferences_runtime.SharedPreferencesMiniProgramCacheStore,
      isNotNull,
    );
  });
}
