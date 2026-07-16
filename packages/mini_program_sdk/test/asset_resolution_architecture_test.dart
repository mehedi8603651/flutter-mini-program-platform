import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset resolver root remains a thin private part registry', () {
    final root = File('lib/network/asset_resolver.dart').readAsStringSync();

    expect(root.split('\n').length, lessThan(20));
    expect(
      RegExp(
        r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
        multiLine: true,
      ).hasMatch(root),
      isFalse,
    );
  });

  test(
    'asset resolution implementations remain private feature-owned parts',
    () {
      const expectedNames = <String>{
        'detection.dart',
        'image_resolution.dart',
        'models.dart',
        'resolver.dart',
        'traversal.dart',
      };
      final root = File('lib/network/asset_resolver.dart').readAsStringSync();
      final files = Directory('lib/network/asset_resolution')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false);
      final names = files.map((file) => _fileName(file.path)).toSet();

      expect(names, expectedNames);
      for (final file in files) {
        final name = _fileName(file.path);
        final source = file.readAsStringSync();

        expect(
          source.trimLeft(),
          startsWith("part of '../asset_resolver.dart';"),
          reason: file.path,
        );
        expect(
          RegExp(
            r'^\s*(?:import|export|library)\s',
            multiLine: true,
          ).hasMatch(source),
          isFalse,
          reason: file.path,
        );
        expect(
          root,
          contains("part 'asset_resolution/$name';"),
          reason: file.path,
        );
      }
    },
  );

  test('public asset declarations have one implementation owner', () {
    final ownership = <RegExp, String>{
      RegExp(r'^class AssetResolutionResult\b', multiLine: true): 'models.dart',
      RegExp(r'^class AssetResolver\b', multiLine: true): 'resolver.dart',
    };
    final files = Directory('lib/network/asset_resolution')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _fileName(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('public resolve operations remain actual class members', () {
    final resolver = File(
      'lib/network/asset_resolution/resolver.dart',
    ).readAsStringSync();

    for (final method in <String>[
      'resolveEntryScreenAssets',
      'resolveScreenAssets',
    ]) {
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(resolver),
        isTrue,
        reason: '$method must remain an AssetResolver member.',
      );
    }
  });

  test('asset resolution internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(barrel, contains("export 'network/asset_resolver.dart';"));
    expect(barrel, isNot(contains('network/asset_resolution/')));
  });
}

String _fileName(String path) {
  return path.replaceAll('\\', '/').split('/').last;
}
