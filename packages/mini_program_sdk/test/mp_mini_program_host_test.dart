import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets('base MiniProgramHost renders Mp screens without adapters', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProgramHost(
          miniProgramId: 'mp_test',
          sdkVersion: '1.0.0',
          source: const _MpSource(),
          hostBridge: const _HostBridge(),
          capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mp-only host screen'), findsOneWidget);
  });
}

class _MpSource implements MiniProgramSource {
  const _MpSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return const MiniProgramManifest(
      id: 'mp_test',
      version: '1.0.0',
      entry: 'mp_test_home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: <CapabilityId>[],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return const <String, dynamic>{
      'schemaVersion': 1,
      'screenId': 'mp_test_home',
      'root': <String, dynamic>{
        'type': 'text',
        'props': <String, dynamic>{'data': 'Mp-only host screen'},
        'children': <Object?>[],
      },
    };
  }
}

class _HostBridge implements HostBridge {
  const _HostBridge();

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => HostActionResult.success(actionName: ActionNames.callSecureApi);

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => HostActionResult.success(actionName: ActionNames.openNativeScreen);

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success(actionName: ActionNames.trackEvent);
}
