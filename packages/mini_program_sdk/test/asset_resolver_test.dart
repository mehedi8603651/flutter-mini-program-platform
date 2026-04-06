import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('AssetResolver', () {
    test(
      'downloads and rewrites standard network image widgets to file paths',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'mini_program_asset_cache_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        final resolver = AssetResolver(
          client: MockClient((request) async {
            expect(
              request.url.toString(),
              'https://cdn.example.com/banner.png',
            );
            return http.Response.bytes(
              List<int>.generate(16, (index) => index),
              200,
              headers: <String, String>{'content-type': 'image/png'},
            );
          }),
        );

        final result = await resolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest(),
          screenJson: _imageScreenJson,
          assetCache: FileAssetCache(directory: tempDirectory),
          logger: const DebugPrintSdkLogger(),
        );

        final image = result.screenJson['body'] as Map<String, dynamic>;
        expect(image['type'], 'image');
        expect(image['imageType'], 'file');
        expect(File(image['src'] as String).existsSync(), isTrue);
        expect(result.downloadedAssetCount, 1);
        expect(result.cachedAssetCount, 0);
      },
    );

    test(
      'reuses cached file-backed assets when network downloads fail',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'mini_program_asset_cache_reuse_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        final cache = FileAssetCache(directory: tempDirectory);
        final seededResolver = AssetResolver(
          client: MockClient((request) async {
            return http.Response.bytes(
              List<int>.generate(8, (index) => index),
              200,
              headers: <String, String>{'content-type': 'image/png'},
            );
          }),
        );
        await seededResolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest(),
          screenJson: _imageScreenJson,
          assetCache: cache,
          logger: const DebugPrintSdkLogger(),
        );

        final offlineResolver = AssetResolver(
          client: MockClient((request) async {
            throw const SocketException('Network unavailable');
          }),
        );
        final result = await offlineResolver.resolveEntryScreenAssets(
          manifest: _cacheableManifest(),
          screenJson: _imageScreenJson,
          assetCache: cache,
          logger: const DebugPrintSdkLogger(),
        );

        final image = result.screenJson['body'] as Map<String, dynamic>;
        expect(image['imageType'], 'file');
        expect(File(image['src'] as String).existsSync(), isTrue);
        expect(result.cachedAssetCount, 1);
      },
    );

    test(
      'does not persist assets for noCache mini-program entry screens',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'mini_program_asset_cache_no_cache_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        final resolver = AssetResolver(
          client: MockClient((request) async {
            return http.Response.bytes(
              List<int>.generate(8, (index) => index),
              200,
              headers: <String, String>{'content-type': 'image/png'},
            );
          }),
        );

        final result = await resolver.resolveEntryScreenAssets(
          manifest: _noCacheManifest(),
          screenJson: _imageScreenJson,
          assetCache: FileAssetCache(directory: tempDirectory),
          logger: const DebugPrintSdkLogger(),
        );

        final image = result.screenJson['body'] as Map<String, dynamic>;
        expect(image['imageType'], 'network');
        expect(image['src'], 'https://cdn.example.com/banner.png');
        expect(tempDirectory.listSync(), isEmpty);
      },
    );
  });
}

MiniProgramManifest _cacheableManifest() {
  return const MiniProgramManifest(
    id: 'profile_center',
    version: '1.1.0',
    entry: 'profile_center_home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: <Capability>[Capability.analytics],
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
}

MiniProgramManifest _noCacheManifest() {
  return const MiniProgramManifest(
    id: 'feedback_form',
    version: '1.1.0',
    entry: 'feedback_form_home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: <Capability>[Capability.secureApi],
    cachePolicy: MiniProgramCachePolicy(
      manifest: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
      entryScreen: MiniProgramCacheRule(mode: MiniProgramCacheMode.noCache),
    ),
  );
}

const Map<String, dynamic> _imageScreenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'image',
    'src': 'https://cdn.example.com/banner.png',
    'imageType': 'network',
    'width': 120.0,
    'height': 80.0,
  },
};
