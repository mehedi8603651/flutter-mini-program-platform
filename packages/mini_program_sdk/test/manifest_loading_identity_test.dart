import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('ManifestLoader delivery ordering', () {
    test(
      'validates manifest compatibility before loading screen resources',
      () async {
        final source = _TrackingSource(
          manifest: _manifest(sdkVersionRange: '>=2.0.0 <3.0.0'),
        );

        await expectLater(
          _load(source),
          throwsA(
            isA<MiniProgramLoadException>()
                .having(
                  (error) => error.failure.errorCode,
                  'errorCode',
                  MiniProgramErrorCodes.unsupportedSdkVersion,
                )
                .having(
                  (error) => error.failure.message,
                  'message',
                  'Mini-program "delivery_app" requires SDK >=2.0.0 <3.0.0, '
                      'but host SDK is 1.1.0.',
                )
                .having(
                  (error) => error.failure.details,
                  'details',
                  <String, dynamic>{
                    'miniProgramId': 'delivery_app',
                    'sdkVersionRange': '>=2.0.0 <3.0.0',
                    'hostSdkVersion': '1.1.0',
                  },
                ),
          ),
        );
        expect(source.calls, <String>['manifest']);
      },
    );

    test(
      'keeps Publisher API contract connectivity failure optional',
      () async {
        final logger = _RecordingLogger();
        final source = _TrackingSource(
          manifest: _manifest(),
          contractException: const MiniProgramSourceException(
            message: 'Publisher API is offline.',
            errorCode: MiniProgramErrorCodes.backendUnreachable,
          ),
        );

        final loaded = await _load(source, logger: logger);

        expect(loaded.manifest.id, 'delivery_app');
        expect(loaded.entryScreenJson, _screenJson);
        expect(loaded.publisherBackendContract, isNull);
        expect(source.calls, <String>[
          'manifest',
          'screen',
          'publisherBackend',
        ]);
        expect(
          logger.warnings,
          contains(
            'Publisher API contract could not be loaded; runtime API access '
            'will remain unavailable for this load.',
          ),
        );
      },
    );

    test('rejects a Publisher API contract owned by another app', () async {
      final source = _TrackingSource(
        manifest: _manifest(),
        contract: MiniProgramPublisherBackendContract(
          appId: 'another_app',
          backendBaseUri: Uri.parse('https://api.example.com'),
        ),
      );

      await expectLater(
        _load(source),
        throwsA(
          isA<MiniProgramLoadException>()
              .having(
                (error) => error.failure.errorCode,
                'errorCode',
                MiniProgramPublisherBackendErrorCodes.invalidContract,
              )
              .having(
                (error) => error.failure.message,
                'message',
                'Publisher API contract appId "another_app" does not '
                    'match "delivery_app".',
              )
              .having(
                (error) => error.failure.details,
                'details',
                <String, dynamic>{
                  'miniProgramId': 'delivery_app',
                  'version': '1.0.0',
                },
              ),
        ),
      );
      expect(source.calls, <String>['manifest', 'screen', 'publisherBackend']);
    });
  });

  test('delivery result types remain available from the public SDK barrel', () {
    final manifest = _manifest();
    final loaded = LoadedMiniProgram(
      manifest: manifest,
      entryScreenJson: _screenJson,
    );
    const screen = LoadedMiniProgramScreen(
      screenId: 'home',
      screenJson: _screenJson,
    );

    expect(const ManifestLoader(), isA<ManifestLoader>());
    expect(loaded.manifest, same(manifest));
    expect(screen.screenId, 'home');
  });
}

Future<LoadedMiniProgram> _load(
  _TrackingSource source, {
  SdkLogger logger = const DebugPrintSdkLogger(),
}) {
  return const ManifestLoader().load(
    miniProgramId: 'delivery_app',
    sdkVersion: '1.1.0',
    source: source,
    manifestCache: InMemoryManifestCache(),
    screenCache: InMemoryScreenCache(),
    capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
    featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
    logger: logger,
  );
}

MiniProgramManifest _manifest({String sdkVersionRange = '>=1.0.0 <2.0.0'}) {
  return MiniProgramManifest(
    id: 'delivery_app',
    version: '1.0.0',
    entry: 'home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: sdkVersionRange),
    requiredCapabilities: const <CapabilityId>[],
  );
}

class _TrackingSource
    implements MiniProgramSource, MiniProgramPublisherBackendContractSource {
  _TrackingSource({
    required this.manifest,
    this.contract,
    this.contractException,
  });

  final MiniProgramManifest manifest;
  final MiniProgramPublisherBackendContract? contract;
  final MiniProgramSourceException? contractException;
  final List<String> calls = <String>[];

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    calls.add('manifest');
    return manifest;
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    calls.add('screen');
    return _screenJson;
  }

  @override
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) async {
    calls.add('publisherBackend');
    final exception = contractException;
    if (exception != null) {
      throw exception;
    }
    return contract;
  }
}

class _RecordingLogger implements SdkLogger {
  final List<String> warnings = <String>[];

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {}

  @override
  void info(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {}

  @override
  void warn(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    warnings.add(message);
  }
}

const Map<String, dynamic> _screenJson = <String, dynamic>{
  'type': 'scaffold',
  'body': <String, dynamic>{
    'type': 'text',
    'data': 'Delivery identity fixture',
  },
};
