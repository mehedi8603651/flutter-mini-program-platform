import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets('loads runtime from MiniProgramRuntimeScope', (tester) async {
    final runtime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: const <String, dynamic>{
          'type': 'scaffold',
          'body': <String, dynamic>{
            'type': 'center',
            'child': <String, dynamic>{
              'type': 'text',
              'data': 'Scoped runtime screen',
            },
          },
        },
      ),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <Capability>[
        Capability.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );

    await tester.pumpWidget(
      MiniProgramRuntimeScope(
        runtime: runtime,
        child: const MaterialApp(
          home: MiniProgramPage(miniProgramId: 'profile_center'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scoped runtime screen'), findsOneWidget);
  });

  testWidgets('explicit runtime overrides scoped runtime', (tester) async {
    final scopedRuntime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: const <String, dynamic>{
          'type': 'scaffold',
          'body': <String, dynamic>{
            'type': 'center',
            'child': <String, dynamic>{
              'type': 'text',
              'data': 'Scoped runtime screen',
            },
          },
        },
      ),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <Capability>[
        Capability.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );
    final explicitRuntime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: const <String, dynamic>{
          'type': 'scaffold',
          'body': <String, dynamic>{
            'type': 'center',
            'child': <String, dynamic>{
              'type': 'text',
              'data': 'Explicit runtime screen',
            },
          },
        },
      ),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <Capability>[
        Capability.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );

    await tester.pumpWidget(
      MiniProgramRuntimeScope(
        runtime: scopedRuntime,
        child: MaterialApp(
          home: MiniProgramPage(
            miniProgramId: 'profile_center',
            runtime: explicitRuntime,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explicit runtime screen'), findsOneWidget);
    expect(find.text('Scoped runtime screen'), findsNothing);
  });

  testWidgets('renders default error scaffold with provided title', (
    tester,
  ) async {
    final runtime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: const _FailingManifestSource(),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <Capability>[
        Capability.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );

    await tester.pumpWidget(
      MiniProgramRuntimeScope(
        runtime: runtime,
        child: const MaterialApp(
          home: MiniProgramPage(
            miniProgramId: 'profile_center',
            title: 'Profile Center',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile Center'), findsOneWidget);
    expect(find.text('Backend unavailable'), findsOneWidget);
  });
}

class _FakeMiniProgramSource implements MiniProgramSource {
  const _FakeMiniProgramSource({
    required this.manifest,
    required this.screenJson,
  });

  final MiniProgramManifest manifest;
  final Map<String, dynamic> screenJson;

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
    return screenJson;
  }
}

class _FailingManifestSource implements MiniProgramSource {
  const _FailingManifestSource();

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    throw const MiniProgramSourceException(
      message:
          'Failed to reach the mini-program backend while loading manifest.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    throw const MiniProgramSourceException(
      message:
          'Failed to reach the mini-program backend while loading manifest.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
    );
  }
}

class _FakeHostBridge implements HostBridge {
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return HostActionResult.success(actionName: ActionNames.trackEvent);
  }
}

MiniProgramManifest _buildManifest() {
  return const MiniProgramManifest(
    id: 'profile_center',
    version: '1.0.0',
    entry: 'profile_center_home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: <Capability>[Capability.analytics],
  );
}
