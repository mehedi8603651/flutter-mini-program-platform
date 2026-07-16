import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mp_state remains a thin public state library', () {
    final source = File('lib/state/mp_state.dart').readAsStringSync();
    expect(source.split('\n').length, lessThan(30));
    expect(
      RegExp(
        r'^(?:class|abstract class|enum|typedef|extension)\s',
        multiLine: true,
      ).hasMatch(source),
      isFalse,
    );
    expect(source, contains("part 'live_state/store.dart';"));
    expect(source, contains("part 'router/router.dart';"));
  });

  test(
    'state and router implementations remain private feature-owned parts',
    () {
      final directory = Directory('lib/state');
      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.endsWith('mp_state.dart'),
          )
          .toList(growable: false);
      final relativeNames = files
          .map((file) => _relativeToState(file.path))
          .toSet();

      expect(relativeNames, <String>{
        'live_state/batching.dart',
        'live_state/limits.dart',
        'live_state/manager.dart',
        'live_state/models.dart',
        'live_state/paths.dart',
        'live_state/policy.dart',
        'live_state/store.dart',
        'live_state/values.dart',
        'router/router.dart',
      });

      final rootSource = File('lib/state/mp_state.dart').readAsStringSync();
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          source.trimLeft(),
          startsWith("part of '../mp_state.dart';"),
          reason: '${file.path} must remain part of state/mp_state.dart.',
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
          rootSource,
          contains("part '${_relativeToState(file.path)}';"),
          reason: '${file.path} must be registered by state/mp_state.dart.',
        );
      }
    },
  );

  test('public state and router declarations have single owners', () {
    final ownership = <String, String>{
      'class MiniProgramLiveStatePolicy': 'live_state/policy.dart',
      'abstract interface class MiniProgramLiveStatePolicyProvider':
          'live_state/policy.dart',
      'class MiniProgramStateLimitException': 'live_state/policy.dart',
      'class MpStore': 'live_state/store.dart',
      'class MpStateManager': 'live_state/manager.dart',
      'typedef MpRouterScreenHandler': 'router/router.dart',
      'typedef MpRouterResultHandler': 'router/router.dart',
      'typedef MpRouterPopToScreenHandler': 'router/router.dart',
      'class MpRouter': 'router/router.dart',
      'String validateStateKey': 'live_state/paths.dart',
    };
    final files = Directory('lib/state')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => file.readAsStringSync().contains(entry.key))
          .map((file) => _relativeToState(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key);
    }

    final barrelSource = File('lib/mini_program_sdk.dart').readAsStringSync();
    expect(barrelSource, contains("export 'state/mp_state.dart';"));
  });
}

String _relativeToState(String path) {
  final normalized = path.replaceAll('\\', '/');
  const marker = 'lib/state/';
  final markerIndex = normalized.indexOf(marker);
  return markerIndex < 0
      ? normalized
      : normalized.substring(markerIndex + marker.length);
}
