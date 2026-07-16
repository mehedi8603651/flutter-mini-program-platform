import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mini_program_ui/mini_program_ui.dart';

void main() {
  testWidgets(
    'controlled search keeps its controller across unrelated state rebuilds',
    (tester) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager()..set('view.tick', 0);
      final cacheManager = MiniProgramCacheManager.inMemory();
      final screenJson = _screen(
        Mp.stateBuilder(
          keys: const <String>['view.tick'],
          child: Mp.searchField(stateKey: 'search.query', hint: 'Search'),
        ),
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();

      final before = tester.widget<EditableText>(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Dhaka');
      await tester.pump();

      stateManager.set('view.tick', 1);
      await tester.pump();

      final after = tester.widget<EditableText>(find.byType(EditableText));
      expect(identical(after.controller, before.controller), isTrue);
      expect(after.controller.text, 'Dhaka');
      expect(stateManager.get<String>('search.query'), 'Dhaka');

      await _disposeRuntime(tester, stateManager, backendStore);
    },
  );

  testWidgets(
    'countdown continues across unrelated rebuilds and completes once',
    (tester) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager()..set('view.tick', 0);
      final cacheManager = MiniProgramCacheManager.inMemory();
      final screenJson = _screen(
        Mp.stateBuilder(
          keys: const <String>['view.tick'],
          child: Mp.timer.countdown(
            duration: const Duration(seconds: 2),
            remainingState: 'timer.remaining',
            onComplete: Mp.state.increment('timer.completions'),
            child: Mp.text('Remaining: {{state.timer.remaining}}'),
          ),
        ),
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(stateManager.get<int>('timer.remaining'), 1);

      stateManager.set('view.tick', 1);
      await tester.pump();
      expect(stateManager.get<int>('timer.remaining'), 1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(stateManager.get<int>('timer.remaining'), 0);
      expect(stateManager.get<num>('timer.completions'), 1);

      stateManager.set('view.tick', 2);
      await tester.pump(const Duration(seconds: 2));
      expect(stateManager.get<num>('timer.completions'), 1);

      await _disposeRuntime(tester, stateManager, backendStore);
    },
  );

  testWidgets('form state is retained until the form identity changes', (
    tester,
  ) async {
    final backendStore = MiniProgramBackendStore();
    final stateManager = MpStateManager();
    final cacheManager = MiniProgramCacheManager.inMemory();

    await tester.pumpWidget(
      _scopedApp(
        backendStore: backendStore,
        cacheManager: cacheManager,
        stateManager: stateManager,
        screenJson: _formScreen('profile_a'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.pumpWidget(
      _scopedApp(
        backendStore: backendStore,
        cacheManager: cacheManager,
        stateManager: stateManager,
        screenJson: _formScreen('profile_a'),
      ),
    );
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.pumpWidget(
      _scopedApp(
        backendStore: backendStore,
        cacheManager: cacheManager,
        stateManager: stateManager,
        screenJson: _formScreen('profile_b'),
      ),
    );
    await tester.pump();
    expect(find.text('This field is required.'), findsNothing);

    await _disposeRuntime(tester, stateManager, backendStore);
  });

  testWidgets('backend builder does not duplicate an unchanged query', (
    tester,
  ) async {
    final connector = _RecordingConnector(
      MiniProgramBackendResult.success(
        endpoint: '/phase3/backend',
        data: const <String, dynamic>{'title': 'Backend ready'},
      ),
    );
    final backendStore = MiniProgramBackendStore();
    final stateManager = MpStateManager()..set('view.tick', 0);
    final cacheManager = MiniProgramCacheManager.inMemory();
    final screenJson = _screen(
      Mp.stateBuilder(
        keys: const <String>['view.tick'],
        child: Mp.backendBuilder(
          requestId: 'phase3_backend',
          endpoint: '/phase3/backend',
          loading: Mp.text('Loading backend'),
          child: Mp.text('{{backend.phase3_backend.data.title}}'),
        ),
      ),
    );

    await tester.pumpWidget(
      _scopedApp(
        backendStore: backendStore,
        backendConnector: connector,
        cacheManager: cacheManager,
        stateManager: stateManager,
        screenJson: screenJson,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Backend ready'), findsOneWidget);
    expect(connector.calls, hasLength(1));

    stateManager.set('view.tick', 1);
    await tester.pumpAndSettle();
    expect(find.text('Backend ready'), findsOneWidget);
    expect(connector.calls, hasLength(1));

    await _disposeRuntime(tester, stateManager, backendStore);
  });

  testWidgets('lazy section does not duplicate work for one runtime key', (
    tester,
  ) async {
    final connector = _RecordingConnector(
      MiniProgramBackendResult.success(
        endpoint: '/phase3/lazy',
        data: const <String, dynamic>{'title': 'Lazy ready'},
      ),
    );
    final backendStore = MiniProgramBackendStore();
    final stateManager = MpStateManager()..set('view.tick', 0);
    final cacheManager = MiniProgramCacheManager.inMemory();
    final screenJson = _screen(
      Mp.stateBuilder(
        keys: const <String>['view.tick'],
        child: Mp.lazy.section(
          id: 'phase3_lazy_identity',
          once: false,
          targetState: 'lazy.result',
          actions: <MpAction>[Mp.backend.call(endpoint: '/phase3/lazy')],
          child: Mp.text('{{state.lazy.result.title}}'),
        ),
      ),
    );

    await tester.pumpWidget(
      _scopedApp(
        backendStore: backendStore,
        backendConnector: connector,
        cacheManager: cacheManager,
        stateManager: stateManager,
        screenJson: screenJson,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lazy ready'), findsOneWidget);
    expect(connector.calls, hasLength(1));

    stateManager.set('view.tick', 1);
    await tester.pumpAndSettle();
    expect(find.text('Lazy ready'), findsOneWidget);
    expect(connector.calls, hasLength(1));

    await _disposeRuntime(tester, stateManager, backendStore);
  });
}

const MiniProgramManifest _manifest = MiniProgramManifest(
  id: 'phase3',
  version: '1.0.0',
  entry: 'home',
  contractVersion: '1.0.0',
  sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
  requiredCapabilities: <CapabilityId>[],
  screenFormat: MiniProgramScreenFormats.mp,
  screenSchemaVersion: 1,
);

Map<String, dynamic> _screen(MpNode root) {
  final json = MpProgram(
    screens: <String, MpScreenBuilder>{'home': () => root},
  ).buildScreensJson()['home']!;
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map);
}

Map<String, dynamic> _formScreen(String id) {
  return _screen(
    Mp.form(
      id: id,
      children: <MpNode>[
        Mp.textInput(name: 'name', label: 'Name', required: true),
        Mp.formSubmit(label: 'Submit', endpoint: '/phase3/form'),
      ],
    ),
  );
}

Widget _scopedApp({
  required MiniProgramBackendStore backendStore,
  required MiniProgramCacheManager cacheManager,
  required MpStateManager stateManager,
  required Map<String, dynamic> screenJson,
  MiniProgramBackendConnector? backendConnector,
}) {
  return MaterialApp(
    home: MiniProgramSdkScope(
      miniProgramId: 'phase3',
      hostBridge: const _NoopHostBridge(),
      capabilityRegistry: CapabilityRegistry(const <CapabilityId>[]),
      backendConnector: backendConnector,
      cacheManager: cacheManager,
      cachePolicy: const MiniProgramCachePolicy(),
      backendStore: backendStore,
      stateManager: stateManager,
      featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
      logger: const DebugPrintSdkLogger(),
      openMiniProgramScreen: (_, _) async => _success('router.open'),
      resetMiniProgramStack: (_, _) async => _success('router.reset'),
      replaceMiniProgramScreen: (_, _) async => _success('router.replace'),
      popMiniProgramScreen: (_, _) async => _success('router.pop'),
      popToMiniProgramRoot: (_, _) async => _success('router.popToRoot'),
      popToMiniProgramScreen: (_, _) async => _success('router.popTo'),
      child: Builder(
        builder: (context) => const MpScreenRenderer().render(
          MiniProgramRenderRequest(
            context: context,
            manifest: _manifest,
            screenId: 'home',
            screenJson: screenJson,
            logger: DebugPrintSdkLogger(),
          ),
        ),
      ),
    ),
  );
}

Future<void> _disposeRuntime(
  WidgetTester tester,
  MpStateManager stateManager,
  MiniProgramBackendStore backendStore,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  stateManager.dispose();
  backendStore.dispose();
}

HostActionResult _success(String actionName) {
  return HostActionResult.success(actionName: actionName);
}

class _RecordingConnector implements MiniProgramBackendConnector {
  _RecordingConnector(this.response);

  final MiniProgramBackendResult response;
  final List<MiniProgramBackendRequest> calls = <MiniProgramBackendRequest>[];

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    calls.add(request);
    return response;
  }
}

class _NoopHostBridge implements HostBridge {
  const _NoopHostBridge();

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return _success(ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return _success(ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return _success(ActionNames.trackEvent);
  }
}
