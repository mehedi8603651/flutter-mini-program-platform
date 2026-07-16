import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Publisher API roots remain thin private part registries', () {
    final connector = File(
      'lib/network/mini_program_backend_connector.dart',
    ).readAsStringSync();
    final store = File(
      'lib/network/mini_program_backend_store.dart',
    ).readAsStringSync();

    expect(connector.split('\n').length, lessThan(30));
    expect(store.split('\n').length, lessThan(20));
    for (final source in <String>[connector, store]) {
      expect(
        RegExp(
          r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
      );
    }
  });

  test('connector implementations remain private feature-owned parts', () {
    _expectPrivateParts(
      rootPath: 'lib/network/mini_program_backend_connector.dart',
      directoryPath: 'lib/network/publisher_api/connector',
      partPrefix: 'publisher_api/connector',
      partOf: "part of '../../mini_program_backend_connector.dart';",
      expectedNames: const <String>{
        'disabled.dart',
        'endpoint_routing.dart',
        'endpoint_validation.dart',
        'headers.dart',
        'interfaces.dart',
        'memory_cache.dart',
        'models.dart',
        'policy.dart',
        'request_transport.dart',
        'response_decoder.dart',
      },
    );
  });

  test('reactive store implementations remain private feature-owned parts', () {
    _expectPrivateParts(
      rootPath: 'lib/network/mini_program_backend_store.dart',
      directoryPath: 'lib/network/publisher_api/store',
      partPrefix: 'publisher_api/store',
      partOf: "part of '../../mini_program_backend_store.dart';",
      expectedNames: const <String>{
        'binding_data.dart',
        'execution.dart',
        'in_flight.dart',
        'pagination.dart',
        'queries.dart',
        'snapshots.dart',
        'store.dart',
      },
    );
  });

  test('public Publisher API declarations have one implementation owner', () {
    final ownership = <RegExp, String>{
      RegExp(
        r'^typedef MiniProgramBackendHttpClientFactory\b',
        multiLine: true,
      ): 'connector/models.dart',
      RegExp(r'^class MiniProgramPublisherApiPolicy\b', multiLine: true):
          'connector/policy.dart',
      RegExp(
        r'^abstract interface class MiniProgramPublisherApiPolicyProvider\b',
        multiLine: true,
      ): 'connector/policy.dart',
      RegExp(
        r'^abstract final class MiniProgramBackendHttpHeaders\b',
        multiLine: true,
      ): 'connector/headers.dart',
      RegExp(r'^class MiniProgramBackendEndpoint\b', multiLine: true):
          'connector/models.dart',
      RegExp(r'^class MiniProgramBackendCachePolicy\b', multiLine: true):
          'connector/models.dart',
      RegExp(r'^class MiniProgramBackendRequest\b', multiLine: true):
          'connector/models.dart',
      RegExp(r'^enum MiniProgramBackendResultStatus\b', multiLine: true):
          'connector/models.dart',
      RegExp(r'^class MiniProgramBackendResult\b', multiLine: true):
          'connector/models.dart',
      RegExp(
        r'^abstract interface class MiniProgramBackendConnector\b',
        multiLine: true,
      ): 'connector/interfaces.dart',
      RegExp(
        r'^abstract interface class DisposableMiniProgramBackendConnector\b',
        multiLine: true,
      ): 'connector/interfaces.dart',
      RegExp(r'^class DisabledMiniProgramBackendConnector\b', multiLine: true):
          'connector/disabled.dart',
      RegExp(
        r'^class EndpointRoutingMiniProgramBackendConnector\b',
        multiLine: true,
      ): 'connector/endpoint_routing.dart',
      RegExp(
        r'^typedef MiniProgramBackendRequestInterceptor\b',
        multiLine: true,
      ): 'store/queries.dart',
      RegExp(r'^enum MiniProgramBackendSnapshotStatus\b', multiLine: true):
          'store/queries.dart',
      RegExp(r'^class MiniProgramBackendQuery\b', multiLine: true):
          'store/queries.dart',
      RegExp(r'^class MiniProgramPagedBackendQuery\b', multiLine: true):
          'store/queries.dart',
      RegExp(r'^class MiniProgramBackendSnapshot\b', multiLine: true):
          'store/snapshots.dart',
      RegExp(r'^class MiniProgramPagedBackendSnapshot\b', multiLine: true):
          'store/pagination.dart',
      RegExp(r'^class MiniProgramBackendStore\b', multiLine: true):
          'store/store.dart',
    };
    final files = Directory('lib/network/publisher_api')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    for (final entry in ownership.entries) {
      final owners = files
          .where((file) => entry.key.hasMatch(file.readAsStringSync()))
          .map((file) => _publisherApiPath(file.path))
          .toList(growable: false);
      expect(owners, <String>[entry.value], reason: entry.key.pattern);
    }
  });

  test('connector and store public operations remain class members', () {
    final connector = File(
      'lib/network/publisher_api/connector/endpoint_routing.dart',
    ).readAsStringSync();
    final store = File(
      'lib/network/publisher_api/store/store.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'Future<MiniProgramBackendResult>\s+call\s*\(',
      ).hasMatch(connector),
      isTrue,
    );
    expect(RegExp(r'void\s+dispose\s*\(').hasMatch(connector), isTrue);

    for (final method in <String>[
      'snapshot',
      'hasTerminalSnapshot',
      'pagedSnapshot',
      'runQuery',
      'runPagedQuery',
      'loadMore',
      'loadMoreByRequestId',
      'clear',
      'toBindingData',
      'dispose',
    ]) {
      expect(
        RegExp('\\b$method(?:<[^>]+>)?\\s*\\(').hasMatch(store),
        isTrue,
        reason: '$method must remain a MiniProgramBackendStore member.',
      );
    }
  });

  test('Publisher API internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(
      barrel,
      contains("export 'network/mini_program_backend_connector.dart';"),
    );
    expect(
      barrel,
      contains("export 'network/mini_program_backend_store.dart';"),
    );
    expect(barrel, isNot(contains('network/publisher_api/')));
  });
}

void _expectPrivateParts({
  required String rootPath,
  required String directoryPath,
  required String partPrefix,
  required String partOf,
  required Set<String> expectedNames,
}) {
  final root = File(rootPath).readAsStringSync();
  final files = Directory(directoryPath)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);
  final names = files.map((file) => _fileName(file.path)).toSet();
  expect(names, expectedNames);

  for (final file in files) {
    final source = file.readAsStringSync();
    expect(source.trimLeft(), startsWith(partOf), reason: file.path);
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
      contains("part '$partPrefix/${_fileName(file.path)}';"),
      reason: file.path,
    );
  }
}

String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

String _publisherApiPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('publisher_api/') + 14);
}
