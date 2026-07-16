import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('action execution remains split behind the central dispatcher', () {
    final dispatcherFile = File(
      'lib/rendering/mp_runtime/action_dispatcher.dart',
    );
    final dispatcherSource = dispatcherFile.readAsStringSync();
    expect(dispatcherSource.split('\n').length, lessThan(350));
    expect(dispatcherSource, contains('class MpActionRunner'));
    expect(
      dispatcherSource,
      contains('abstract final class _MpActionDispatcher'),
    );
    expect(dispatcherSource, contains('static Future<Object?> dispatch('));
    expect(
      RegExp(
        r'^\s+static\s+[^\n]+\s_[A-Za-z0-9_]+\(',
        multiLine: true,
      ).hasMatch(dispatcherSource),
      isFalse,
      reason: 'Feature action methods must live in mp_runtime/actions/.',
    );

    final actionDirectory = Directory('lib/rendering/mp_runtime/actions');
    expect(actionDirectory.existsSync(), isTrue);
    final actionFiles = actionDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    expect(actionFiles.map((file) => _fileName(file.path)).toSet(), <String>{
      'auth_backend.dart',
      'backend_search.dart',
      'cache.dart',
      'composition.dart',
      'data.dart',
      'feedback_forms_lazy.dart',
      'location.dart',
      'math.dart',
      'navigation.dart',
      'shared.dart',
      'state.dart',
    });

    for (final file in actionFiles) {
      final source = file.readAsStringSync();
      expect(
        source.trimLeft(),
        startsWith('part of '),
        reason: '${file.path} must remain part of the renderer library.',
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
        reason: '${file.path} must not include additional part directives.',
      );
    }
  });
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;
