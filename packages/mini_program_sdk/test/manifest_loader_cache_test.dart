import 'dart:io';

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
              manifest: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 3600,
              ),
              entryScreen: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 3600,
              ),
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
        expect(await manifestCache.read('profile_center'), isNotNull);
        expect(
          await screenCache.read(
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
              manifest: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.noCache,
              ),
              entryScreen: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.noCache,
              ),
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

        expect(await manifestCache.read('profile_center'), isNull);
        expect(
          await screenCache.read(
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
              manifest: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 3600,
              ),
              entryScreen: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.noCache,
              ),
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

        expect(await manifestCache.read('profile_center'), isNotNull);
        expect(
          await screenCache.read(
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

    test(
      'rejects stale manifest cache beyond the configured age limit',
      () async {
        final source = _MutableMiniProgramSource(
          manifest: _buildManifest(
            cachePolicy: const MiniProgramCachePolicy(
              manifest: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 1,
              ),
              entryScreen: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 1,
              ),
            ),
          ),
          screenJson: _helloScreenJson,
        );
        final manifestCache = InMemoryManifestCache();
        final screenCache = InMemoryScreenCache();
        const loader = ManifestLoader();

        await manifestCache.write(
          CachedManifestEntry(
            miniProgramId: 'profile_center',
            manifest: source.manifest,
            cachedAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        );
        await screenCache.write(
          CachedScreenEntry(
            miniProgramId: 'profile_center',
            version: '1.0.0',
            screenId: 'profile/home',
            screenJson: _helloScreenJson,
            cachedAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
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
              (error) => error.failure.details['manifestCacheExpired'],
              'manifestCacheExpired',
              isTrue,
            ),
          ),
        );
      },
    );
  });

  group('Persistent cache behavior', () {
    test(
      'reuses persisted cache across cache instances when backend is unreachable',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'mini_program_sdk_cache_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        final initialSource = _MutableMiniProgramSource(
          manifest: _buildManifest(
            cachePolicy: const MiniProgramCachePolicy(
              manifest: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 3600,
              ),
              entryScreen: MiniProgramCacheRule(
                mode: MiniProgramCacheMode.staleWhileError,
                maxStaleSeconds: 3600,
              ),
            ),
          ),
          screenJson: _helloScreenJson,
        );
        final initialCacheBundle = MiniProgramCacheBundle.fileBacked(
          rootDirectory: tempDirectory,
        );
        const loader = ManifestLoader();

        await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: initialSource,
          manifestCache: initialCacheBundle.manifestCache,
          screenCache: initialCacheBundle.screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        final offlineSource =
            _MutableMiniProgramSource(
                manifest: initialSource.manifest,
                screenJson: _helloScreenJson,
              )
              ..manifestException = const MiniProgramSourceException(
                message: 'Backend temporarily unavailable for manifest.',
                errorCode: MiniProgramErrorCodes.backendUnreachable,
              )
              ..screenException = const MiniProgramSourceException(
                message: 'Backend temporarily unavailable for screen.',
                errorCode: MiniProgramErrorCodes.backendUnreachable,
              );
        final coldStartCacheBundle = MiniProgramCacheBundle.fileBacked(
          rootDirectory: tempDirectory,
        );

        final fallback = await loader.load(
          miniProgramId: 'profile_center',
          sdkVersion: '1.1.0',
          source: offlineSource,
          manifestCache: coldStartCacheBundle.manifestCache,
          screenCache: coldStartCacheBundle.screenCache,
          capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
          featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
          logger: const DebugPrintSdkLogger(),
        );

        expect(fallback.usedStaleManifestCache, isTrue);
        expect(fallback.usedStaleEntryScreenCache, isTrue);
        expect(fallback.entryScreenJson, _helloScreenJson);
      },
    );

    test('does not persist noCache manifests and screens to disk', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_sdk_no_cache_test_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final source = _MutableMiniProgramSource(
        manifest: _buildManifest(
          cachePolicy: const MiniProgramCachePolicy(
            manifest: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
            entryScreen: MiniProgramCacheRule(
              mode: MiniProgramCacheMode.noCache,
            ),
          ),
        ),
        screenJson: _helloScreenJson,
      );
      final cacheBundle = MiniProgramCacheBundle.fileBacked(
        rootDirectory: tempDirectory,
      );
      const loader = ManifestLoader();

      await loader.load(
        miniProgramId: 'profile_center',
        sdkVersion: '1.1.0',
        source: source,
        manifestCache: cacheBundle.manifestCache,
        screenCache: cacheBundle.screenCache,
        capabilityRegistry: CapabilityRegistry(const [Capability.auth]),
        featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
        logger: const DebugPrintSdkLogger(),
      );

      final manifestsDir = Directory('${tempDirectory.path}/manifests');
      final screensDir = Directory('${tempDirectory.path}/screens');

      expect(await manifestsDir.exists(), isFalse);
      expect(await screensDir.exists(), isFalse);
    });
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
