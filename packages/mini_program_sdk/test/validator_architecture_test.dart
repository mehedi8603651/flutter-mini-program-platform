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

  test('shared validation foundations remain feature-owned private parts', () {
    const expectedNames = <String>{
      'collections_forms.dart',
      'failures.dart',
      'media.dart',
      'numbers.dart',
      'presentation.dart',
      'state_cache.dart',
      'strings.dart',
      'structure.dart',
      'theme.dart',
    };
    final root = File(
      'lib/rendering/mp_screen_renderer.dart',
    ).readAsStringSync();
    final directory = Directory('lib/rendering/mp_runtime/validation/shared');
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _fileName(file.path)).toSet();

    expect(names, expectedNames);
    expect(
      File(
        'lib/rendering/mp_runtime/validation/shared_validation.dart',
      ).existsSync(),
      isFalse,
    );

    final owners = <String, String>{};
    for (final file in files) {
      final name = _fileName(file.path);
      final source = file.readAsStringSync();
      expect(
        root,
        contains("part 'mp_runtime/validation/shared/$name';"),
        reason: file.path,
      );

      final declarations = RegExp(
        r'^(?:[A-Za-z_<][A-Za-z0-9_<>,? ]*|void|Never) (_[A-Za-z0-9_]+)\(',
        multiLine: true,
      ).allMatches(source);
      for (final declaration in declarations) {
        final helper = declaration.group(1)!;
        expect(
          owners.containsKey(helper),
          isFalse,
          reason:
              '$helper is declared by both ${owners[helper]} and ${file.path}.',
        );
        owners[helper] = file.path;
      }
    }

    expect(owners, hasLength(87));
    expect(_ownerName(owners, '_validateObjectKeys'), 'structure.dart');
    expect(_ownerName(owners, '_requiredString'), 'strings.dart');
    expect(_ownerName(owners, '_boundedNumber'), 'numbers.dart');
    expect(_ownerName(owners, '_requiredHexColor'), 'presentation.dart');
    expect(_ownerName(owners, '_parseThemeTypography'), 'theme.dart');
    expect(_ownerName(owners, '_validateBase64Image'), 'media.dart');
    expect(_ownerName(owners, '_parseOptions'), 'collections_forms.dart');
    expect(_ownerName(owners, '_validateCacheValue'), 'state_cache.dart');
    expect(_ownerName(owners, '_fail'), 'failures.dart');
  });
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

String? _ownerName(Map<String, String> owners, String helper) {
  final path = owners[helper];
  return path == null ? null : _fileName(path);
}
