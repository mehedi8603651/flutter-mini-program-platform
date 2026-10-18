import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mini_program_ui/mini_program_ui.dart';

void main() {
  late _Provider provider;
  late MiniProgramMediaManager media;
  late MiniProgramMicrophoneManager manager;
  const allowed = MiniProgramMicrophonePolicy(
    enabled: true,
    maxDurationSeconds: 5,
  );
  setUp(() {
    provider = _Provider();
    media = MiniProgramMediaManager(provider);
    manager = MiniProgramMicrophoneManager(provider, mediaManager: media);
  });
  tearDown(() async {
    await manager.dispose();
    await media.dispose();
  });

  for (final hideSurface in [false, true]) {
    testWidgets(
      'recording ignores permission inactivity and finalizes on ${hideSurface ? 'hidden surface' : 'background'}',
      (tester) async {
        provider = _Provider()..completeOnStop = true;
        final source = _Source();
        final runtime = MiniProgramRuntime(
          sdkVersion: '1.0.0',
          source: source,
          hostBridge: _Bridge(),
          capabilityRegistry: CapabilityRegistry(const []),
          cacheBundle: MiniProgramCacheBundle.inMemory(),
          microphoneProvider: provider,
        );
        Future<void> show(MiniProgramVisibility visibility) =>
            tester.pumpWidget(
              MaterialApp(
                home: MiniProgramPage(
                  miniProgramId: 'voice',
                  runtime: runtime,
                  visibility: visibility,
                  showAppBar: false,
                ),
              ),
            );
        await show(MiniProgramVisibility.foreground);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record'));
        await tester.pump();
        provider.onStarted!();
        await tester.pump();
        expect(find.text('Status: recording'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(provider.stopCalls, 0);
        if (hideSurface) {
          await show(MiniProgramVisibility.hidden);
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        await tester.pumpAndSettle();
        expect(provider.background, isTrue);
        expect(provider.stopCalls, greaterThan(0));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await show(MiniProgramVisibility.foreground);
        await tester.pumpAndSettle();
        expect(
          find.text('Status: success'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((e) => e.data)
              .join(' | '),
        );
        expect(source.loads, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        runtime.dispose();
      },
    );
  }

  test(
    'endpoint policies default deny and are scoped to the requested app',
    () {
      final source = EndpointRoutingMiniProgramSource(
        deliveryContext: const MiniProgramDeliveryContext(
          hostApp: 'host',
          sdkVersion: '1.0.0',
          hostVersion: '1.0.0',
          capabilities: {},
          platform: 'android',
          locale: 'en-US',
        ),
        endpoints: {
          'a': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://example.com/a/'),
            microphonePolicy: allowed,
          ),
          'b': MiniProgramEndpoint.public(
            apiBaseUri: Uri.parse('https://example.com/b/'),
          ),
        },
      );
      expect(source.microphonePolicyFor('a'), allowed);
      expect(source.microphonePolicyFor('b').enabled, isFalse);
      expect(
        () => source.microphonePolicyFor('unknown'),
        throwsA(isA<MiniProgramSourceException>()),
      );
      source.dispose();
    },
  );
  test(
    'disabled policy and invalid limits fail before invoking capture',
    () async {
      await expectLater(
        manager.record(
          miniProgramId: 'a',
          policy: const MiniProgramMicrophonePolicy(),
        ),
        throwsA(_error(MiniProgramErrorCodes.microphoneNotAccepted)),
      );
      for (final policy in [
        const MiniProgramMicrophonePolicy(enabled: true, maxDurationSeconds: 0),
        const MiniProgramMicrophonePolicy(enabled: true, maxBytes: 104857601),
      ]) {
        await expectLater(
          manager.record(miniProgramId: 'a', policy: policy),
          throwsA(_error(MiniProgramErrorCodes.microphoneInvalidRequest)),
        );
      }
      expect(provider.request, isNull);
    },
  );
  test(
    'clamps duration, sends started once and stop finalizes app-owned audio',
    () async {
      var started = 0;
      final future = manager.record(
        miniProgramId: 'a',
        policy: allowed,
        maxDurationSeconds: 60,
        onStarted: () => started++,
      );
      expect(provider.request!.maxDurationSeconds, 5);
      provider.onStarted!();
      provider.onStarted!();
      expect(started, 1);
      expect(await manager.stopFor('b'), isFalse);
      expect(await manager.stopFor('a', background: true), isTrue);
      expect(provider.background, isTrue);
      provider.complete(reason: 'background');
      final result = await future;
      expect(media.owns('a', result.mediaRef), isTrue);
      expect(media.owns('b', result.mediaRef), isFalse);
      await manager.releaseRecording('b', result);
      expect(provider.released, isEmpty);
      await manager.releaseRecording('a', result);
      expect(provider.released, ['voice_1']);
    },
  );
  test('one operation at a time; cancellation disposes late audio', () async {
    final future = manager.record(miniProgramId: 'a', policy: allowed);
    await expectLater(
      manager.record(miniProgramId: 'b', policy: allowed),
      throwsA(_error(MiniProgramErrorCodes.microphoneRequestInProgress)),
    );
    expect(await manager.cancelFor('b'), isFalse);
    expect(await manager.cancelFor('a'), isTrue);
    final check = expectLater(
      future,
      throwsA(_error(MiniProgramErrorCodes.microphoneRecordingCancelled)),
    );
    provider.complete();
    await check;
    expect(media.isRegistered('voice_1'), isFalse);
    expect(provider.released, ['voice_1']);
  });
  test(
    'disposal cleans late results and suppresses stale started callbacks',
    () async {
      var started = false;
      final future = manager.record(
        miniProgramId: 'a',
        policy: allowed,
        onStarted: () => started = true,
      );
      await manager.dispose();
      provider.onStarted!();
      final check = expectLater(
        future,
        throwsA(_error(MiniProgramErrorCodes.microphoneRecordingCancelled)),
      );
      provider.complete();
      await check;
      expect(started, isFalse);
      expect(provider.released, ['voice_1']);
    },
  );
  test(
    'started callback failure cancels and preserves the original exception',
    () async {
      final future = manager.record(
        miniProgramId: 'a',
        policy: allowed,
        onStarted: () => throw StateError('status quota'),
      );
      provider.onStarted!();
      final check = expectLater(future, throwsStateError);
      provider.complete();
      await check;
      expect(provider.cancelled, isTrue);
      expect(provider.released, ['voice_1']);
    },
  );
  test('over-limit result is released without registering it', () async {
    final future = manager.record(miniProgramId: 'a', policy: allowed);
    final check = expectLater(
      future,
      throwsA(_error(MiniProgramErrorCodes.microphoneLimitExceeded)),
    );
    provider.complete(durationMs: 6001);
    await check;
    expect(media.isRegistered('voice_1'), isFalse);
    expect(provider.released, ['voice_1']);
  });
  test(
    'wrong identity releases new output and duplicate refs preserve earlier ownership',
    () async {
      final future = manager.record(miniProgramId: 'a', policy: allowed);
      final check = expectLater(
        future,
        throwsA(_error(MiniProgramErrorCodes.microphoneInvalidResult)),
      );
      provider.complete(id: 'different');
      await check;
      expect(provider.released, ['voice_1']);
      provider = _Provider();
      await manager.dispose();
      manager = MiniProgramMicrophoneManager(provider, mediaManager: media);
      media.register(miniProgramId: 'other', mediaRef: 'voice_1');
      final duplicate = manager.record(miniProgramId: 'a', policy: allowed);
      final duplicateCheck = expectLater(
        duplicate,
        throwsA(_error(MiniProgramErrorCodes.microphoneInvalidResult)),
      );
      provider.complete();
      await duplicateCheck;
      expect(provider.released, isEmpty);
      expect(media.owns('other', 'voice_1'), isTrue);
    },
  );
}

Matcher _error(String code) => isA<MiniProgramMicrophoneException>().having(
  (e) => e.errorCode,
  'code',
  code,
);

class _Provider implements MiniProgramMicrophoneProvider {
  final completer = Completer<MiniProgramMicrophoneResult>();
  MiniProgramMicrophoneRequest? request;
  VoidCallback? onStarted;
  bool background = false, cancelled = false;
  bool completeOnStop = false;
  int stopCalls = 0;
  final released = <String>[];
  void complete({String? id, int durationMs = 1000, String reason = 'user'}) =>
      completer.complete(
        MiniProgramMicrophoneResult(
          recordingId: id ?? request!.recordingId,
          mediaRef: 'voice_1',
          fileName: 'voice_1.m4a',
          bytes: 8000,
          durationMs: durationMs,
          stopReason: reason,
          recordedAtUtc: DateTime.utc(2026),
        ),
      );
  @override
  Future<MiniProgramMicrophoneResult> record(
    MiniProgramMicrophoneRequest request, {
    required VoidCallback onStarted,
  }) {
    this.request = request;
    this.onStarted = onStarted;
    return completer.future;
  }

  @override
  Future<bool> stop(String recordingId, {bool background = false}) async {
    this.background = background;
    stopCalls++;
    if (completeOnStop && !completer.isCompleted) {
      complete(reason: background ? 'background' : 'user');
    }
    return recordingId == request?.recordingId;
  }

  @override
  Future<bool> cancel(String recordingId) async {
    cancelled = true;
    return true;
  }

  @override
  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request) async {
    released.add(request.mediaRef);
    return true;
  }

  @override
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  ) => throw UnsupportedError('Audio');
}

class _Source
    implements MiniProgramSource, MiniProgramMicrophonePolicyProvider {
  int loads = 0;
  @override
  MiniProgramMicrophonePolicy microphonePolicyFor(String miniProgramId) =>
      const MiniProgramMicrophonePolicy(enabled: true);
  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    loads++;
    return const MiniProgramManifest(
      id: 'voice',
      version: '1.0.0',
      entry: 'home',
      contractVersion: '1.0.0',
      sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
      requiredCapabilities: [],
      screenFormat: MiniProgramScreenFormats.mp,
      screenSchemaVersion: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async => MpProgram(
    screens: {
      'home': () => Mp.stateBuilder(
        keys: ['status'],
        child: Mp.column(
          children: [
            Mp.text('Status: {{state.status}}'),
            Mp.primaryButton(
              label: 'Record',
              action: Mp.microphone.record(
                targetState: 'voice',
                statusState: 'status',
              ),
            ),
          ],
        ),
      ),
    },
  ).buildScreensJson()['home']!;
}

class _Bridge implements HostBridge {
  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => HostActionResult.success(actionName: 'callSecureApi');
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => HostActionResult.success(actionName: 'openNativeScreen');
  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success(actionName: 'trackEvent');
}
