import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgramScreenRendererRegistry', () {
    test('selects Stac for legacy manifests and Mp for Mp manifests', () {
      final registry = MiniProgramScreenRendererRegistry.withDefaults();

      expect(
        registry.resolve(
          _manifest(screenFormat: MiniProgramScreenFormats.stac),
        ),
        isA<StacScreenRenderer>(),
      );
      expect(
        registry.resolve(
          _manifest(
            screenFormat: MiniProgramScreenFormats.mp,
            screenSchemaVersion: 1,
          ),
        ),
        isA<MpScreenRenderer>(),
      );
    });

    test('reports unsupported formats and schema versions', () {
      final registry = MiniProgramScreenRendererRegistry.withDefaults();

      expect(
        () => registry.resolve(_manifest(screenFormat: 'future')),
        throwsA(isA<MiniProgramRenderException>()),
      );
      expect(
        () => registry.resolve(
          _manifest(
            screenFormat: MiniProgramScreenFormats.mp,
            screenSchemaVersion: 99,
          ),
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    });

    test('rejects duplicate renderer registrations', () {
      expect(
        () => MiniProgramScreenRendererRegistry.withDefaults(
          const <MiniProgramScreenRenderer>[_DuplicateStacRenderer()],
        ),
        throwsArgumentError,
      );
    });
  });
}

MiniProgramManifest _manifest({
  required String screenFormat,
  int? screenSchemaVersion,
}) {
  return MiniProgramManifest(
    id: 'coupon',
    version: '1.0.0',
    entry: 'coupon_home',
    contractVersion: '1.0.0',
    sdkVersionRange: const SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: const <CapabilityId>[CapabilityIds.auth],
    screenFormat: screenFormat,
    screenSchemaVersion: screenSchemaVersion,
  );
}

class _DuplicateStacRenderer extends MiniProgramScreenRenderer {
  const _DuplicateStacRenderer();

  @override
  String get screenFormat => MiniProgramScreenFormats.stac;

  @override
  Set<int> get supportedSchemaVersions => const <int>{};

  @override
  Widget render(MiniProgramRenderRequest request) => const SizedBox.shrink();
}
