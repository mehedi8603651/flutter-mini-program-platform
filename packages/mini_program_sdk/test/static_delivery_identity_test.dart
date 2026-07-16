import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('HTTP static delivery identity', () {
    test('keeps delivery query parameters on latest manifest only', () async {
      final requestedUris = <Uri>[];
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('https://cdn.example.com/store'),
        manifestRequestQueryParametersBuilder: (_) => const <String, String>{
          'hostApp': 'identity_host',
          'sdkVersion': '0.5.13',
        },
        client: MockClient((request) async {
          requestedUris.add(request.url);
          if (request.url.path.endsWith('/latest.json')) {
            return http.Response(_manifestJson, 200);
          }
          if (request.url.path.endsWith('/publisher_backend.json')) {
            return http.Response(_publisherBackendJson, 200);
          }
          if (request.url.path.endsWith('.json') &&
              request.url.path.contains('/screens/')) {
            return http.Response(_screenJson, 200);
          }
          return http.Response.bytes(<int>[91, 93], 200);
        }),
      );

      await source.loadManifest('weather');
      await source.loadScreen(
        miniProgramId: 'weather',
        version: '1.2.0',
        screenId: 'home',
      );
      await source.loadJsonAsset(
        miniProgramId: 'weather',
        version: '1.2.0',
        assetPath: 'data/locations.json',
      );
      await source.loadPublisherBackendContract(
        miniProgramId: 'weather',
        version: '1.2.0',
      );

      expect(requestedUris.map((uri) => uri.toString()).toList(), <String>[
        'https://cdn.example.com/store/artifacts/weather/latest.json'
            '?hostApp=identity_host&sdkVersion=0.5.13',
        'https://cdn.example.com/store/artifacts/weather/1.2.0'
            '/screens/home.json',
        'https://cdn.example.com/store/artifacts/weather/1.2.0'
            '/assets/data/locations.json',
        'https://cdn.example.com/store/artifacts/weather/1.2.0'
            '/publisher_backend.json',
      ]);
    });

    test('does not close an injected HTTP client', () async {
      final client = _TrackingClient();
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
        client: client,
      );

      await source.loadManifest('weather');
      source.dispose();

      expect(client.closeCount, 0);
    });

    test('rejects a Publisher API contract for another app', () async {
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
        client: MockClient(
          (request) async => http.Response(
            _publisherBackendJson.replaceFirst(
              '"appId":"weather"',
              '"appId":"calculator"',
            ),
            200,
          ),
        ),
      );

      await expectLater(
        () => source.loadPublisherBackendContract(
          miniProgramId: 'weather',
          version: '1.2.0',
        ),
        throwsA(
          isA<MiniProgramSourceException>()
              .having(
                (error) => error.errorCode,
                'errorCode',
                MiniProgramPublisherBackendErrorCodes.invalidContract,
              )
              .having((error) => error.details, 'details', <String, dynamic>{
                'miniProgramId': 'weather',
                'version': '1.2.0',
              }),
        ),
      );
    });
  });

  group('endpoint routing identity', () {
    test('normalizes app IDs and reuses one lazy source', () async {
      var sourceCreations = 0;
      late _BasicSource createdSource;
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          ' weather ': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) {
              sourceCreations++;
              createdSource = _BasicSource(appId);
              return createdSource;
            },
      );

      await source.loadManifest(' weather ');
      await source.loadScreen(
        miniProgramId: 'weather',
        version: '1.2.0',
        screenId: 'home',
      );

      expect(sourceCreations, 1);
      expect(createdSource.manifestCalls, <String>[' weather ']);
      expect(createdSource.screenCalls, 1);
      expect(source.cachePolicyFor(' weather '), isNotNull);
    });

    test('rejects duplicate endpoint IDs after normalization', () {
      expect(
        () => EndpointRoutingMiniProgramSource(
          endpoints: <String, MiniProgramEndpoint>{
            'weather': MiniProgramEndpoint.public(
              apiBaseUri: Uri.parse('https://cdn.example.com/one/'),
            ),
            ' weather ': MiniProgramEndpoint.public(
              apiBaseUri: Uri.parse('https://cdn.example.com/two/'),
            ),
          },
          deliveryContext: _deliveryContext,
        ),
        throwsArgumentError,
      );
    });

    test('keeps optional source capabilities optional', () async {
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'weather': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) =>
                _BasicSource(appId),
      );

      await expectLater(
        () => source.loadJsonAsset(
          miniProgramId: 'weather',
          version: '1.2.0',
          assetPath: 'data/locations.json',
        ),
        throwsA(
          isA<MiniProgramSourceException>().having(
            (error) => error.errorCode,
            'errorCode',
            MiniProgramErrorCodes.dataAssetUnavailable,
          ),
        ),
      );
      expect(
        await source.loadPublisherBackendContract(
          miniProgramId: 'weather',
          version: '1.2.0',
        ),
        isNull,
      );
    });

    test('disposal clears lazy source identity for later recreation', () async {
      final createdSources = <_BasicSource>[];
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'weather': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) {
              final created = _BasicSource(appId);
              createdSources.add(created);
              return created;
            },
      );

      await source.loadManifest('weather');
      await source.loadManifest('weather');
      source.dispose();
      await source.loadManifest('weather');
      source.dispose();

      expect(createdSources, hasLength(2));
      expect(createdSources[0].disposeCount, 1);
      expect(createdSources[1].disposeCount, 1);
    });
  });
}

const MiniProgramDeliveryContext _deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'identity_host',
  sdkVersion: '0.5.13',
  hostVersion: '1.0.0',
  capabilities: <CapabilityId>{},
);

const String _manifestJson =
    '{"id":"weather","version":"1.2.0","entry":"home",'
    '"contractVersion":"1.0.0","sdkVersionRange":">=0.5.13 <1.0.0",'
    '"requiredCapabilities":[]}';
const String _screenJson = '{"type":"text","data":"Weather"}';
const String _publisherBackendJson =
    '{"schemaVersion":1,'
    '"type":"mini_program_publisher_backend_contract",'
    '"contractVersion":"1","appId":"weather",'
    '"backendBaseUrl":"https://api.publisher.example/weather/"}';

class _TrackingClient extends http.BaseClient {
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(_manifestJson)),
      200,
      request: request,
    );
  }

  @override
  void close() {
    closeCount++;
  }
}

class _BasicSource implements DisposableMiniProgramSource {
  _BasicSource(this.appId);

  final String appId;
  final List<String> manifestCalls = <String>[];
  int screenCalls = 0;
  int disposeCount = 0;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    manifestCalls.add(miniProgramId);
    return MiniProgramManifest(
      id: appId,
      version: '1.2.0',
      entry: 'home',
      contractVersion: '1.0.0',
      sdkVersionRange: const SdkVersionRange(value: '>=0.5.13 <1.0.0'),
      requiredCapabilities: const <CapabilityId>[],
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    screenCalls++;
    return const <String, dynamic>{'type': 'text', 'data': 'Weather'};
  }

  @override
  void dispose() {
    disposeCount++;
  }
}
