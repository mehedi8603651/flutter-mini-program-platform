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

  test('SDK runtime does not depend on mini_program_ui', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependenciesBlock = pubspec
        .split('\ndev_dependencies:')
        .first
        .split('\ndependencies:')
        .last;

    expect(dependenciesBlock, isNot(contains('\n  mini_program_ui:')));
  });

  test('SDK runtime does not carry legacy Stac dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependenciesBlock = pubspec
        .split('\ndev_dependencies:')
        .first
        .split('\ndependencies:')
        .last;

    for (final packageName in <String>[
      'stac',
      'stac_core',
      'dio',
      'cached_network_image',
      'flutter_svg',
      'shared_preferences',
      'sqflite',
      'mini_program_legacy_stac',
    ]) {
      expect(dependenciesBlock, isNot(contains('\n  $packageName:')));
    }
  });
}
