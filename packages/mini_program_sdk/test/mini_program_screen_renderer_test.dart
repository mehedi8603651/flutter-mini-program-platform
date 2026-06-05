import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgramScreenRendererRegistry', () {
    test('selects Mp by default and rejects unsupported formats', () {
      final registry = MiniProgramScreenRendererRegistry.withDefaults();

      expect(
        () => registry.resolve(_manifest(screenFormat: 'legacy-test')),
        throwsA(isA<MiniProgramRenderException>()),
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
          const <MiniProgramScreenRenderer>[_DuplicateMpRenderer()],
        ),
        throwsArgumentError,
      );
    });

    test('accepts an explicit custom-format renderer', () {
      final registry = MiniProgramScreenRendererRegistry.withDefaults(
        const <MiniProgramScreenRenderer>[_TestCustomRenderer()],
      );

      expect(
        registry.resolve(_manifest(screenFormat: 'custom')),
        isA<_TestCustomRenderer>(),
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

class _DuplicateMpRenderer extends MiniProgramScreenRenderer {
  const _DuplicateMpRenderer();

  @override
  String get screenFormat => MiniProgramScreenFormats.mp;

  @override
  Set<int> get supportedSchemaVersions => const <int>{1};

  @override
  Widget render(MiniProgramRenderRequest request) => const SizedBox.shrink();
}

class _TestCustomRenderer extends MiniProgramScreenRenderer {
  const _TestCustomRenderer();

  @override
  String get screenFormat => 'custom';

  @override
  Set<int> get supportedSchemaVersions => const <int>{};

  @override
  Widget render(MiniProgramRenderRequest request) => const SizedBox.shrink();
}
