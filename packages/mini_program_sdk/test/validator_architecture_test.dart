import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validator implementation remains internal to the renderer library', () {
    final validationDirectory = Directory(
      'lib/rendering/mp_runtime/validation',
    );
    expect(validationDirectory.existsSync(), isTrue);

    final validationFiles = validationDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    expect(validationFiles, isNotEmpty);

    for (final file in validationFiles) {
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

    expect(
      File('lib/rendering/mp_runtime/models_validator.dart').existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/rendering/mp_runtime/models_validator_helpers.dart',
      ).existsSync(),
      isFalse,
    );
  });
}
