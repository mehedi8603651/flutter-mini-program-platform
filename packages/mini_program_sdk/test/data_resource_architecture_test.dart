import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data resource root remains a thin private part registry', () {
    final root = File(
      'lib/data/mini_program_data_resource.dart',
    ).readAsStringSync();

    expect(root.split('\n').length, lessThan(30));
    expect(
      RegExp(
        r'^(?:class|abstract class|abstract interface class|enum|typedef|const int)\s',
        multiLine: true,
      ).hasMatch(root),
      isFalse,
    );
  });

  test('data resource implementations remain private feature-owned parts', () {
    const expectedNames = <String>{
      'constants.dart',
      'loading.dart',
      'manager.dart',
      'models.dart',
      'resource_keys.dart',
      'resource_state.dart',
      'resource_validation.dart',
      'search/execution.dart',
      'search/indexing.dart',
      'search/models.dart',
      'search/ranking.dart',
    };
    final root = File(
      'lib/data/mini_program_data_resource.dart',
    ).readAsStringSync();
    final files = Directory('lib/data/runtime')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _runtimePath(file.path)).toSet();

    expect(names, expectedNames);
    for (final file in files) {
      final relativePath = _runtimePath(file.path);
      final source = file.readAsStringSync();
      final expectedPartOf = relativePath.startsWith('search/')
          ? "part of '../../mini_program_data_resource.dart';"
          : "part of '../mini_program_data_resource.dart';";
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
        root,
        contains("part 'runtime/$relativePath';"),
        reason: file.path,
      );
    }
  });

  test('public data declarations have one implementation owner', () {
    final ownership = <RegExp, String>{
      RegExp(r'^const int miniProgramJsonAssetMaxBytes\b', multiLine: true):
          'constants.dart',
      RegExp(r'^const int miniProgramJsonAssetMaxDepth\b', multiLine: true):
          'constants.dart',
      RegExp(r'^const int miniProgramJsonAssetMaxMembers\b', multiLine: true):
          'constants.dart',
      RegExp(
        r'^const int miniProgramJsonAssetPathMaxLength\b',
        multiLine: true,
      ): 'constants.dart',
      RegExp(r'^class MiniProgramDataResourceLoadResult\b', multiLine: true):
          'models.dart',
      RegExp(r'^class MiniProgramDataException\b', multiLine: true):
          'models.dart',
      RegExp(r'^class MiniProgramDataResourceManager\b', multiLine: true):
          'manager.dart',
    };
    final files = Directory('lib/data/runtime')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _runtimePath(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('data manager public operations remain actual class members', () {
    final manager = File('lib/data/runtime/manager.dart').readAsStringSync();

    for (final method in <String>['load', 'search', 'clear']) {
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(manager),
        isTrue,
        reason: '$method must remain a MiniProgramDataResourceManager member.',
      );
    }
  });

  test('data resource internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(barrel, contains("export 'data/mini_program_data_resource.dart';"));
    expect(barrel, isNot(contains('data/runtime/')));
  });
}

String _runtimePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('data/runtime/') + 13);
}
