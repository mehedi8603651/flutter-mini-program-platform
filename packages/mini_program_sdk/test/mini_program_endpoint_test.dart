import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('EndpointRoutingMiniProgramSource', () {
    test('routes each appId to its configured endpoint', () async {
      final createdSources = <_RecordingSource>[];
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'aws_coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
            accessKey: 'mpk_live_aws',
          ),
          'gcp_rewards': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://gcp.example.com/api/'),
            accessKey: 'mpk_live_gcp',
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) {
              final createdSource = _RecordingSource(
                appId: appId,
                endpoint: endpoint,
              );
              createdSources.add(createdSource);
              return createdSource;
            },
      );

      final awsManifest = await source.loadManifest('aws_coupon_demo');
      final gcpManifest = await source.loadManifest('gcp_rewards');
      await source.loadScreen(
        miniProgramId: 'aws_coupon_demo',
        version: '1.0.0',
        screenId: 'home',
      );

      expect(awsManifest.id, 'aws_coupon_demo');
      expect(gcpManifest.id, 'gcp_rewards');
      expect(createdSources, hasLength(2));
      expect(createdSources[0].endpoint.accessKey, 'mpk_live_aws');
      expect(createdSources[1].endpoint.accessKey, 'mpk_live_gcp');
      expect(createdSources[0].loadManifestCalls, <String>['aws_coupon_demo']);
      expect(
        createdSources[0].loadScreenCalls.single.miniProgramId,
        'aws_coupon_demo',
      );
    });

    test('supports public endpoints without an access key', () async {
      final createdSources = <_RecordingSource>[];
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'public_coupon_demo': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://cdn.example.com/public/'),
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) {
              final createdSource = _RecordingSource(
                appId: appId,
                endpoint: endpoint,
              );
              createdSources.add(createdSource);
              return createdSource;
            },
      );

      final manifest = await source.loadManifest('public_coupon_demo');

      expect(manifest.id, 'public_coupon_demo');
      expect(createdSources.single.endpoint.accessKey, isNull);
    });

    test('builds a backend connector from endpoint backend config', () async {
      final connector = buildEndpointRoutingBackendConnector(
        endpoints: <String, MiniProgramEndpoint>{
          'coupon': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://delivery.example.com/api/'),
            accessKey: 'mpk_live_coupon',
            backend: MiniProgramBackendEndpoint(
              baseUri: Uri.parse('https://publisher.example.com/api/'),
              sendAccessKeyToBackend: true,
            ),
          ),
          'public_demo': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://cdn.example.com/public/'),
          ),
        },
        deliveryContext: _deliveryContext,
        clientFactory: () => _BackendRecordingClient(),
      );

      expect(connector, isNotNull);

      final result = await connector!.call(
        const MiniProgramBackendRequest(
          miniProgramId: 'coupon',
          endpoint: 'home/bootstrap',
        ),
      );

      expect(result.isSuccess, isTrue);
      (connector as DisposableMiniProgramBackendConnector).dispose();
    });

    test('rejects a blank protected access key', () {
      expect(
        () => EndpointRoutingMiniProgramSource(
          endpoints: <String, MiniProgramEndpoint>{
            'aws_coupon_demo': MiniProgramEndpoint(
              apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
              accessKey: '   ',
            ),
          },
          deliveryContext: _deliveryContext,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws a structured error for an unregistered appId', () async {
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'aws_coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
            accessKey: 'mpk_live_aws',
          ),
        },
        deliveryContext: _deliveryContext,
      );

      expect(
        () => source.loadManifest('gcp_rewards'),
        throwsA(
          isA<MiniProgramSourceException>()
              .having(
                (error) => error.errorCode,
                'errorCode',
                MiniProgramErrorCodes.endpointNotConfigured,
              )
              .having(
                (error) => error.message,
                'message',
                contains('No MiniProgramEndpoint is configured'),
              ),
        ),
      );
    });

    test('disposes created endpoint sources', () async {
      final createdSources = <_RecordingSource>[];
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'aws_coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
            accessKey: 'mpk_live_aws',
          ),
        },
        deliveryContext: _deliveryContext,
        sourceFactory:
            ({required appId, required endpoint, required deliveryContext}) {
              final createdSource = _RecordingSource(
                appId: appId,
                endpoint: endpoint,
              );
              createdSources.add(createdSource);
              return createdSource;
            },
      );

      await source.loadManifest('aws_coupon_demo');
      source.dispose();

      expect(createdSources.single.disposeCount, 1);
    });
  });
}

const MiniProgramDeliveryContext _deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'host_app',
  sdkVersion: '1.0.0',
  hostVersion: '1.0.0',
  capabilities: <Capability>{Capability.analytics},
  platform: 'android',
  locale: 'en-US',
);

class _RecordingSource implements DisposableMiniProgramSource {
  _RecordingSource({required this.appId, required this.endpoint});

  final String appId;
  final MiniProgramEndpoint endpoint;
  final List<String> loadManifestCalls = <String>[];
  final List<_ScreenCall> loadScreenCalls = <_ScreenCall>[];
  int disposeCount = 0;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    loadManifestCalls.add(miniProgramId);
    return MiniProgramManifest(
      id: miniProgramId,
      version: '1.0.0',
      entry: 'home',
      contractVersion: '1.0.0',
      sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: const <Capability>[Capability.analytics],
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    loadScreenCalls.add(
      _ScreenCall(
        miniProgramId: miniProgramId,
        version: version,
        screenId: screenId,
      ),
    );
    return const <String, dynamic>{'type': 'text', 'data': 'Loaded'};
  }

  @override
  void dispose() {
    disposeCount++;
  }
}

class _ScreenCall {
  const _ScreenCall({
    required this.miniProgramId,
    required this.version,
    required this.screenId,
  });

  final String miniProgramId;
  final String version;
  final String screenId;
}

class _BackendRecordingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(
      request.url.toString(),
      'https://publisher.example.com/api/home/bootstrap',
    );
    expect(
      request.headers[MiniProgramHttpHeaders.accessKey],
      'mpk_live_coupon',
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(<int>[
        123,
        34,
        111,
        107,
        34,
        58,
        116,
        114,
        117,
        101,
        125,
      ]),
      200,
      request: request,
    );
  }
}
