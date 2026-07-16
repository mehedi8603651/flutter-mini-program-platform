import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('pubspec stays pure Dart and lightweight', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final forbidden in <String>[
      'flutter:',
      'stac:',
      'stac_core:',
      'analyzer:',
      'build_runner:',
    ]) {
      expect(
        pubspec,
        isNot(contains(forbidden)),
        reason: 'mini_program_ui must not depend on $forbidden',
      );
    }
  });
}
