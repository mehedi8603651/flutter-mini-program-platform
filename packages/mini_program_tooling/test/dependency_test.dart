import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('tooling does not require host architecture packages', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final packageName in <String>[
      'get',
      'go_router',
      'provider',
      'bloc',
      'flutter_bloc',
      'riverpod',
      'flutter_riverpod',
      'hooks_riverpod',
    ]) {
      expect(pubspec, isNot(contains('\n  $packageName:')));
    }
  });
}
