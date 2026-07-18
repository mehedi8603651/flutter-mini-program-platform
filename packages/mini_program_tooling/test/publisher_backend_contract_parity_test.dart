import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_tooling/src/publisher_backend_contract_controller.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Publisher API contract parity', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'publisher_backend_contract_parity_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'init preserves path, canonical bytes, and validation result',
      () async {
        const controller = PublisherBackendContractController();
        final result = await controller.init(
          PublisherBackendContractInitRequest(
            miniProgramRootPath: tempDirectory.path,
            appId: 'weather',
            backendBaseUri: Uri.parse('https://api.example.com/'),
            permissionReason: 'Load weather forecasts.',
          ),
        );

        expect(
          result.contractPath,
          p.join(tempDirectory.path, 'publisher_backend.json'),
        );
        expect(
          await File(result.contractPath).readAsString(),
          '{\n'
          '  "schemaVersion": 1,\n'
          '  "type": "mini_program_publisher_backend_contract",\n'
          '  "contractVersion": "1",\n'
          '  "appId": "weather",\n'
          '  "backendBaseUrl": "https://api.example.com",\n'
          '  "permissionReason": "Load weather forecasts.",\n'
          '  "healthEndpoint": "health",\n'
          '  "smokeTests": [\n'
          '    {\n'
          '      "id": "health",\n'
          '      "method": "GET",\n'
          '      "endpoint": "health",\n'
          '      "expectedStatus": 200,\n'
          '      "expectJsonObject": true\n'
          '    }\n'
          '  ]\n'
          '}\n',
        );

        final validated = await controller.validate(
          miniProgramRootPath: tempDirectory.path,
          explicitContractPath: null,
          allowLocalHttp: false,
        );
        expect(validated.contractPath, result.contractPath);
        expect(validated.contract.toJson(), result.contract.toJson());
      },
    );

    test('read preserves the exact missing-file failure', () async {
      const controller = PublisherBackendContractController();
      final missingPath = p.join(tempDirectory.path, 'missing.json');

      expect(
        () => controller.readContract(
          contractPath: missingPath,
          allowLocalHttp: false,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Publisher API contract file does not exist: $missingPath',
          ),
        ),
      );
    });

    test(
      'smoke preserves methods, headers, bodies, order, and disposal',
      () async {
        final requests = <http.BaseRequest>[];
        final client = _TrackingClient((request) async {
          requests.add(request);
          return _jsonResponse(request, 200, <String, Object?>{'ok': true});
        });
        final contract = _contractWithSmokeTests(
          <MiniProgramPublisherBackendSmokeCase>[
            for (final method in <String>[
              'GET',
              'POST',
              'PUT',
              'PATCH',
              'DELETE',
            ])
              MiniProgramPublisherBackendSmokeCase(
                id: method.toLowerCase(),
                method: method,
                endpoint: method.toLowerCase(),
                body: method == 'GET'
                    ? const <String, Object?>{}
                    : <String, Object?>{'method': method},
              ),
          ],
        );
        final controller = PublisherBackendContractController(
          httpClientFactory: () => client,
        );

        final result = await controller.smoke(
          PublisherBackendContractSmokeRequest(
            contractPath: 'publisher_backend.json',
            contract: contract,
            authToken: ' runtime-token ',
          ),
        );

        expect(result.passed, isTrue);
        expect(result.authTokenProvided, isTrue);
        expect(result.routes.map((route) => route.method), <String>[
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
        ]);
        expect(requests.map((request) => request.method), <String>[
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
        ]);
        for (final request in requests) {
          expect(request.headers['accept'], 'application/json');
          expect(request.headers['x-mini-program-app-id'], 'weather');
          expect(
            request.headers['x-mini-program-host-app'],
            'miniprogram-tooling',
          );
          expect(request.headers['x-mini-program-platform'], 'cli');
          expect(request.headers['authorization'], 'Bearer runtime-token');
          expect(
            request.headers['x-mini-program-request-id'],
            request.method.toLowerCase(),
          );
          if (request.method == 'GET') {
            expect(request.headers.containsKey('content-type'), isFalse);
          } else {
            expect(request.headers['content-type'], 'application/json');
            expect(
              (request as http.Request).body,
              jsonEncode(<String, Object?>{'method': request.method}),
            );
          }
        }
        expect(client.closed, isTrue);
      },
    );

    test('smoke preserves response and transport failure mapping', () async {
      final client = _TrackingClient((request) async {
        return switch (request.url.pathSegments.last) {
          'status' => _jsonResponse(request, 503, <String, Object?>{}),
          'json' => http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('[]')),
            200,
            request: request,
          ),
          'empty' => http.StreamedResponse(
            Stream<List<int>>.value(const <int>[]),
            200,
            request: request,
          ),
          'slow' => Future<http.StreamedResponse>.delayed(
            const Duration(milliseconds: 100),
            () => _jsonResponse(request, 200, <String, Object?>{}),
          ),
          'unreachable' => throw StateError('offline'),
          _ => throw StateError('unexpected route'),
        };
      });
      final contract = _contractWithSmokeTests(
        <MiniProgramPublisherBackendSmokeCase>[
          for (final id in <String>[
            'status',
            'json',
            'empty',
            'slow',
            'unreachable',
          ])
            MiniProgramPublisherBackendSmokeCase(id: id, endpoint: id),
        ],
      );
      final controller = PublisherBackendContractController(
        httpClientFactory: () => client,
      );

      final result = await controller.smoke(
        PublisherBackendContractSmokeRequest(
          contractPath: 'publisher_backend.json',
          contract: contract,
          timeout: const Duration(milliseconds: 1),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.authTokenProvided, isFalse);
      expect(
        result.routes
            .map(
              (route) => <Object?>[
                route.id,
                route.statusCode,
                route.passed,
                route.errorCode,
                route.message,
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[
            'status',
            503,
            false,
            MiniProgramPublisherBackendErrorCodes.unexpectedStatus,
            'Expected HTTP 200, got HTTP 503.',
          ],
          <Object?>[
            'json',
            200,
            false,
            MiniProgramPublisherBackendErrorCodes.invalidJson,
            'Expected a JSON object response.',
          ],
          <Object?>['empty', 200, true, null, null],
          <Object?>[
            'slow',
            null,
            false,
            MiniProgramPublisherBackendErrorCodes.timeout,
            'Timed out while calling Publisher API route.',
          ],
          <Object?>[
            'unreachable',
            null,
            false,
            MiniProgramPublisherBackendErrorCodes.unreachable,
            'Failed to reach Publisher API route: Bad state: offline',
          ],
        ],
      );
      expect(client.closed, isTrue);
    });
  });
}

MiniProgramPublisherBackendContract _contractWithSmokeTests(
  List<MiniProgramPublisherBackendSmokeCase> smokeTests,
) => MiniProgramPublisherBackendContract(
  appId: 'weather',
  backendBaseUri: Uri.parse('https://api.example.com/base'),
  smokeTests: smokeTests,
);

http.StreamedResponse _jsonResponse(
  http.BaseRequest request,
  int statusCode,
  Map<String, Object?> body,
) => http.StreamedResponse(
  Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
  statusCode,
  request: request,
);

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closed = true;
    super.close();
  }
}
