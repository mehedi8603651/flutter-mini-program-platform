import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('EndpointRoutingMiniProgramSource', () {
    test('routes each appId to its configured endpoint', () async {
      final createdSources = <_RecordingSource>[];
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://cdn.example.com/coupon/'),
          ),
          'rewards': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://cdn.example.com/rewards/'),
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

      final couponManifest = await source.loadManifest('coupon_demo');
      final rewardsManifest = await source.loadManifest('rewards');
      await source.loadScreen(
        miniProgramId: 'coupon_demo',
        version: '1.0.0',
        screenId: 'home',
      );

      expect(couponManifest.id, 'coupon_demo');
      expect(rewardsManifest.id, 'rewards');
      expect(createdSources, hasLength(2));
      expect(
        createdSources[0].endpoint.apiBaseUri.toString(),
        contains('coupon'),
      );
      expect(
        createdSources[1].endpoint.apiBaseUri.toString(),
        contains('rewards'),
      );
      expect(createdSources[0].loadManifestCalls, <String>['coupon_demo']);
      expect(
        createdSources[0].loadScreenCalls.single.miniProgramId,
        'coupon_demo',
      );
      final assetBytes = await source.loadJsonAsset(
        miniProgramId: 'coupon_demo',
        version: '1.0.0',
        assetPath: 'data/items.json',
      );
      expect(assetBytes, <int>[91, 93]);
      expect(createdSources[0].loadJsonAssetCalls, <String>['data/items.json']);
      final contract = await source.loadPublisherBackendContract(
        miniProgramId: 'coupon_demo',
        version: '1.0.0',
      );
      expect(contract?.appId, 'coupon_demo');
    });

    test(
      'supports static artifact endpoints without credential headers',
      () async {
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
        expect(
          createdSources.single.endpoint.apiBaseUri.toString(),
          contains('public'),
        );
      },
    );

    test('exposes per-app accepted policies from routing', () {
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'temporary': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://tmp.example.com/api/'),
            cachePolicy: const MiniProgramCachePolicy(
              dataTtl: Duration(hours: 12),
              maxBytes: 5 * 1024 * 1024,
            ),
            liveStatePolicy: const MiniProgramLiveStatePolicy(
              maxBytes: 3 * 1024 * 1024,
              maxEntries: 1500,
              maxValueBytes: 512 * 1024,
              maxDepth: 24,
            ),
            publisherApiPolicy: const MiniProgramPublisherApiPolicy(
              enabled: true,
            ),
            locationPolicy: const MiniProgramLocationPolicy(enabled: true),
          ),
          'normal': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://normal.example.com/api/'),
          ),
        },
        deliveryContext: _deliveryContext,
      );

      expect(
        source.cachePolicyFor('temporary').dataTtl,
        const Duration(hours: 12),
      );
      expect(source.cachePolicyFor('temporary').maxBytes, 5 * 1024 * 1024);
      expect(source.cachePolicyFor('normal').dataTtl, const Duration(days: 30));
      expect(source.liveStatePolicyFor('temporary').maxBytes, 3 * 1024 * 1024);
      expect(source.liveStatePolicyFor('temporary').maxEntries, 1500);
      expect(source.liveStatePolicyFor('normal').maxEntries, 1000);
      expect(source.publisherApiPolicyFor('temporary').enabled, isTrue);
      expect(source.publisherApiPolicyFor('normal').enabled, isFalse);
      expect(source.locationPolicyFor('temporary').enabled, isTrue);
      expect(source.locationPolicyFor('normal').enabled, isFalse);
      expect(source.deliveryContext, same(_deliveryContext));
    });

    test('throws a structured error for an unregistered appId', () async {
      final source = EndpointRoutingMiniProgramSource(
        endpoints: <String, MiniProgramEndpoint>{
          'coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://cdn.example.com/coupon/'),
          ),
        },
        deliveryContext: _deliveryContext,
      );

      expect(
        () => source.loadManifest('rewards'),
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
          'coupon_demo': MiniProgramEndpoint(
            apiBaseUri: Uri.parse('https://cdn.example.com/coupon/'),
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

      await source.loadManifest('coupon_demo');
      source.dispose();

      expect(createdSources.single.disposeCount, 1);
    });
  });
}

const MiniProgramDeliveryContext _deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'host_app',
  sdkVersion: '1.0.0',
  hostVersion: '1.0.0',
  capabilities: <CapabilityId>{CapabilityIds.analytics},
  platform: 'android',
  locale: 'en-US',
);

class _RecordingSource
    implements
        DisposableMiniProgramSource,
        MiniProgramJsonAssetSource,
        MiniProgramPublisherBackendContractSource {
  _RecordingSource({required this.appId, required this.endpoint});

  final String appId;
  final MiniProgramEndpoint endpoint;
  final List<String> loadManifestCalls = <String>[];
  final List<_ScreenCall> loadScreenCalls = <_ScreenCall>[];
  final List<String> loadJsonAssetCalls = <String>[];
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
      requiredCapabilities: const <CapabilityId>[CapabilityIds.analytics],
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
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async {
    loadJsonAssetCalls.add(assetPath);
    return <int>[91, 93];
  }

  @override
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) async {
    return MiniProgramPublisherBackendContract(
      appId: miniProgramId,
      backendBaseUri: Uri.parse('https://publisher.example.com/api/'),
    );
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
