import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SDK does not require host architecture packages', () {
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
