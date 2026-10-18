import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mini_program_ui/mini_program_ui.dart';

void main() {
  testWidgets(
    'hiding and showing a mini-program keeps its state and load generation',
    (tester) async {
      final source = _CountingVisibilitySource();
      final runtime = MiniProgramRuntime(
        sdkVersion: '1.0.0',
        source: source,
        hostBridge: const _HostBridge(),
        capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
        cacheBundle: MiniProgramCacheBundle.inMemory(),
      );

      await tester.pumpWidget(
        MaterialApp(home: _VisibilityHarness(runtime: runtime)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counter: 0'), findsOneWidget);
      expect(source.manifestLoads, 1);
      expect(source.screenLoads, 1);

      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Counter: 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('hideMiniProgram')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('showMiniProgram')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1'), findsOneWidget);
      expect(source.manifestLoads, 1);
      expect(source.screenLoads, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      runtime.dispose();
    },
  );

  testWidgets('system Back changes only a foreground mini-program stack', (
    tester,
  ) async {
    final source = _CountingVisibilitySource();
    final runtime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: source,
      hostBridge: const _HostBridge(),
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
      cacheBundle: MiniProgramCacheBundle.inMemory(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PopScope<void>(
          canPop: false,
          child: _VisibilityHarness(runtime: runtime),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Counter: 0'), findsOneWidget);

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Keep this reference');
    await tester.tap(find.byKey(const ValueKey<String>('hideMiniProgram')));
    await tester.pumpAndSettle();
    final screenLoads = source.screenLoads;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('showMiniProgram')));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Keep this reference'), findsOneWidget);
    expect(source.manifestLoads, 1);
    expect(source.screenLoads, screenLoads);

    await tester.pumpWidget(const SizedBox.shrink());
    runtime.dispose();
  });
}

class _VisibilityHarness extends StatefulWidget {
  const _VisibilityHarness({required this.runtime});

  final MiniProgramRuntime runtime;

  @override
  State<_VisibilityHarness> createState() => _VisibilityHarnessState();
}

class _VisibilityHarnessState extends State<_VisibilityHarness> {
  var _visibility = MiniProgramVisibility.foreground;

  @override
  Widget build(BuildContext context) {
    final isForeground = _visibility == MiniProgramVisibility.foreground;
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            key: const ValueKey<String>('hideMiniProgram'),
            onPressed: isForeground
                ? () =>
                      setState(() => _visibility = MiniProgramVisibility.hidden)
                : null,
            child: const Text('Hide'),
          ),
          TextButton(
            key: const ValueKey<String>('showMiniProgram'),
            onPressed: isForeground
                ? null
                : () => setState(
                    () => _visibility = MiniProgramVisibility.foreground,
                  ),
            child: const Text('Show'),
          ),
          Expanded(
            child: MiniProgramPage(
              miniProgramId: 'visibility_test',
              runtime: widget.runtime,
              visibility: _visibility,
              showAppBar: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountingVisibilitySource implements MiniProgramSource {
  int manifestLoads = 0;
  int screenLoads = 0;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    manifestLoads += 1;
    return const MiniProgramManifest(
      id: 'visibility_test',
      version: '1.0.0',
      entry: 'visibility_home',
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
    screenLoads += 1;
    final json = MpProgram(
      screens: <String, MpScreenBuilder>{
        'visibility_home': () => Mp.initialize(
          actions: <MpAction>[Mp.state.set('counter', 0)],
          child: Mp.stateBuilder(
            keys: const <String>['counter'],
            child: Mp.column(
              children: <MpNode>[
                Mp.text('Counter: {{state.counter}}'),
                Mp.primaryButton(
                  label: 'Increment',
                  action: Mp.state.increment('counter'),
                ),
                Mp.primaryButton(
                  label: 'Open details',
                  action: Mp.navigation.openScreen('visibility_details'),
                ),
              ],
            ),
          ),
        ),
        'visibility_details': () => Mp.form(
          id: 'reference',
          children: <MpNode>[
            Mp.text('Details'),
            Mp.textInput(name: 'reference', label: 'Reference'),
          ],
        ),
      },
    ).buildScreensJson()[screenId]!;
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map);
  }
}

class _HostBridge implements HostBridge {
  const _HostBridge();

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return HostActionResult.success(actionName: ActionNames.trackEvent);
  }
}
