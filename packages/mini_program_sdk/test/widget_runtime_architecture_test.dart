import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget runtime remains feature-owned inside the renderer library', () {
    final widgetsDirectory = Directory('lib/rendering/mp_runtime/widgets');
    expect(widgetsDirectory.existsSync(), isTrue);

    final files = widgetsDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final relativePaths = files
        .map((file) => _relativePath(widgetsDirectory, file))
        .toSet();

    expect(relativePaths, <String>{
      'backend/auth_builder.dart',
      'backend/helpers.dart',
      'backend/pagination.dart',
      'backend/query_builder.dart',
      'charts/line_chart.dart',
      'collections.dart',
      'content.dart',
      'controls.dart',
      'feedback.dart',
      'forms/backend_search_input.dart',
      'forms/form_container.dart',
      'forms/models.dart',
      'forms/selection_controls.dart',
      'forms/shared.dart',
      'forms/state_builder.dart',
      'forms/state_search_field.dart',
      'forms/state_text_field.dart',
      'forms/submit.dart',
      'forms/text_input.dart',
      'layout.dart',
      'lazy/chunk.dart',
      'lazy/helpers.dart',
      'lazy/models.dart',
      'lazy/section.dart',
      'lifecycle/condition_scopes.dart',
      'lifecycle/countdown.dart',
      'lifecycle/identity.dart',
      'lifecycle/initialize.dart',
      'lifecycle/refresh_viewport.dart',
      'lifecycle/state_scope.dart',
      'media.dart',
      'shared.dart',
      'theme.dart',
    });

    final rendererSource = File(
      'lib/rendering/mp_screen_renderer.dart',
    ).readAsStringSync();
    for (final file in files) {
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
        reason: '${file.path} must not contain additional part directives.',
      );

      final relativePath = _relativePath(widgetsDirectory, file);
      expect(
        rendererSource,
        contains("part 'mp_runtime/widgets/$relativePath';"),
        reason: '$relativePath must be registered by mp_screen_renderer.dart.',
      );
    }
  });

  test('central widget file owns only screen and node dispatch', () {
    final source = File(
      'lib/rendering/mp_runtime/widgets.dart',
    ).readAsStringSync();
    expect(source.split('\n').length, lessThan(220));

    final declarations = RegExp(
      r'^(?:class|enum)\s+([A-Za-z0-9_]+)',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)).toList();
    expect(declarations, <String>[
      '_MpScreenView',
      '_MpParentKind',
      '_MpNodeView',
    ]);
    expect(source, contains('return switch (node.type)'));
    expect(source, contains('Unsupported Mp node type'));
  });

  test('old monolithic widget runtime files no longer exist', () {
    for (final path in <String>[
      'lib/rendering/mp_runtime/forms.dart',
      'lib/rendering/mp_runtime/widgets_primitives.dart',
      'lib/rendering/mp_runtime/widgets_forms.dart',
      'lib/rendering/mp_runtime/widgets_backend.dart',
      'lib/rendering/mp_runtime/widgets_charts.dart',
      'lib/rendering/mp_runtime/widgets_lazy.dart',
      'lib/rendering/mp_runtime/widgets_lifecycle.dart',
    ]) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path must stay removed.',
      );
    }
  });

  test('private widget declarations are defined once', () {
    final sources = <File>[
      File('lib/rendering/mp_runtime/widgets.dart'),
      ...Directory('lib/rendering/mp_runtime/widgets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    ];
    final owners = <String, List<String>>{};
    final declarationPattern = RegExp(
      r'^(?:abstract\s+final\s+class|abstract\s+class|class|enum|typedef)\s+'
      r'(_[A-Za-z0-9_]+)',
      multiLine: true,
    );

    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final match in declarationPattern.allMatches(source)) {
        owners.putIfAbsent(match.group(1)!, () => <String>[]).add(file.path);
      }
    }

    final duplicates = <String, List<String>>{
      for (final entry in owners.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(duplicates, isEmpty);
  });
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path;
  return file.absolute.path
      .substring(rootPath.length + 1)
      .replaceAll('\\', '/');
}
