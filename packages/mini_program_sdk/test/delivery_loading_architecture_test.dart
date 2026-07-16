import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ManifestLoader remains a thin public delivery facade', () {
    final source = File('lib/manifest_loader.dart').readAsStringSync();
    expect(source.split('\n').length, lessThan(100));

    final classNames = RegExp(
      r'^class\s+([A-Za-z0-9_]+)',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)).toList();
    expect(classNames, <String>['ManifestLoader']);
    expect(source, contains('Future<LoadedMiniProgram> load('));
    expect(source, contains('Future<LoadedMiniProgramScreen> loadScreen('));
    expect(source, isNot(contains('final cachedManifest')));
    expect(source, isNot(contains('final cachedScreen')));
  });

  test('delivery loading remains private feature-owned parts', () {
    final directory = Directory('lib/delivery_loading');
    expect(directory.existsSync(), isTrue);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _fileName(file.path)).toSet();

    expect(names, <String>{
      'manifest_cache.dart',
      'models.dart',
      'pipeline.dart',
      'publisher_backend.dart',
      'screen_cache.dart',
      'stale_cache.dart',
      'validation.dart',
    });

    final loaderSource = File('lib/manifest_loader.dart').readAsStringSync();
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source.trimLeft(),
        startsWith("part of '../manifest_loader.dart';"),
        reason: '${file.path} must remain part of manifest_loader.dart.',
      );
      expect(
        RegExp(
          r'^\s*(?:import|export|library)\s',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
        reason: '${file.path} must not define a separate Dart library.',
      );
      final firstLineEnd = source.indexOf('\n');
      final body = firstLineEnd < 0 ? '' : source.substring(firstLineEnd + 1);
      expect(
        RegExp(r'^\s*part\s', multiLine: true).hasMatch(body),
        isFalse,
        reason: '${file.path} must not contain additional part directives.',
      );
      expect(
        loaderSource,
        contains("part 'delivery_loading/${_fileName(file.path)}';"),
        reason: '${file.path} must be registered by manifest_loader.dart.',
      );
    }
  });

  test('delivery result models have one private implementation owner', () {
    final modelSource = File(
      'lib/delivery_loading/models.dart',
    ).readAsStringSync();
    final otherSources = Directory('lib/delivery_loading')
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.endsWith('models.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(modelSource, contains('class LoadedMiniProgram'));
    expect(modelSource, contains('class LoadedMiniProgramScreen'));
    expect(modelSource, contains('class _ManifestLoadResult'));
    expect(modelSource, contains('class _ScreenLoadResult'));
    expect(otherSources, isNot(contains('class LoadedMiniProgram')));
    expect(otherSources, isNot(contains('class LoadedMiniProgramScreen')));
    expect(otherSources, isNot(contains('class _ManifestLoadResult')));
    expect(otherSources, isNot(contains('class _ScreenLoadResult')));

    final barrelSource = File('lib/mini_program_sdk.dart').readAsStringSync();
    expect(barrelSource, contains("export 'manifest_loader.dart';"));
  });
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;
