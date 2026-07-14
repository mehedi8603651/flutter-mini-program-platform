import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test(
    'disabled Publisher API policy fails without making a request',
    () async {
      final result = await const DisabledMiniProgramBackendConnector().call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorCode, MiniProgramErrorCodes.publisherApiDisabled);
    },
  );

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
        expect(
          requested[0].headers.containsKey('x-mini-program-access-key'),
          isFalse,
        );
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

    test('never sends artifact credential headers to backend', () async {
      final requestedHeaders = <String?>[];
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
          'trusted_coupon': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          requestedHeaders.add(
            request.headers['x-mini-program-'
                'access-key'],
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

      expect(requestedHeaders, <String?>[null, null]);
    });

    test(
      'sends request authorization headers without artifact credential leakage',
      () async {
        final requestedHeaders = <Map<String, String>>[];
        final connector = EndpointRoutingMiniProgramBackendConnector(
          backends: <String, MiniProgramBackendEndpoint>{
            'coupon': MiniProgramBackendEndpoint(
              baseUri: Uri.parse('https://publisher.example.com/api/'),
            ),
          },
          deliveryContext: _deliveryContext,
          clientFactory: () => _RecordingClient((request) async {
            requestedHeaders.add(request.headers);
            return http.Response('{"ok":true}', 200);
          }),
        );

        final result = await connector.call(
          const MiniProgramBackendRequest(
            miniProgramId: 'coupon',
            endpoint: 'profile',
            headers: <String, String>{'authorization': 'Bearer id-token'},
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(requestedHeaders.single['authorization'], 'Bearer id-token');
        expect(
          requestedHeaders.single.containsKey('x-mini-program-access-key'),
          isFalse,
        );
      },
    );

    test('partitions GET cache by authorization header', () async {
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
          final auth = request.headers['authorization'] ?? '';
          return http.Response('{"request":$requests,"auth":"$auth"}', 200);
        }),
      );

      const cachePolicy = MiniProgramBackendCachePolicy(
        ttl: Duration(minutes: 1),
      );
      final publicResult = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'profile',
          cachePolicy: cachePolicy,
        ),
      );
      final authResult = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'profile',
          headers: <String, String>{'authorization': 'Bearer id-token'},
          cachePolicy: cachePolicy,
        ),
      );
      final authResultCached = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'profile',
          headers: <String, String>{'authorization': 'Bearer id-token'},
          cachePolicy: cachePolicy,
        ),
      );

      expect(publicResult.data['request'], 1);
      expect(authResult.data['request'], 2);
      expect(authResultCached.data['request'], 2);
      expect(authResultCached.fromCache, isTrue);
      expect(requests, 2);
    });

    test('force refresh bypasses an otherwise valid GET cache entry', () async {
      var requests = 0;
      final connector = EndpointRoutingMiniProgramBackendConnector(
        backends: <String, MiniProgramBackendEndpoint>{
          'weather': MiniProgramBackendEndpoint(
            baseUri: Uri.parse('https://publisher.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _RecordingClient((request) async {
          requests++;
          return http.Response('{"request":$requests}', 200);
        }),
      );
      const cachePolicy = MiniProgramBackendCachePolicy(
        ttl: Duration(minutes: 10),
      );

      final first = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          cachePolicy: cachePolicy,
        ),
      );
      final cached = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          cachePolicy: cachePolicy,
        ),
      );
      final refreshed = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          cachePolicy: cachePolicy,
          forceRefresh: true,
        ),
      );

      expect(first.data['request'], 1);
      expect(cached.fromCache, isTrue);
      expect(refreshed.data['request'], 2);
      expect(refreshed.fromCache, isFalse);
      expect(requests, 2);
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
  capabilities: <CapabilityId>{CapabilityIds.analytics},
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
