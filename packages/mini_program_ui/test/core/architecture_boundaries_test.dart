import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'the package remains pure Dart and features do not import the facade',
    () {
      final library = Directory('lib');
      final dartFiles = library
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains("package:flutter/")),
          reason: '${file.path} must remain pure Dart.',
        );
        final corePath =
            '${Platform.pathSeparator}core${Platform.pathSeparator}';
        final programPath =
            '${Platform.pathSeparator}program${Platform.pathSeparator}';
        final featuresPath =
            '${Platform.pathSeparator}features${Platform.pathSeparator}';
        if (file.path.contains(corePath)) {
          expect(source, isNot(contains('/features/')));
          expect(source, isNot(contains('/program/')));
        }
        if (file.path.contains(programPath)) {
          expect(source, isNot(contains('/features/')));
          expect(source, isNot(contains("import '../mp.dart'")));
        }
        if (file.path.contains(featuresPath)) {
          expect(
            source,
            isNot(matches(RegExp(r'''import\s+['"][^'"]*mp\.dart['"]'''))),
            reason: '${file.path} must not depend on the Mp facade.',
          );
        }
      }
    },
  );

  test('the Mp facade contains signatures and delegation only', () {
    final source = File('lib/src/mp.dart').readAsStringSync();

    expect(source, isNot(contains('MpNode(')));
    expect(source, isNot(contains('MpAction(')));
    expect(source, isNot(contains('throw ArgumentError')));
    expect(source, isNot(contains('props: <String, Object?>')));
  });

  test('the public barrel does not export internal builders or validators', () {
    final source = File('lib/mini_program_ui.dart').readAsStringSync();

    expect(source, isNot(contains('authoring_validation.dart')));
    expect(source, isNot(contains('binding_validation.dart')));
    expect(source, isNot(contains('value_normalization.dart')));
    expect(source, isNot(contains('node_builders.dart')));
    expect(source, isNot(contains('presentation_validation.dart')));
    expect(source, isNot(contains('_actions.dart')));
  });
}
