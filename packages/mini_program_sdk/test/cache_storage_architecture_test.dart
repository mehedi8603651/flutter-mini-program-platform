import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy cache files remain thin compatibility barrels', () {
    final expectedExports = <String, List<String>>{
      'lib/cache/manifest_cache.dart': <String>[
        "export 'delivery/manifest/entry.dart' show CachedManifestEntry;",
        "export 'delivery/manifest/file_store.dart' show FileManifestCache;",
        "export 'delivery/manifest/memory_store.dart' show InMemoryManifestCache;",
        "export 'delivery/manifest/store.dart' show ManifestCache;",
      ],
      'lib/cache/screen_cache.dart': <String>[
        "export 'delivery/screen/entry.dart' show CachedScreenEntry;",
        "export 'delivery/screen/file_store.dart' show FileScreenCache;",
        "export 'delivery/screen/keys.dart' show buildScreenCacheKey;",
        "export 'delivery/screen/memory_store.dart' show InMemoryScreenCache;",
        "export 'delivery/screen/store.dart' show ScreenCache;",
      ],
      'lib/cache/asset_cache.dart': <String>[
        "export 'delivery/asset/entry.dart' show CachedAssetEntry;",
        "export 'delivery/asset/file_store.dart' show FileAssetCache;",
        "export 'delivery/asset/no_op_store.dart' show NoOpAssetCache;",
        "export 'delivery/asset/store.dart' show AssetCache;",
      ],
      'lib/cache/runtime_file_cache.dart': <String>[
        "export 'persistence/file_runtime_store.dart' show FileMiniProgramCacheStore;",
      ],
      'lib/cache/runtime_shared_preferences_cache.dart': <String>[
        "export 'persistence/preferences_runtime_store.dart'",
        'show SharedPreferencesMiniProgramCacheStore;',
      ],
    };

    for (final entry in expectedExports.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source.split('\n').length, lessThan(10), reason: entry.key);
      expect(
        RegExp(
          r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
        reason: entry.key,
      );
      for (final export in entry.value) {
        expect(source, contains(export), reason: entry.key);
      }
    }
  });

  test('delivery cache declarations have one feature owner', () {
    final ownership = <RegExp, String>{
      RegExp(r'^class CachedManifestEntry\b', multiLine: true):
          'delivery/manifest/entry.dart',
      RegExp(r'^abstract interface class ManifestCache\b', multiLine: true):
          'delivery/manifest/store.dart',
      RegExp(r'^class InMemoryManifestCache\b', multiLine: true):
          'delivery/manifest/memory_store.dart',
      RegExp(r'^class FileManifestCache\b', multiLine: true):
          'delivery/manifest/file_store.dart',
      RegExp(r'^class CachedScreenEntry\b', multiLine: true):
          'delivery/screen/entry.dart',
      RegExp(r'^abstract interface class ScreenCache\b', multiLine: true):
          'delivery/screen/store.dart',
      RegExp(r'^class InMemoryScreenCache\b', multiLine: true):
          'delivery/screen/memory_store.dart',
      RegExp(r'^class FileScreenCache\b', multiLine: true):
          'delivery/screen/file_store.dart',
      RegExp(r'^String buildScreenCacheKey\b', multiLine: true):
          'delivery/screen/keys.dart',
      RegExp(r'^class CachedAssetEntry\b', multiLine: true):
          'delivery/asset/entry.dart',
      RegExp(r'^abstract interface class AssetCache\b', multiLine: true):
          'delivery/asset/store.dart',
      RegExp(r'^class NoOpAssetCache\b', multiLine: true):
          'delivery/asset/no_op_store.dart',
      RegExp(r'^class FileAssetCache\b', multiLine: true):
          'delivery/asset/file_store.dart',
    };
    final files = Directory('lib/cache/delivery')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _relativeCachePath(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('runtime persistence adapters share one internal entry codec', () {
    final fileStore = File(
      'lib/cache/persistence/file_runtime_store.dart',
    ).readAsStringSync();
    final preferencesStore = File(
      'lib/cache/persistence/preferences_runtime_store.dart',
    ).readAsStringSync();
    final codec = File(
      'lib/cache/persistence/runtime_entry_codec.dart',
    ).readAsStringSync();

    for (final source in <String>[fileStore, preferencesStore]) {
      expect(source, contains("import 'runtime_entry_codec.dart';"));
      expect(source, contains('encodeRuntimeCacheEntry(entry)'));
      expect(source, contains('decodeRuntimeCacheEntry('));
      expect(source, isNot(contains("'schemaVersion':")));
    }
    expect(codec, contains('runtimeCachePersistenceSchemaVersion = 1'));
    expect(codec, contains("'schemaVersion':"));
    expect(codec, contains("'lastAccessedAt':"));
  });

  test('internal cache codecs are not exported as SDK APIs', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(barrel, contains("export 'cache/manifest_cache.dart';"));
    expect(barrel, contains("export 'cache/screen_cache.dart';"));
    expect(barrel, contains("export 'cache/asset_cache.dart';"));
    expect(barrel, contains("export 'cache/runtime_file_cache.dart';"));
    expect(
      barrel,
      contains("export 'cache/runtime_shared_preferences_cache.dart';"),
    );
    expect(barrel, isNot(contains('cache/delivery/')));
    expect(barrel, isNot(contains('cache/persistence/')));
  });
}

String _relativeCachePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('delivery/'));
}
