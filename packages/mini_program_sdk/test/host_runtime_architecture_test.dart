import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MiniProgramHost remains a thin public widget library', () {
    final source = File('lib/mini_program_host.dart').readAsStringSync();
    expect(source.split('\n').length, lessThan(140));

    final classNames = RegExp(
      r'^class\s+([A-Za-z0-9_]+)',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)).toList();
    expect(classNames, <String>['MiniProgramHost']);
    expect(source, contains('typedef MiniProgramErrorBuilder'));
    expect(source, isNot(contains('class _MiniProgramHostState')));
  });

  test('host runtime remains private feature-owned parts', () {
    final directory = Directory('lib/host_runtime');
    expect(directory.existsSync(), isTrue);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _fileName(file.path)).toSet();

    expect(names, <String>{
      'cache_lifecycle.dart',
      'failures.dart',
      'host_state.dart',
      'loading.dart',
      'models.dart',
      'navigation.dart',
      'policies.dart',
      'publisher_backend.dart',
      'rendering.dart',
    });

    final hostSource = File('lib/mini_program_host.dart').readAsStringSync();
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source.trimLeft(),
        startsWith("part of '../mini_program_host.dart';"),
        reason: '${file.path} must remain part of mini_program_host.dart.',
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
        hostSource,
        contains("part 'host_runtime/${_fileName(file.path)}';"),
        reason: '${file.path} must be registered by mini_program_host.dart.',
      );
    }
  });

  test('host state and rendered screen models have single owners', () {
    final stateSource = File(
      'lib/host_runtime/host_state.dart',
    ).readAsStringSync();
    final modelSource = File('lib/host_runtime/models.dart').readAsStringSync();
    final otherSources = Directory('lib/host_runtime')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              !file.path.endsWith('host_state.dart') &&
              !file.path.endsWith('models.dart'),
        )
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(stateSource, contains('class _MiniProgramHostState'));
    expect(modelSource, contains('class _RenderedMiniProgramScreen'));
    expect(otherSources, isNot(contains('class _MiniProgramHostState')));
    expect(otherSources, isNot(contains('class _RenderedMiniProgramScreen')));
  });
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;
