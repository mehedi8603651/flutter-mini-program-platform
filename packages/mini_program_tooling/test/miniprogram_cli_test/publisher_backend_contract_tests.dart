part of '../miniprogram_cli_test.dart';

void _registerPublisherBackendContractTests() {
  group('publisher-backend contract', () {
    test(
      'help and capabilities expose provider-neutral contract commands',
      () async {
        final helpOut = StringBuffer();
        final helpExitCode = await MiniprogramCli(
          stdoutSink: helpOut,
          stderrSink: StringBuffer(),
          workingDirectory: repoRoot.path,
        ).run(<String>['publisher-backend', 'contract', '--help']);

        expect(helpExitCode, 0);
        expect(helpOut.toString(), contains('init --backend-base-url'));
        expect(helpOut.toString(), contains('validate [--mini-program-root'));
        expect(helpOut.toString(), contains('smoke [--mini-program-root'));
        expect(helpOut.toString(), contains('handoff --delivery-url'));

        final capabilitiesOut = StringBuffer();
        final capabilitiesExitCode = await MiniprogramCli(
          stdoutSink: capabilitiesOut,
          stderrSink: StringBuffer(),
          workingDirectory: repoRoot.path,
        ).run(<String>['capabilities', '--json']);

        expect(capabilitiesExitCode, 0);
        final json = jsonDecode(capabilitiesOut.toString()) as Map;
        expect(json['toolingVersion'], '0.5.1');
        expect(
          json['capabilityIds'],
          contains('publisher_backend.contract.smoke'),
        );
        expect(
          json['commands'],
          contains('publisher-backend contract handoff'),
        );
      },
    );

    test('init writes deterministic contract and validate reads it', () async {
      final miniProgramRoot = p.join(tempDir.path, 'shop_demo');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'shop_demo',
        version: '1.0.0',
      );

      final initOut = StringBuffer();
      final initExitCode =
          await MiniprogramCli(
            stdoutSink: initOut,
            stderrSink: StringBuffer(),
            workingDirectory: miniProgramRoot,
          ).run(<String>[
            'publisher-backend',
            'contract',
            'init',
            '--backend-base-url',
            'https://api.publisher.example/',
            '--json',
          ]);

      expect(initExitCode, 0);
      final initJson = jsonDecode(initOut.toString()) as Map;
      expect(initJson['command'], 'publisher-backend contract init');
      expect(initJson['miniProgramId'], 'shop_demo');
      expect(initJson['backendBaseUrl'], 'https://api.publisher.example');
      expect(initJson['accessMode'], 'protected');
      final contractPath = initJson['contractPath'] as String;
      expect(await File(contractPath).exists(), isTrue);
      final contractJson =
          jsonDecode(await File(contractPath).readAsString()) as Map;
      expect(
        contractJson['type'],
        MiniProgramPublisherBackendContract.documentType,
      );
      expect(contractJson['smokeTests'], hasLength(1));

      final validateOut = StringBuffer();
      final validateExitCode = await MiniprogramCli(
        stdoutSink: validateOut,
        stderrSink: StringBuffer(),
        workingDirectory: miniProgramRoot,
      ).run(<String>['publisher-backend', 'contract', 'validate', '--json']);

      expect(validateExitCode, 0);
      final validateJson = jsonDecode(validateOut.toString()) as Map;
      expect(validateJson['valid'], isTrue);
      expect(validateJson['contractPath'], contractPath);
    });

    test('validate rejects non-local HTTP unless explicitly allowed', () async {
      final miniProgramRoot = p.join(tempDir.path, 'lan_demo');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'lan_demo',
        version: '1.0.0',
      );
      final contractPath = p.join(miniProgramRoot, 'publisher_backend.json');
      await File(contractPath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': MiniProgramPublisherBackendContract.documentType,
          'contractVersion': '1',
          'appId': 'lan_demo',
          'backendBaseUrl': 'http://192.168.1.10:9090',
          'accessMode': 'protected',
          'healthEndpoint': 'health',
          'smokeTests': <Object?>[
            <String, Object?>{
              'id': 'health',
              'method': 'GET',
              'endpoint': 'health',
              'expectedStatus': 200,
              'expectJsonObject': true,
            },
          ],
        }),
      );

      final stderr = StringBuffer();
      final rejectedExitCode = await MiniprogramCli(
        stdoutSink: StringBuffer(),
        stderrSink: stderr,
        workingDirectory: miniProgramRoot,
      ).run(<String>['publisher-backend', 'contract', 'validate']);

      expect(rejectedExitCode, 64);
      expect(stderr.toString(), contains('must use HTTPS'));

      final acceptedExitCode =
          await MiniprogramCli(
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: miniProgramRoot,
          ).run(<String>[
            'publisher-backend',
            'contract',
            'validate',
            '--allow-local-http',
          ]);

      expect(acceptedExitCode, 0);
    });

    test('smoke sends standard headers and redacts secrets', () async {
      final miniProgramRoot = p.join(tempDir.path, 'api_demo');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'api_demo',
        version: '1.0.0',
      );
      final requests = <_ObservedBackendRequest>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(
          _ObservedBackendRequest(
            method: request.method,
            path: request.uri.path,
            query: request.uri.query,
            headers: request.headers,
            body: body,
          ),
        );
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/orders') {
          request.response.statusCode = 201;
          request.response.write('{"data":{"orderId":"order-1"}}');
        } else {
          request.response.write('{"data":{"ok":true}}');
        }
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final contractPath = p.join(miniProgramRoot, 'publisher_backend.json');
      await File(contractPath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': MiniProgramPublisherBackendContract.documentType,
          'contractVersion': '1',
          'appId': 'api_demo',
          'backendBaseUrl': 'http://127.0.0.1:${server.port}',
          'accessMode': 'protected',
          'healthEndpoint': 'health',
          'smokeTests': <Object?>[
            <String, Object?>{
              'id': 'health',
              'method': 'GET',
              'endpoint': 'health',
              'expectedStatus': 200,
              'expectJsonObject': true,
            },
            <String, Object?>{
              'id': 'products_page',
              'method': 'GET',
              'endpoint': 'products/page?limit=1',
              'expectedStatus': 200,
              'expectJsonObject': true,
            },
            <String, Object?>{
              'id': 'create_order',
              'method': 'POST',
              'endpoint': 'orders',
              'body': <String, Object?>{'productId': 'product-1'},
              'expectedStatus': 201,
              'expectJsonObject': true,
            },
          ],
        }),
      );

      const accessKey = 'partner_key_12345678901234567890';
      const authToken = 'secret-auth-token';
      final stdout = StringBuffer();
      final exitCode =
          await MiniprogramCli(
            stdoutSink: stdout,
            stderrSink: StringBuffer(),
            workingDirectory: miniProgramRoot,
          ).run(<String>[
            'publisher-backend',
            'contract',
            'smoke',
            '--access-key',
            accessKey,
            '--auth-token',
            authToken,
            '--json',
          ]);

      expect(exitCode, 0);
      final output = stdout.toString();
      expect(output, isNot(contains(accessKey)));
      expect(output, isNot(contains(authToken)));
      final json = jsonDecode(output) as Map;
      expect(json['passed'], isTrue);
      expect(json['accessKeyProvided'], isTrue);
      expect(json['authTokenProvided'], isTrue);
      expect(json['routes'], hasLength(3));
      expect(requests, hasLength(3));
      expect(requests[0].headers.value('x-mini-program-app-id'), 'api_demo');
      expect(
        requests[0].headers.value('x-mini-program-host-app'),
        'miniprogram-tooling',
      );
      expect(requests[0].headers.value('x-mini-program-access-key'), accessKey);
      expect(requests[0].headers.value('authorization'), 'Bearer $authToken');
      expect(
        requests[0].headers.value('x-mini-program-backend-contract-version'),
        '1',
      );
      expect(requests[1].path, '/products/page');
      expect(requests[1].query, 'limit=1');
      expect(requests[2].method, 'POST');
      expect(requests[2].body, contains('product-1'));
    });

    test('smoke reports unexpected status without leaking secrets', () async {
      final miniProgramRoot = p.join(tempDir.path, 'failure_demo');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'failure_demo',
        version: '1.0.0',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = 500;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"errorCode":"broken"}');
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      await File(
        p.join(miniProgramRoot, 'publisher_backend.json'),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': MiniProgramPublisherBackendContract.documentType,
          'contractVersion': '1',
          'appId': 'failure_demo',
          'backendBaseUrl': 'http://127.0.0.1:${server.port}',
          'accessMode': 'protected',
          'healthEndpoint': 'health',
          'smokeTests': <Object?>[
            <String, Object?>{
              'id': 'health',
              'method': 'GET',
              'endpoint': 'health',
              'expectedStatus': 200,
              'expectJsonObject': true,
            },
          ],
        }),
      );

      const accessKey = 'partner_key_abcdefghij1234567890';
      final stdout = StringBuffer();
      final exitCode =
          await MiniprogramCli(
            stdoutSink: stdout,
            stderrSink: StringBuffer(),
            workingDirectory: miniProgramRoot,
          ).run(<String>[
            'publisher-backend',
            'contract',
            'smoke',
            '--access-key',
            accessKey,
            '--json',
          ]);

      expect(exitCode, 1);
      final output = stdout.toString();
      expect(output, isNot(contains(accessKey)));
      final json = jsonDecode(output) as Map;
      expect(json['passed'], isFalse);
      final routes = (json['routes'] as List).cast<Map>();
      expect(routes.single['statusCode'], 500);
      expect(
        routes.single['errorCode'],
        MiniProgramPublisherBackendErrorCodes.unexpectedStatus,
      );
    });

    test(
      'handoff creates protected partner package from generic contract',
      () async {
        final miniProgramRoot = p.join(tempDir.path, 'handoff_demo');
        await _writeMiniProgramFixture(
          miniProgramRoot,
          miniProgramId: 'handoff_demo',
          version: '1.0.0',
        );
        final contractPath = p.join(miniProgramRoot, 'publisher_backend.json');
        await File(contractPath).writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'type': MiniProgramPublisherBackendContract.documentType,
            'contractVersion': '1',
            'appId': 'handoff_demo',
            'backendBaseUrl': 'https://api.publisher.example',
            'accessMode': 'protected',
            'healthEndpoint': 'health',
            'smokeTests': <Object?>[
              <String, Object?>{
                'id': 'health',
                'method': 'GET',
                'endpoint': 'health',
                'expectedStatus': 200,
                'expectJsonObject': true,
              },
            ],
          }),
        );

        const accessKey = 'partner_key_12345678901234567890';
        final outputPath = p.join(miniProgramRoot, 'company-a.partner.json');
        final stdout = StringBuffer();
        final exitCode =
            await MiniprogramCli(
              stdoutSink: stdout,
              stderrSink: StringBuffer(),
              workingDirectory: miniProgramRoot,
            ).run(<String>[
              'publisher-backend',
              'contract',
              'handoff',
              '--delivery-url',
              'https://delivery.publisher.example/',
              '--access-key',
              accessKey,
              '--output',
              outputPath,
              '--json',
            ]);

        expect(exitCode, 0);
        final output = stdout.toString();
        expect(output, isNot(contains(accessKey)));
        final json = jsonDecode(output) as Map;
        expect(json['command'], 'publisher-backend contract handoff');
        expect(json['accessKeyIncluded'], isTrue);
        expect(json['backendBaseUrl'], 'https://api.publisher.example');
        final packageJson =
            jsonDecode(await File(outputPath).readAsString()) as Map;
        expect(packageJson['type'], 'mini_program_partner_handoff');
        expect(packageJson['appId'], 'handoff_demo');
        expect(packageJson['apiBaseUrl'], 'https://delivery.publisher.example');
        expect(packageJson['backendBaseUrl'], 'https://api.publisher.example');
        expect(packageJson['accessKey'], accessKey);
      },
    );
  });
}

class _ObservedBackendRequest {
  const _ObservedBackendRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final String query;
  final HttpHeaders headers;
  final String body;
}
