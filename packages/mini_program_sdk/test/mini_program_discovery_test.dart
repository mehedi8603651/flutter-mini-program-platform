import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgramDiscoveryResolver', () {
    test(
      'returns live for remote delivery when manifest load succeeds',
      () async {
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        final resolver = MiniProgramDiscoveryResolver(
          now: () => DateTime.utc(2026, 4, 6, 12),
        );

        final result = await resolver.resolve(
          miniProgramId: 'profile_center',
          source: _SuccessfulSource(manifest: _profileCenterManifest),
          manifestCache: manifestCache,
          screenCache: screenCache,
          sourceKind: MiniProgramDiscoverySourceKind.remote,
        );

        expect(result.status, MiniProgramDiscoveryStatus.live);
        expect(result.canOpen, isTrue);
        expect(result.manifest?.version, '1.1.0');
        expect(await manifestCache.read('profile_center'), isNotNull);
      },
    );

    test(
      'returns cached for bundled delivery when manifest load succeeds',
      () async {
        final resolver = MiniProgramDiscoveryResolver();

        final result = await resolver.resolve(
          miniProgramId: 'profile_center',
          source: _SuccessfulSource(manifest: _profileCenterManifest),
          manifestCache: InMemoryManifestCache(),
          screenCache: InMemoryScreenCache(),
          sourceKind: MiniProgramDiscoverySourceKind.bundled,
        );

        expect(result.status, MiniProgramDiscoveryStatus.cached);
        expect(result.canOpen, isTrue);
        expect(result.displayMessage, contains('Bundled release'));
      },
    );

    test(
      'returns staleButAllowed when backend is offline and cached manifest plus screen exist',
      () async {
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        final now = DateTime.utc(2026, 4, 6, 12);
        final resolver = MiniProgramDiscoveryResolver(now: () => now);

        await manifestCache.write(
          CachedManifestEntry(
            miniProgramId: 'profile_center',
            manifest: _profileCenterManifest,
            cachedAt: now.subtract(const Duration(minutes: 20)),
          ),
        );
        await screenCache.write(
          CachedScreenEntry(
            miniProgramId: 'profile_center',
            version: '1.1.0',
            screenId: 'profile_center_home',
            screenJson: const <String, dynamic>{
              'type': 'text',
              'data': 'Cached profile center screen',
            },
            cachedAt: now.subtract(const Duration(minutes: 10)),
          ),
        );

        final result = await resolver.resolve(
          miniProgramId: 'profile_center',
          source: const _FailingSource(
            MiniProgramSourceException(
              message: 'Backend is offline.',
              errorCode: MiniProgramErrorCodes.backendUnreachable,
            ),
          ),
          manifestCache: manifestCache,
          screenCache: screenCache,
          sourceKind: MiniProgramDiscoverySourceKind.remote,
        );

        expect(result.status, MiniProgramDiscoveryStatus.staleButAllowed);
        expect(result.canOpen, isTrue);
        expect(result.manifest?.version, '1.1.0');
        expect(result.displayMessage, contains('backend is offline'));
      },
    );

    test(
      'returns unavailable when backend is offline and no valid entry screen cache exists',
      () async {
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        final now = DateTime.utc(2026, 4, 6, 12);
        final resolver = MiniProgramDiscoveryResolver(now: () => now);

        await manifestCache.write(
          CachedManifestEntry(
            miniProgramId: 'profile_center',
            manifest: _profileCenterManifest,
            cachedAt: now.subtract(const Duration(minutes: 20)),
          ),
        );

        final result = await resolver.resolve(
          miniProgramId: 'profile_center',
          source: const _FailingSource(
            MiniProgramSourceException(
              message: 'Backend timed out.',
              errorCode: MiniProgramErrorCodes.backendTimeout,
            ),
          ),
          manifestCache: manifestCache,
          screenCache: screenCache,
          sourceKind: MiniProgramDiscoverySourceKind.remote,
        );

        expect(result.status, MiniProgramDiscoveryStatus.unavailable);
        expect(result.canOpen, isFalse);
        expect(result.displayMessage, 'No valid offline copy is available.');
      },
    );
  });
}

const MiniProgramManifest _profileCenterManifest = MiniProgramManifest(
  id: 'profile_center',
  version: '1.1.0',
  entry: 'profile_center_home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
  requiredCapabilities: <Capability>[
    Capability.analytics,
    Capability.nativeNavigation,
  ],
  cachePolicy: MiniProgramCachePolicy(
    manifest: MiniProgramCacheRule(
      mode: MiniProgramCacheMode.staleWhileError,
      maxStaleSeconds: 3600,
    ),
    entryScreen: MiniProgramCacheRule(
      mode: MiniProgramCacheMode.staleWhileError,
      maxStaleSeconds: 3600,
    ),
  ),
);

class _SuccessfulSource implements MiniProgramSource {
  const _SuccessfulSource({required this.manifest});

  final MiniProgramManifest manifest;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return manifest;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{};
  }
}

class _FailingSource implements MiniProgramSource {
  const _FailingSource(this.exception);

  final MiniProgramSourceException exception;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    throw exception;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    throw exception;
  }
}
