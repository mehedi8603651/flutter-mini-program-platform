import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth root remains a thin private part registry', () {
    final root = File('lib/auth/mini_program_auth.dart').readAsStringSync();

    expect(root.split('\n').length, lessThan(30));
    expect(
      RegExp(
        r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
        multiLine: true,
      ).hasMatch(root),
      isFalse,
    );
  });

  test('auth implementations remain private feature-owned parts', () {
    const expectedNames = <String>{
      'controller/authorization.dart',
      'controller/controller.dart',
      'controller/email_auth.dart',
      'controller/refresh.dart',
      'controller/restoration.dart',
      'controller/session_updates.dart',
      'headers_paths.dart',
      'memory_store.dart',
      'result.dart',
      'secure_store.dart',
      'session.dart',
      'snapshot.dart',
      'store.dart',
      'user.dart',
    };
    final root = File('lib/auth/mini_program_auth.dart').readAsStringSync();
    final files = Directory('lib/auth/runtime')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _runtimePath(file.path)).toSet();

    expect(names, expectedNames);
    for (final file in files) {
      final relativePath = _runtimePath(file.path);
      final source = file.readAsStringSync();
      final expectedPartOf = relativePath.startsWith('controller/')
          ? "part of '../../mini_program_auth.dart';"
          : "part of '../mini_program_auth.dart';";
      expect(source.trimLeft(), startsWith(expectedPartOf), reason: file.path);
      expect(
        RegExp(
          r'^\s*(?:import|export|library)\s',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        root,
        contains("part 'runtime/$relativePath';"),
        reason: file.path,
      );
    }
  });

  test('public auth declarations have one implementation owner', () {
    final ownership = <RegExp, String>{
      RegExp(r'^typedef MiniProgramAuthClock\b', multiLine: true):
          'headers_paths.dart',
      RegExp(
        r'^abstract final class MiniProgramAuthHttpHeaders\b',
        multiLine: true,
      ): 'headers_paths.dart',
      RegExp(r'^class MiniProgramAuthBackendPaths\b', multiLine: true):
          'headers_paths.dart',
      RegExp(r'^class MiniProgramAuthUser\b', multiLine: true): 'user.dart',
      RegExp(r'^class MiniProgramAuthSession\b', multiLine: true):
          'session.dart',
      RegExp(r'^enum MiniProgramAuthStatus\b', multiLine: true):
          'snapshot.dart',
      RegExp(r'^class MiniProgramAuthSnapshot\b', multiLine: true):
          'snapshot.dart',
      RegExp(r'^class MiniProgramAuthResult\b', multiLine: true): 'result.dart',
      RegExp(
        r'^abstract interface class MiniProgramAuthStore\b',
        multiLine: true,
      ): 'store.dart',
      RegExp(r'^class InMemoryMiniProgramAuthStore\b', multiLine: true):
          'memory_store.dart',
      RegExp(r'^class SecureMiniProgramAuthStore\b', multiLine: true):
          'secure_store.dart',
      RegExp(r'^class MiniProgramAuthController\b', multiLine: true):
          'controller/controller.dart',
    };
    final files = Directory('lib/auth/runtime')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _runtimePath(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('auth controller public operations remain actual class members', () {
    final controller = File(
      'lib/auth/runtime/controller/controller.dart',
    ).readAsStringSync();

    for (final method in <String>[
      'snapshot',
      'session',
      'restore',
      'signInEmail',
      'signUpEmail',
      'refresh',
      'signOut',
      'authorizeRequest',
    ]) {
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(controller),
        isTrue,
        reason: '$method must remain a MiniProgramAuthController member.',
      );
    }
  });

  test('auth internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(barrel, contains("export 'auth/mini_program_auth.dart';"));
    expect(barrel, isNot(contains('auth/runtime/')));
  });
}

String _runtimePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('auth/runtime/') + 13);
}
