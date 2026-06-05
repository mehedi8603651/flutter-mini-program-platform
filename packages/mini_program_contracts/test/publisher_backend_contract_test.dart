import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('MiniProgramPublisherBackendContract', () {
    test('round-trips protected contract JSON', () {
      final contract = MiniProgramPublisherBackendContract(
        appId: 'shop_demo',
        backendBaseUri: Uri.parse('https://api.publisher.example/'),
        smokeTests: <MiniProgramPublisherBackendSmokeCase>[
          MiniProgramPublisherBackendSmokeCase(
            id: 'products_page',
            endpoint: 'products/page?limit=1',
          ),
          MiniProgramPublisherBackendSmokeCase(
            id: 'create_order',
            method: 'POST',
            endpoint: 'orders',
            body: const <String, Object?>{'productId': 'product-1'},
            expectation: const MiniProgramPublisherBackendSmokeExpectation(
              expectedStatus: 201,
            ),
          ),
        ],
      );

      final json = contract.toJson();

      expect(json, <String, Object?>{
        'schemaVersion': 1,
        'type': 'mini_program_publisher_backend_contract',
        'contractVersion': '1',
        'appId': 'shop_demo',
        'backendBaseUrl': 'https://api.publisher.example',
        'accessMode': 'protected',
        'healthEndpoint': 'health',
        'smokeTests': <Object?>[
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
      });

      final decoded = MiniProgramPublisherBackendContract.fromJson(json);

      expect(decoded.appId, 'shop_demo');
      expect(
        decoded.backendBaseUri.toString(),
        'https://api.publisher.example',
      );
      expect(decoded.accessMode, 'protected');
      expect(decoded.isProtected, isTrue);
      expect(decoded.smokeTests, hasLength(2));
      expect(decoded.smokeTests[1].method, 'POST');
      expect(decoded.smokeTests[1].expectation.expectedStatus, 201);
    });

    test('round-trips public contract JSON', () {
      final contract = MiniProgramPublisherBackendContract(
        appId: 'public_demo',
        backendBaseUri: Uri.parse('https://api.publisher.example'),
        accessMode: MiniProgramPublisherBackendContract.accessModePublic,
      );

      final decoded = MiniProgramPublisherBackendContract.fromJson(
        contract.toJson(),
      );

      expect(decoded.accessMode, 'public');
      expect(decoded.isProtected, isFalse);
      expect(decoded.smokeTests.single.id, 'health');
      expect(decoded.smokeTests.single.endpoint, 'health');
    });

    test('accepts loopback HTTP and rejects non-local HTTP by default', () {
      final loopback = MiniProgramPublisherBackendContract(
        appId: 'local_demo',
        backendBaseUri: Uri.parse('http://127.0.0.1:9090/'),
      );

      expect(loopback.backendBaseUri.toString(), 'http://127.0.0.1:9090');

      expect(
        () => MiniProgramPublisherBackendContract(
          appId: 'lan_demo',
          backendBaseUri: Uri.parse('http://192.168.1.10:9090/'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts LAN HTTP only when explicitly enabled', () {
      final contract = MiniProgramPublisherBackendContract(
        appId: 'lan_demo',
        backendBaseUri: Uri.parse('http://192.168.1.10:9090/'),
        allowLocalHttp: true,
      );

      expect(contract.backendBaseUri.toString(), 'http://192.168.1.10:9090');
    });

    test('rejects malformed contracts and smoke routes', () {
      expect(
        () => MiniProgramPublisherBackendContract.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'type': 'wrong',
          'contractVersion': '1',
          'appId': 'shop_demo',
          'backendBaseUrl': 'https://api.publisher.example',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MiniProgramPublisherBackendContract(
          appId: 'bad app',
          backendBaseUri: Uri.parse('https://api.publisher.example'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MiniProgramPublisherBackendContract(
          appId: 'shop_demo',
          backendBaseUri: Uri.parse('https://api.publisher.example'),
          smokeTests: <MiniProgramPublisherBackendSmokeCase>[
            MiniProgramPublisherBackendSmokeCase(
              id: 'bad',
              endpoint: 'https://evil.example/orders',
            ),
          ],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MiniProgramPublisherBackendSmokeCase(
          id: 'bad',
          method: 'TRACE',
          endpoint: 'orders',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MiniProgramPublisherBackendSmokeCase(
          id: 'bad',
          endpoint: '../orders',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MiniProgramPublisherBackendSmokeCase(
          id: 'bad',
          endpoint: 'orders',
          expectation: MiniProgramPublisherBackendSmokeExpectation(
            expectedStatus: 99,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
