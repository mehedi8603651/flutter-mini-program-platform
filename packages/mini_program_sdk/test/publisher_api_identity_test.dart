import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('connector preserves header precedence and request encoding', () async {
    final requests = <http.BaseRequest>[];
    final connector = EndpointRoutingMiniProgramBackendConnector(
      backends: <String, MiniProgramBackendEndpoint>{
        'weather': MiniProgramBackendEndpoint(
          baseUri: Uri.parse('https://publisher.example.com/api/'),
          headers: const <String, String>{
            'x-precedence': 'endpoint',
            MiniProgramBackendHttpHeaders.appId: 'endpoint-app',
          },
        ),
      },
      deliveryContext: _deliveryContext,
      clientFactory: () => _RecordingClient((request) async {
        requests.add(request);
        return http.Response('{"ok":true}', 200);
      }),
    );

    await connector.call(
      const MiniProgramBackendRequest(
        miniProgramId: 'weather',
        endpoint: 'forecast',
        method: 'post',
        body: <String, dynamic>{'latitude': 23.8},
        headers: <String, String>{
          'x-precedence': 'request',
          MiniProgramBackendHttpHeaders.appId: 'request-app',
          'authorization': 'Bearer token',
        },
      ),
    );

    final request = requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.body, '{"latitude":23.8}');
    expect(request.headers['accept'], 'application/json');
    expect(request.headers['content-type'], 'application/json');
    expect(request.headers['x-precedence'], 'request');
    expect(request.headers[MiniProgramBackendHttpHeaders.appId], 'request-app');
    expect(request.headers[MiniProgramBackendHttpHeaders.hostApp], 'host_app');
    expect(request.headers[MiniProgramBackendHttpHeaders.hostVersion], '2.0.0');
    expect(request.headers[MiniProgramBackendHttpHeaders.sdkVersion], '1.0.0');
    expect(request.headers[MiniProgramBackendHttpHeaders.platform], 'android');
    expect(request.headers[MiniProgramBackendHttpHeaders.locale], 'en-US');
    expect(request.headers['authorization'], 'Bearer token');
  });

  test(
    'connector preserves response normalization and result JSON order',
    () async {
      final responses = Queue<http.Response>.of(<http.Response>[
        http.Response('[1,2]', 200),
        http.Response('"sunny"', 200),
        http.Response('not-json', 200),
        http.Response('', 204),
        http.Response('{"message":"Denied","errorCode":"denied"}', 403),
      ]);
      final connector = _connector(
        () => _RecordingClient((_) async => responses.removeFirst()),
      );

      final list = await connector.call(_request('list'));
      final scalar = await connector.call(_request('scalar'));
      final raw = await connector.call(_request('raw'));
      final empty = await connector.call(_request('empty'));
      final failed = await connector.call(_request('failed'));

      expect(list.data, <String, dynamic>{
        'items': <dynamic>[1, 2],
      });
      expect(scalar.data, <String, dynamic>{'value': 'sunny'});
      expect(raw.data, <String, dynamic>{'rawBody': 'not-json'});
      expect(empty.data, isEmpty);
      expect(failed.isFailure, isTrue);
      expect(failed.statusCode, 403);
      expect(failed.message, 'Denied');
      expect(failed.errorCode, 'denied');
      expect(failed.toJson().keys, <String>[
        'status',
        'endpoint',
        'method',
        'statusCode',
        'message',
        'errorCode',
        'data',
        'fromCache',
      ]);
    },
  );

  test('connector rejects traversal and stays failed after disposal', () async {
    var requests = 0;
    final connector = _connector(
      () => _RecordingClient((_) async {
        requests++;
        return http.Response('{"ok":true}', 200);
      }),
    );

    final traversal = await connector.call(_request('../private'));
    connector.dispose();
    final disposed = await connector.call(_request('forecast'));

    expect(traversal.errorCode, 'invalid_backend_endpoint');
    expect(disposed.errorCode, 'publisher_backend_disposed');
    expect(requests, 0);
  });

  test(
    'GET cache treats authorization header names case-insensitively',
    () async {
      var requests = 0;
      final connector = _connector(
        () => _RecordingClient((request) async {
          requests++;
          return http.Response('{"request":$requests}', 200);
        }),
      );
      const cachePolicy = MiniProgramBackendCachePolicy(
        ttl: Duration(minutes: 1),
      );

      final first = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          headers: <String, String>{'Authorization': 'Bearer one'},
          cachePolicy: cachePolicy,
        ),
      );
      final cached = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          headers: <String, String>{'Authorization': 'Bearer one'},
          cachePolicy: cachePolicy,
        ),
      );
      final otherUser = await connector.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          headers: <String, String>{'Authorization': 'Bearer two'},
          cachePolicy: cachePolicy,
        ),
      );

      expect(first.data['request'], 1);
      expect(cached.fromCache, isTrue);
      expect(otherUser.data['request'], 2);
      expect(requests, 2);
    },
  );

  test(
    'store deduplicates one request and notifies loading then success',
    () async {
      final completer = Completer<MiniProgramBackendResult>();
      final connector = _DeferredConnector(completer);
      final store = MiniProgramBackendStore();
      final statuses = <MiniProgramBackendSnapshotStatus>[];
      store.addListener(() {
        statuses.add(store.snapshot('forecast').status);
      });
      const query = MiniProgramBackendQuery(
        requestId: 'forecast',
        endpoint: 'forecast',
      );

      final first = store.runQuery(
        connector: connector,
        miniProgramId: 'weather',
        query: query,
      );
      final second = store.runQuery(
        connector: connector,
        miniProgramId: 'weather',
        query: query,
      );

      expect(identical(first, second), isTrue);
      expect(connector.calls, hasLength(1));
      completer.complete(
        MiniProgramBackendResult.success(
          endpoint: 'forecast',
          method: 'GET',
          data: const <String, dynamic>{'temperature': 31},
        ),
      );
      await first;

      expect(statuses, <MiniProgramBackendSnapshotStatus>[
        MiniProgramBackendSnapshotStatus.loading,
        MiniProgramBackendSnapshotStatus.success,
      ]);
    },
  );

  test(
    'failed refresh preserves previous data and binding JSON shape',
    () async {
      final store = MiniProgramBackendStore();
      final connector = _QueueConnector(<MiniProgramBackendResult>[
        MiniProgramBackendResult.success(
          endpoint: 'forecast',
          method: 'GET',
          statusCode: 200,
          data: const <String, dynamic>{'temperature': 31},
        ),
        MiniProgramBackendResult.failed(
          endpoint: 'forecast',
          method: 'GET',
          statusCode: 503,
          message: 'Offline',
          errorCode: 'offline',
        ),
      ]);

      await store.runQuery(
        connector: connector,
        miniProgramId: 'weather',
        query: const MiniProgramBackendQuery(
          requestId: 'forecast',
          endpoint: 'forecast',
        ),
      );
      final failed = await store.runQuery(
        connector: connector,
        miniProgramId: 'weather',
        query: const MiniProgramBackendQuery(
          requestId: 'forecast',
          endpoint: 'forecast',
          forceRefresh: true,
        ),
      );

      expect(failed.isFailure, isTrue);
      expect(failed.data, <String, dynamic>{'temperature': 31});
      final binding = store.toBindingData()['forecast'] as Map<String, dynamic>;
      expect(binding.keys, <String>[
        'requestId',
        'status',
        'idle',
        'loading',
        'success',
        'failed',
        'error',
        'endpoint',
        'method',
        'statusCode',
        'message',
        'errorCode',
        'data',
        'hasData',
        'fromCache',
        'updatedAtUtc',
      ]);
      expect(binding['status'], 'failed');
      expect(binding['data'], <String, dynamic>{'temperature': 31});
    },
  );

  test('store disposal suppresses late results and notifications', () async {
    final completer = Completer<MiniProgramBackendResult>();
    final store = MiniProgramBackendStore();
    var notifications = 0;
    store.addListener(() {
      notifications++;
    });

    final future = store.runQuery(
      connector: _DeferredConnector(completer),
      miniProgramId: 'weather',
      query: const MiniProgramBackendQuery(
        requestId: 'forecast',
        endpoint: 'forecast',
      ),
    );
    expect(notifications, 1);
    store.dispose();
    completer.complete(
      MiniProgramBackendResult.success(
        data: const <String, dynamic>{'temperature': 31},
      ),
    );

    final result = await future;
    expect(result.isIdle, isTrue);
    expect(notifications, 1);
  });

  test('Publisher API types remain available from the SDK barrel', () {
    expect(const MiniProgramPublisherApiPolicy(), isNotNull);
    expect(MiniProgramBackendHttpHeaders.appId, 'x-mini-program-app-id');
    expect(MiniProgramBackendResultStatus.values, hasLength(2));
    expect(MiniProgramBackendSnapshotStatus.values, hasLength(4));
    expect(const DisabledMiniProgramBackendConnector(), isNotNull);
    expect(MiniProgramBackendStore(), isA<MiniProgramBackendStore>());
  });
}

EndpointRoutingMiniProgramBackendConnector _connector(
  MiniProgramBackendHttpClientFactory clientFactory,
) {
  return EndpointRoutingMiniProgramBackendConnector(
    backends: <String, MiniProgramBackendEndpoint>{
      'weather': MiniProgramBackendEndpoint(
        baseUri: Uri.parse('https://publisher.example.com/api/'),
      ),
    },
    deliveryContext: _deliveryContext,
    clientFactory: clientFactory,
  );
}

MiniProgramBackendRequest _request(String endpoint) {
  return MiniProgramBackendRequest(
    miniProgramId: 'weather',
    endpoint: endpoint,
  );
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
  _RecordingClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _DeferredConnector implements MiniProgramBackendConnector {
  _DeferredConnector(this.completer);

  final Completer<MiniProgramBackendResult> completer;
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];

  @override
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request) {
    calls.add(request);
    return completer.future;
  }
}

class _QueueConnector implements MiniProgramBackendConnector {
  _QueueConnector(List<MiniProgramBackendResult> results)
    : _results = Queue<MiniProgramBackendResult>.of(results);

  final Queue<MiniProgramBackendResult> _results;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return _results.removeFirst();
  }
}
