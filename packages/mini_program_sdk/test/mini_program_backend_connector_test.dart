import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('EndpointRoutingMiniProgramBackendConnector', () {
    test('does not create an HTTP client before the first backend call', () {
      var createdClients = 0;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () {
          createdClients++;
          return _RecordingClient(
            (request) async => http.Response('{"ok":true}', 200),
          );
        },
      );

      expect(createdClients, 0);
      connector.dispose();
      expect(createdClients, 0);
    });

    test(
      'routes backend calls by miniProgramId and sends safe headers',
      () async {
        final requested = <http.BaseRequest>[];
        final connector = EndpointRoutingMiniProgramBackendConnector(
          backends: <String, MiniProgramBackendEndpoint>{
            'coupon': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('https://coupon.example.com/api/'),
            ),
            'rewards': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('https://rewards.example.com/api/'),
            ),
          },
          deliveryContext: _deliveryContext,
          clientFactory: () => _RecordingClient((request) async {
            requested.add(request);
            return http.Response('{"ok":true}', 200);
          }),
        );

        final coupon = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'coupon',
            endpoint: 'home/bootstrap',
          ),
        );
        final rewards = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'rewards',
            endpoint: 'profile',
          ),
        );

        expect(coupon.isSuccess, isTrue);
        expect(rewards.isSuccess, isTrue);
        expect(
          requested[0].url.toString(),
          'https://coupon.example.com/api/home/bootstrap',
        );
        expect(
          requested[1].url.toString(),
          'https://rewards.example.com/api/profile',
        );
        expect(
          requested[0].headers[MiniProgramBackendHttpHeaders.appId],
          'coupon',
        );
        expect(
          requested[0].headers[MiniProgramBackendHttpHeaders.sdkVersion],
          '1.0.0',
        );
        expect(requested[0].headers[MiniProgramHttpHeaders.accessKey], isNull);
      },
    );

    test('returns a clear failure when backend endpoint is missing', () async {
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: const <String, MiniProgramBackendEndpoint>{},
        deliveryContext: _deliveryContext,
      );

      final result = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home/bootstrap',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorCode, 'publisher_backend_not_configured');
    });

    test('rejects absolute backend action endpoints', () async {
      var createdClients = 0;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () {
          createdClients++;
          return _RecordingClient(
            (request) async => http.Response('{"ok":true}', 200),
          );
        },
      );

      final result = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'https://evil.example.com/steal',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorCode, 'invalid_backend_endpoint');
      expect(createdClients, 0);
    });

    test('times out backend requests with a stable error', () async {
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
            requestTimeout: const Duration(milliseconds: 10),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{"ok":true}', 200);
        }),
      );

      final result = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home/bootstrap',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorCode, 'publisher_backend_timeout');
      expect(result.data['requestTimeoutMs'], 10);
    });

    test(
      'falls back from localhost backend URL to Android emulator host',
      () async {
        final requestedUrls = <String>[];
        final connector = EndpointRoutingMiniProgramBackendConnector(
          backends: <String, MiniProgramBackendEndpoint>{
            'coupon': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('http://127.0.0.1:9090/'),
            ),
          },
          deliveryContext: _deliveryContext,
          clientFactory: () => _RecordingClient((request) async {
            requestedUrls.add(request.url.toString());
            if (request.url.host == '127.0.0.1') {
              throw http.ClientException('Connection refused', request.url);
            }
            return http.Response('{"ok":true}', 200);
          }),
        );

        final result = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'coupon',
            endpoint: 'home/bootstrap',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(requestedUrls, <String>[
          'http://127.0.0.1:9090/home/bootstrap',
          'http://10.0.2.2:9090/home/bootstrap',
        ]);
      },
    );

    test(
      'does not fall back when local loopback fallback is disabled',
      () async {
        final requestedUrls = <String>[];
        final connector = EndpointRoutingMiniProgramBackendConnector(
          backends: <String, MiniProgramBackendEndpoint>{
            'coupon': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('http://127.0.0.1:9090/'),
              enableLocalLoopbackFallback: false,
            ),
          },
          deliveryContext: _deliveryContext,
          clientFactory: () => _RecordingClient((request) async {
            requestedUrls.add(request.url.toString());
            throw http.ClientException('Connection refused', request.url);
          }),
        );

        final result = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'coupon',
            endpoint: 'home/bootstrap',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.errorCode, 'publisher_backend_unreachable');
        expect(requestedUrls, <String>['http://127.0.0.1:9090/home/bootstrap']);
      },
    );

    test(
      'does not try fallback URL when configured local URL succeeds',
      () async {
        final requestedUrls = <String>[];
        final connector = EndpointRoutingMiniProgramBackendConnector(
          backends: <String, MiniProgramBackendEndpoint>{
            'coupon': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('http://127.0.0.1:9090/'),
            ),
          },
          deliveryContext: _deliveryContext,
          clientFactory: () => _RecordingClient((request) async {
            requestedUrls.add(request.url.toString());
            return http.Response('{"ok":true}', 200);
          }),
        );

        final result = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'coupon',
            endpoint: 'home/bootstrap',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(requestedUrls, <String>['http://127.0.0.1:9090/home/bootstrap']);
      },
    );

    test('caches GET calls only when cache TTL is explicit', () async {
      var requests = 0;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          requests++;
          return http.Response('{"request":$requests}', 200);
        }),
      );

      final first = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home/bootstrap',
          method: 'GET',
          cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 1)),
        ),
      );
      final second = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home/bootstrap',
          method: 'GET',
          cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 1)),
        ),
      );

      expect(first.data['request'], 1);
      expect(second.data['request'], 1);
      expect(second.fromCache, isTrue);
      expect(requests, 1);
    });

    test('does not cache POST calls', () async {
      var requests = 0;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          requests++;
          return http.Response('{"request":$requests}', 200);
        }),
      );

      await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'orders/create',
          method: 'POST',
          cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 1)),
        ),
      );
      await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'orders/create',
          method: 'POST',
          cachePolicy: MiniProgramBackendCachePolicy(ttl: Duration(minutes: 1)),
        ),
      );

      expect(requests, 2);
    });

    test('sends access key to backend only when explicitly enabled', () async {
      final requestedHeaders = <String?>[];
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
          'trusted_coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
            sendAccessKeyToBackend: true,
          ),
        },
        accessKeys: const <String, String>{
          'coupon': 'mpk_live_coupon',
          'trusted_coupon': 'mpk_live_trusted',
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          requestedHeaders.add(
            request.headers[MiniProgramHttpHeaders.accessKey],
          );
          return http.Response('{"ok":true}', 200);
        }),
      );

      await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home',
        ),
      );
      await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'trusted_coupon',
          endpoint: 'home',
        ),
      );

      expect(requestedHeaders, <String?>[null, 'mpk_live_trusted']);
    });

    test('disposes owned backend HTTP client', () async {
      late _RecordingClient client;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () {
          client = _RecordingClient(
            (request) async => http.Response('{"ok":true}', 200),
          );
          return client;
        },
      );

      await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home',
        ),
      );
      connector.dispose();

      expect(client.closeCount, 1);
    });
  });
}

const MiniProgramDeliveryContext _deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'host_app',
  sdkVersion: '1.0.0',
  hostVersion: '2.0.0',
  capabilities: <Capability>{Capability.analytics},
  platform: 'android',
  locale: 'en-US',
);

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }

  @override
  void close() {
    closeCount++;
    super.close();
  }
}
