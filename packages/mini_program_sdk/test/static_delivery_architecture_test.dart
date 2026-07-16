import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static delivery roots remain thin private part registries', () {
    for (final path in <String>[
      'lib/network/http_mini_program_source.dart',
      'lib/network/mini_program_endpoint.dart',
    ]) {
      final root = File(path).readAsStringSync();

      expect(root.split('\n').length, lessThan(35), reason: path);
      expect(
        RegExp(
          r'^(?:class|abstract class|abstract interface class|enum|typedef)\s',
          multiLine: true,
        ).hasMatch(root),
        isFalse,
        reason: path,
      );
    }
  });

  test(
    'static delivery implementations remain private feature-owned parts',
    () {
      const expectedNames = <String>{
        'endpoint/capabilities.dart',
        'endpoint/models.dart',
        'endpoint/policies.dart',
        'endpoint/routing_source.dart',
        'endpoint/source_factory.dart',
        'endpoint/validation.dart',
        'http/errors.dart',
        'http/loading.dart',
        'http/loopback.dart',
        'http/paths.dart',
        'http/publisher_backend.dart',
        'http/source.dart',
        'http/transport.dart',
      };
      final httpRoot = File(
        'lib/network/http_mini_program_source.dart',
      ).readAsStringSync();
      final endpointRoot = File(
        'lib/network/mini_program_endpoint.dart',
      ).readAsStringSync();
      final files = Directory('lib/network/static_delivery')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false);
      final names = files.map((file) => _runtimePath(file.path)).toSet();

      expect(names, expectedNames);
      for (final file in files) {
        final relativePath = _runtimePath(file.path);
        final source = file.readAsStringSync();
        final root = relativePath.startsWith('http/') ? httpRoot : endpointRoot;
        final rootName = relativePath.startsWith('http/')
            ? 'http_mini_program_source.dart'
            : 'mini_program_endpoint.dart';

        expect(
          source.trimLeft(),
          startsWith("part of '../../$rootName';"),
          reason: file.path,
        );
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
          contains("part 'static_delivery/$relativePath';"),
          reason: file.path,
        );
      }
    },
  );

  test('public static delivery declarations have one implementation owner', () {
    final ownership = <RegExp, String>{
      RegExp(
        r'^typedef ManifestRequestQueryParametersBuilder\b',
        multiLine: true,
      ): 'http/source.dart',
      RegExp(r'^class HttpMiniProgramSource\b', multiLine: true):
          'http/source.dart',
      RegExp(r'^typedef MiniProgramEndpointSourceFactory\b', multiLine: true):
          'endpoint/models.dart',
      RegExp(r'^class MiniProgramEndpoint\b', multiLine: true):
          'endpoint/models.dart',
      RegExp(r'^class EndpointRoutingMiniProgramSource\b', multiLine: true):
          'endpoint/routing_source.dart',
    };
    final files = Directory('lib/network/static_delivery')
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

  test('public source operations remain actual class members', () {
    final httpSource = File(
      'lib/network/static_delivery/http/source.dart',
    ).readAsStringSync();
    final routingSource = File(
      'lib/network/static_delivery/endpoint/routing_source.dart',
    ).readAsStringSync();

    for (final method in <String>[
      'dispose',
      'loadManifest',
      'loadScreen',
      'loadJsonAsset',
      'loadPublisherBackendContract',
    ]) {
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(httpSource),
        isTrue,
        reason: '$method must remain an HttpMiniProgramSource member.',
      );
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(routingSource),
        isTrue,
        reason:
            '$method must remain an EndpointRoutingMiniProgramSource member.',
      );
    }

    for (final method in <String>[
      'cachePolicyFor',
      'liveStatePolicyFor',
      'publisherApiPolicyFor',
      'locationPolicyFor',
    ]) {
      expect(
        RegExp('\\b$method\\s*\\(').hasMatch(routingSource),
        isTrue,
        reason:
            '$method must remain an EndpointRoutingMiniProgramSource member.',
      );
    }
  });

  test('static delivery internals are not separately exported', () {
    final barrel = File('lib/mini_program_sdk.dart').readAsStringSync();

    expect(barrel, contains("export 'network/http_mini_program_source.dart';"));
    expect(barrel, contains("export 'network/mini_program_endpoint.dart';"));
    expect(barrel, isNot(contains('network/static_delivery/')));
  });
}

String _runtimePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(
    normalized.indexOf('network/static_delivery/') + 24,
  );
}
