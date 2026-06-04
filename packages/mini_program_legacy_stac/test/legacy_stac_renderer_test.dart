import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_legacy_stac/mini_program_legacy_stac.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('legacyStacRenderers registers the legacy Stac format explicitly', () {
    final registry = MiniProgramScreenRendererRegistry.withDefaults(
      legacyStacRenderers,
    );

    expect(registry.resolve(_legacyManifest()), isA<StacScreenRenderer>());
  });

  testWidgets('StacScreenRenderer renders legacy screen JSON', (tester) async {
    final renderer = const StacScreenRenderer();
    await renderer.ensureInitialized(logger: const DebugPrintSdkLogger());

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => renderer.render(
            MiniProgramRenderRequest(
              context: context,
              manifest: _legacyManifest(),
              screenId: 'legacy_home',
              screenJson: const <String, dynamic>{
                'type': 'text',
                'data': 'Legacy Stac screen',
              },
              logger: const DebugPrintSdkLogger(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Legacy Stac screen'), findsOneWidget);
  });
}

MiniProgramManifest _legacyManifest() {
  return const MiniProgramManifest(
    id: 'legacy',
    version: '1.0.0',
    entry: 'legacy_home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: <CapabilityId>[],
  );
}
