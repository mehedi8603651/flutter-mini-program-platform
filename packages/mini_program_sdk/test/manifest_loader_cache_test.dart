import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('ManifestLoader cache policy', () {
    test(
      'uses stale manifest and entry screen cache when backend is unreachable',
      () async {
        final source = _MutableMiniProgramSource(
          manifest: _buildManifest(
            cachePolicy: const MiniProgramCachePolicy(
              manifest: MiniProgramCacheMode.staleWhileError,
              entryScreen: MiniProgramCacheMode.staleWhileError,
            ),
          ),
          screenJson: _helloScreenJson,
        );
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        const loader = ManifestLoader();

        final initial = await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: source,
          manifestCache: manifestCache,
          screenCache: screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        expect(initial.usedStaleCache, isFalse);
        expect(manifestCache.read('profile_center'), isNotNull);
        expect(
          screenCache.read(
            miniProgramId: 'profile_center',
            version: '1.0.0',
            screenId: 'profile/home',
          ),
          isNotNull,
        );

        source.manifestException = const MiniProgramSourceException(
          message: 'Backend temporarily unavailable for manifest.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
        );
        source.screenException = const MiniProgramSourceException(
          message: 'Backend temporarily unavailable for screen.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
        );

        final fallback = await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: source,
          manifestCache: manifestCache,
          screenCache: screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        expect(fallback.usedStaleManifestCache, isTrue);
        expect(fallback.usedStaleEntryScreenCache, isTrue);
        expect(fallback.entryScreenJson, _helloScreenJson);
      },
    );

    test(
      'does not persist or reuse stale cache when manifest policy is noCache',
      () async {
        final source = _MutableMiniProgramSource(
          manifest: _buildManifest(
            cachePolicy: const MiniProgramCachePolicy(
              manifest: MiniProgramCacheMode.noCache,
              entryScreen: MiniProgramCacheMode.noCache,
            ),
          ),
          screenJson: _helloScreenJson,
        );
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        const loader = ManifestLoader();

        await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: source,
          manifestCache: manifestCache,
          screenCache: screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        expect(manifestCache.read('profile_center'), isNull);
        expect(
          screenCache.read(
            miniProgramId: 'profile_center',
            version: '1.0.0',
            screenId: 'profile/home',
          ),
          isNull,
        );

        source.manifestException = const MiniProgramSourceException(
          message: 'Backend temporarily unavailable for manifest.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
        );

        expect(
          () => loader.load(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            manifestCache: manifestCache,
            screenCache: screenCache,
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
            logger: const DebugPrintSdkLogger(),
          ),
          throwsA(
            isA<MiniProgramLoadException>().having(
              (error) => error.failure.errorCode,
              'errorCode',
              MiniProgramErrorCodes.backendUnreachable,
            ),
          ),
        );
      },
    );

    test(
      'does not reuse a stale entry screen when only manifest caching is allowed',
      () async {
        final source = _MutableMiniProgramSource(
          manifest: _buildManifest(
            cachePolicy: const MiniProgramCachePolicy(
              manifest: MiniProgramCacheMode.staleWhileError,
              entryScreen: MiniProgramCacheMode.noCache,
            ),
          ),
          screenJson: _helloScreenJson,
        );
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        const loader = ManifestLoader();

        await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: source,
          manifestCache: manifestCache,
          screenCache: screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        expect(manifestCache.read('profile_center'), isNotNull);
        expect(
          screenCache.read(
            miniProgramId: 'profile_center',
            version: '1.0.0',
            screenId: 'profile/home',
          ),
          isNull,
        );

        source.manifestException = const MiniProgramSourceException(
          message: 'Backend temporarily unavailable for manifest.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
        );
        source.screenException = const MiniProgramSourceException(
          message: 'Backend temporarily unavailable for screen.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
        );

        expect(
          () => loader.load(
            miniProgramId: 'profile_center',
            sdkVersion: '1.1.0',
            source: source,
            manifestCache: manifestCache,
            screenCache: screenCache,
            capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
            featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
            logger: const DebugPrintSdkLogger(),
          ),
          throwsA(
            isA<MiniProgramLoadException>().having(
              (error) => error.failure.errorCode,
              'errorCode',
              MiniProgramErrorCodes.backendUnreachable,
            ),
          ),
        );
      },
    );
  });
}

class _MutableMiniProgramSource implements MiniProgramSource {
  _MutableMiniProgramSource({required this.manifest, required this.screenJson});

  final MiniProgramManifest manifest;
  final Map<String, dynamic> screenJson;
  MiniProgramSourceException? manifestException;
  MiniProgramSourceException? screenException;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    final exception = manifestException;
    if (exception != null) {
      throw exception;
    }
    return manifest;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    final exception = screenException;
    if (exception != null) {
      throw exception;
    }
    return screenJson;
  }
}

MiniProgramManifest _buildManifest({
  required MiniProgramCachePolicy cachePolicy,
}) {
  return MiniProgramManifest(
    id: 'profile_center',
    version: '1.0.0',
    entry: 'profile/home',
    contractVersion: '1.0.0',
    sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: const [Capability.auth],
    cachePolicy: cachePolicy,
  );
}

const Map<String, dynamic> _helloScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'center',
    'child': <String, dynamic>{'type': 'text', 'data': 'Hello from cache test'},
  },
};
