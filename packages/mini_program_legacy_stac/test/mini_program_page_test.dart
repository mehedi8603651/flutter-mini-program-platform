import 'dart:async';

// Compatibility coverage intentionally exercises deprecated launcher APIs.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_legacy_stac/mini_program_legacy_stac.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets(
    'renders a scaffolded loading page while the mini-program loads',
    (tester) async {
      final loadGate = Completer<void>();
      final runtime = MiniProgramRuntime(
        renderers: legacyStacRenderers,
        sdkVersion: '1.0.0',
        source: _DelayedMiniProgramSource(
          loadGate: loadGate,
          manifest: _buildManifest(),
          screenJson: const <String, dynamic>{
            'type': 'scaffold',
            'body': <String, dynamic>{
              'type': 'center',
              'child': <String, dynamic>{
                'type': 'text',
                'data': 'Loaded after cloud fetch',
              },
            },
          },
        ),
        hostBridge: _FakeHostBridge(),
        capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
          CapabilityIds.analytics,
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
      await tester.pump();

      expect(find.text('Profile Center'), findsOneWidget);
      expect(find.text('Loading Profile Center'), findsOneWidget);
      expect(find.byType(SdkLoadingView), findsOneWidget);

      loadGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Loaded after cloud fetch'), findsOneWidget);
      expect(find.text('Loading Profile Center'), findsNothing);
    },
  );

  testWidgets('loads runtime from MiniProgramRuntimeScope', (tester) async {
    final runtime = MiniProgramRuntime(
      renderers: legacyStacRenderers,
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
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.analytics,
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
      renderers: legacyStacRenderers,
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
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );
    final explicitRuntime = MiniProgramRuntime(
      renderers: legacyStacRenderers,
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
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.analytics,
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
      renderers: legacyStacRenderers,
      sdkVersion: '1.0.0',
      source: const _FailingManifestSource(),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.analytics,
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

  testWidgets(
    'openMiniProgram pushes a MiniProgramPage with the scoped runtime',
    (tester) async {
      final runtime = MiniProgramRuntime(
        renderers: legacyStacRenderers,
        sdkVersion: '1.0.0',
        source: _FakeMiniProgramSource(
          manifest: _buildManifest(),
          screenJson: const <String, dynamic>{
            'type': 'scaffold',
            'body': <String, dynamic>{
              'type': 'center',
              'child': <String, dynamic>{
                'type': 'text',
                'data': 'Launcher helper screen',
              },
            },
          },
        ),
        hostBridge: _FakeHostBridge(),
        capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
          CapabilityIds.analytics,
        ]),
        cacheBundle: MiniProgramCacheBundle.inMemory(),
      );

      await tester.pumpWidget(
        MiniProgramRuntimeScope(
          runtime: runtime,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        openMiniProgram<void>(
                          context,
                          miniProgramId: 'profile_center',
                          title: 'Profile Center',
                        );
                      },
                      child: const Text('Launch mini-program'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch mini-program'));
      await tester.pumpAndSettle();

      expect(find.text('Launcher helper screen'), findsOneWidget);
    },
  );

  testWidgets('MiniProgramLauncherButton opens a mini-program by id', (
    tester,
  ) async {
    final runtime = MiniProgramRuntime(
      renderers: legacyStacRenderers,
      sdkVersion: '1.0.0',
      source: _FakeMiniProgramSource(
        manifest: _buildManifest(),
        screenJson: const <String, dynamic>{
          'type': 'scaffold',
          'body': <String, dynamic>{
            'type': 'center',
            'child': <String, dynamic>{
              'type': 'text',
              'data': 'Launcher button screen',
            },
          },
        },
      ),
      hostBridge: _FakeHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
        CapabilityIds.analytics,
      ]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );

    await tester.pumpWidget(
      MiniProgramRuntimeScope(
        runtime: runtime,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MiniProgramLauncherButton(
                miniProgramId: 'profile_center',
                title: 'Profile Center',
                child: Text('Open with launcher button'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open with launcher button'));
    await tester.pumpAndSettle();

    expect(find.text('Launcher button screen'), findsOneWidget);
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

class _DelayedMiniProgramSource implements MiniProgramSource {
  const _DelayedMiniProgramSource({
    required this.loadGate,
    required this.manifest,
    required this.screenJson,
  });

  final Completer<void> loadGate;
  final MiniProgramManifest manifest;
  final Map<String, dynamic> screenJson;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    await loadGate.future;
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
    requiredCapabilities: <CapabilityId>[CapabilityIds.analytics],
  );
}
