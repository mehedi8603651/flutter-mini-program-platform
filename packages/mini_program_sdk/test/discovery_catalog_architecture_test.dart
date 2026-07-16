import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog and discovery roots remain thin private part registries', () {
    for (final path in <String>[
      'lib/network/published_mini_program_catalog_client.dart',
      'lib/mini_program_discovery.dart',
    ]) {
      final root = File(path).readAsStringSync();

      expect(root.split('\n').length, lessThan(20), reason: path);
      expect(
        RegExp(
          r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
          multiLine: true,
        ).hasMatch(root),
        isFalse,
        reason: path,
      );
    }
  });

  test('catalog and discovery implementations remain private parts', () {
    const catalogNames = <String>{
      'client.dart',
      'errors.dart',
      'models.dart',
      'parsing.dart',
      'transport.dart',
    };
    const discoveryNames = <String>{
      'cache.dart',
      'messages.dart',
      'models.dart',
      'offline_fallback.dart',
      'resolver.dart',
    };
    final catalogRoot = File(
      'lib/network/published_mini_program_catalog_client.dart',
    ).readAsStringSync();
    final discoveryRoot = File(
      'lib/mini_program_discovery.dart',
    ).readAsStringSync();

    _expectPrivateParts(
      directoryPath: 'lib/network/published_catalog',
      expectedNames: catalogNames,
      expectedPartOf:
          "part of '../published_mini_program_catalog_client.dart';",
      rootSource: catalogRoot,
      partPrefix: 'published_catalog',
    );
    _expectPrivateParts(
      directoryPath: 'lib/discovery_runtime',
      expectedNames: discoveryNames,
      expectedPartOf: "part of '../mini_program_discovery.dart';",
      rootSource: discoveryRoot,
      partPrefix: 'discovery_runtime',
    );
  });

  test('public catalog and discovery declarations have one owner', () {
    final ownership = <RegExp, String>{
      RegExp(r'^class PublishedMiniProgramCatalog\b', multiLine: true):
          'network/published_catalog/models.dart',
      RegExp(r'^class PublishedMiniProgramSummary\b', multiLine: true):
          'network/published_catalog/models.dart',
      RegExp(r'^class PublishedMiniProgramCatalogClient\b', multiLine: true):
          'network/published_catalog/client.dart',
      RegExp(r'^enum MiniProgramDiscoverySourceKind\b', multiLine: true):
          'discovery_runtime/models.dart',
      RegExp(r'^enum MiniProgramDiscoveryStatus\b', multiLine: true):
          'discovery_runtime/models.dart',
      RegExp(r'^class MiniProgramDiscoveryState\b', multiLine: true):
          'discovery_runtime/models.dart',
      RegExp(r'^class MiniProgramDiscoveryResolver\b', multiLine: true):
          'discovery_runtime/resolver.dart',
    };
    final files = <File>[
      ...Directory(
        'lib/network/published_catalog',
      ).listSync().whereType<File>(),
      ...Directory('lib/discovery_runtime').listSync().whereType<File>(),
    ].where((file) => file.path.endsWith('.dart')).toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _ownedPath(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('public list and resolve operations remain actual class members', () {
    final client = File(
      'lib/network/published_catalog/client.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/discovery_runtime/resolver.dart',
    ).readAsStringSync();

    expect(client, contains('listAvailableMiniPrograms()'));
    expect(resolver, contains('resolve({'));
  });

  test('catalog and discovery internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(
      barrel,
      contains("export 'network/published_mini_program_catalog_client.dart';"),
    );
    expect(barrel, contains("export 'mini_program_discovery.dart';"));
    expect(barrel, isNot(contains('network/published_catalog/')));
    expect(barrel, isNot(contains('discovery_runtime/')));
  });
}

void _expectPrivateParts({
  required String directoryPath,
  required Set<String> expectedNames,
  required String expectedPartOf,
  required String rootSource,
  required String partPrefix,
}) {
  final files = Directory(directoryPath)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);
  final names = files.map((file) => _fileName(file.path)).toSet();

  expect(names, expectedNames);
  for (final file in files) {
    final name = _fileName(file.path);
    final source = file.readAsStringSync();

    expect(source.trimLeft(), startsWith(expectedPartOf), reason: file.path);
    expect(
      RegExp(
        r'^\s*(?:import|export|library)\s',
        multiLine: true,
      ).hasMatch(source),
      isFalse,
      reason: file.path,
    );
    expect(
      rootSource,
      contains("part '$partPrefix/$name';"),
      reason: file.path,
    );
  }
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

String _ownedPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final libIndex = normalized.indexOf('lib/');
  return normalized.substring(libIndex + 4);
}
