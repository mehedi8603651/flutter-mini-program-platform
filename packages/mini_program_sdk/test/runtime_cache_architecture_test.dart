import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime_cache remains a thin public cache library', () {
    final source = File('lib/cache/runtime_cache.dart').readAsStringSync();
    expect(source.split('\n').length, lessThan(30));
    expect(
      RegExp(
        r'^(?:class|abstract class|enum|typedef|extension)\s',
        multiLine: true,
      ).hasMatch(source),
      isFalse,
    );
    expect(source, contains("part 'runtime/manager.dart';"));
    expect(source, contains("part 'runtime/app_cache.dart';"));
  });

  test('runtime cache implementations remain private feature-owned parts', () {
    final directory = Directory('lib/cache/runtime');
    expect(directory.existsSync(), isTrue);
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final names = files.map((file) => _fileName(file.path)).toSet();

    expect(names, <String>{
      'app_cache.dart',
      'enforcement.dart',
      'entries.dart',
      'lifecycle.dart',
      'manager.dart',
      'memory_store.dart',
      'operations.dart',
      'policy.dart',
      'store.dart',
      'tracking.dart',
      'types.dart',
      'usage.dart',
      'values.dart',
    });

    final rootSource = File('lib/cache/runtime_cache.dart').readAsStringSync();
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source.trimLeft(),
        startsWith("part of '../runtime_cache.dart';"),
        reason: '${file.path} must remain part of runtime_cache.dart.',
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
        contains("part 'runtime/${_fileName(file.path)}';"),
        reason: '${file.path} must be registered by runtime_cache.dart.',
      );
    }
  });

  test('cache manager keeps overrideable operations as class members', () {
    final source = File('lib/cache/runtime/manager.dart').readAsStringSync();
    const methodNames = <String>[
      'openApp',
      'closeApp',
      'set',
      'get',
      'has',
      'remove',
      'clear',
      'clearApp',
      'clearBucket',
      'clearExpired',
      'clearLowPriority',
      'clearAllThirdParty',
      'clearOnLogout',
      'clearInactiveSessions',
      'clearInactiveState',
      'getMetadata',
      'getTotalBytes',
      'usageForApp',
    ];

    expect(source, contains('class MiniProgramCacheManager'));
    for (final methodName in methodNames) {
      expect(
        RegExp('\\b$methodName(?:<[^>]+>)?\\s*\\(').hasMatch(source),
        isTrue,
        reason: '$methodName must remain a MiniProgramCacheManager member.',
      );
    }
  });

  test('public runtime cache declarations have single owners', () {
    final ownership = <RegExp, String>{
      RegExp(r'^typedef MiniProgramCacheClock\b', multiLine: true):
          'types.dart',
      RegExp(r'^enum MiniProgramCacheBucket\b', multiLine: true): 'types.dart',
      RegExp(r'^enum MiniProgramCacheStorage\b', multiLine: true): 'types.dart',
      RegExp(r'^enum MiniProgramCachePriority\b', multiLine: true):
          'types.dart',
      RegExp(
        r'^abstract interface class MiniProgramCachePolicyProvider\b',
        multiLine: true,
      ): 'policy.dart',
      RegExp(r'^class MiniProgramCachePolicy\b', multiLine: true):
          'policy.dart',
      RegExp(r'^class MiniProgramCacheBucketUsage\b', multiLine: true):
          'usage.dart',
      RegExp(r'^class MiniProgramCacheUsage\b', multiLine: true): 'usage.dart',
      RegExp(r'^class MiniProgramCacheEntry\b', multiLine: true):
          'entries.dart',
      RegExp(r'^class MiniProgramCacheMetadata\b', multiLine: true):
          'entries.dart',
      RegExp(
        r'^abstract interface class MiniProgramCacheStore\b',
        multiLine: true,
      ): 'store.dart',
      RegExp(
        r'^abstract interface class MiniProgramIndexedCacheStore\b',
        multiLine: true,
      ): 'store.dart',
      RegExp(r'^class MiniProgramMemoryCacheStore\b', multiLine: true):
          'memory_store.dart',
      RegExp(r'^class MiniProgramCacheManager\b', multiLine: true):
          'manager.dart',
      RegExp(r'^class MiniProgramAppCache\b', multiLine: true):
          'app_cache.dart',
    };
    final files = Directory('lib/cache/runtime')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _fileName(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }

    final barrelSource = File('lib/mini_program_sdk.dart').readAsStringSync();
    expect(barrelSource, contains("export 'cache/runtime_cache.dart';"));
  });
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;
