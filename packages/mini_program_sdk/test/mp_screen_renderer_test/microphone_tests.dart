part of '../mp_screen_renderer_test.dart';

void _mpMicrophoneTests() {
  testWidgets('recording requires a gesture, accepted policy and provider', (
    tester,
  ) async {
    final state = MpStateManager()..set('voice', {'previous': true});
    final action = Mp.microphone.record(targetState: 'voice').toJson();
    for (final gesture in [false, true]) {
      final result =
          await _runMpAction(
                tester,
                action,
                stateManager: state,
                userGesture: gesture,
              )
              as HostActionResult;
      expect(
        result.errorCode,
        gesture
            ? MiniProgramErrorCodes.microphoneNotAccepted
            : MiniProgramErrorCodes.microphoneUserGestureRequired,
      );
    }
    final unavailable =
        await _runMpAction(
              tester,
              action,
              stateManager: state,
              userGesture: true,
              microphonePolicy: const MiniProgramMicrophonePolicy(
                enabled: true,
              ),
            )
            as HostActionResult;
    expect(unavailable.errorCode, MiniProgramErrorCodes.microphoneUnavailable);
    expect(state.get('voice'), {'previous': true});
    state.dispose();
  });
  testWidgets(
    'recording writes safe metadata and cancellation preserves previous voice',
    (tester) async {
      final state = MpStateManager();
      final provider = _ResultMicrophoneProvider();
      final media = MiniProgramMediaManager(provider);
      final manager = MiniProgramMicrophoneManager(
        provider,
        mediaManager: media,
      );
      final action = Mp.microphone
          .record(
            targetState: 'voice',
            statusState: 'status',
            errorState: 'error',
            requestId: 'record-1',
          )
          .toJson();
      Future<HostActionResult> run() async =>
          await _runMpAction(
                tester,
                action,
                stateManager: state,
                microphoneManager: manager,
                mediaManager: media,
                microphonePolicy: const MiniProgramMicrophonePolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      final result = await run();
      expect(result.isSuccess, isTrue);
      expect(result.requestId, 'record-1');
      expect(state.get('status'), 'success');
      expect(state.get<Map>('voice')!['mimeType'], 'audio/mp4');
      final previous = state.get('voice');
      provider.cancelled = true;
      expect((await run()).status, HostActionStatus.cancelled);
      expect(state.get('voice'), previous);
      expect(state.get('status'), 'cancelled');
      expect(state.contains('error'), isFalse);
      await manager.dispose();
      await media.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'recording quota failure rolls back and deletes new native audio',
    (tester) async {
      final state = MpStateManager(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 1024,
          maxValueBytes: 100,
        ),
      )..set('voice', {'previous': true});
      final provider = _ResultMicrophoneProvider();
      final media = MiniProgramMediaManager(provider);
      final manager = MiniProgramMicrophoneManager(
        provider,
        mediaManager: media,
      );
      final result =
          await _runMpAction(
                tester,
                Mp.microphone
                    .record(targetState: 'voice', statusState: 'status')
                    .toJson(),
                stateManager: state,
                microphoneManager: manager,
                mediaManager: media,
                microphonePolicy: const MiniProgramMicrophonePolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(result.errorCode, MiniProgramErrorCodes.stateLimitExceeded);
      expect(state.get('voice'), {'previous': true});
      expect(provider.released, ['voice_test']);
      await manager.dispose();
      await media.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'recorded audio playback revalidates ownership, policy and release',
    (tester) async {
      final provider = _TestPlaybackProvider();
      final manager = MiniProgramMediaPlaybackManager(provider);
      final media = MiniProgramMediaManager(_ResultMicrophoneProvider());
      final state = MpStateManager()..set('voice.ref', 'voice_test');
      final action = Mp.audio
          .play(
            audioId: 'voice',
            source: MpAudioSource.hostMedia('{{state.voice.ref}}'),
          )
          .toJson();
      media.register(miniProgramId: 'coupon', mediaRef: 'voice_test');
      Future<HostActionResult> run({
        bool allow = true,
        Map<String, dynamic>? json,
      }) async =>
          await _runMpAction(
                tester,
                json ?? action,
                stateManager: state,
                mediaManager: media,
                mediaPlaybackManager: manager,
                mediaPlaybackPolicy: MiniProgramMediaPlaybackPolicy(
                  audioEnabled: allow,
                ),
              )
              as HostActionResult;
      expect(
        (await run(allow: false)).errorCode,
        MiniProgramErrorCodes.mediaNotAccepted,
      );
      expect(provider.created, 0);
      expect((await run()).isSuccess, isTrue);
      expect(
        provider.lastRequest!.source.candidateUris.single.toString(),
        'miniprogram-media:voice_test',
      );
      expect(
        (await run(
          json: {
            ...action,
            'props': {...action['props'] as Map, 'cacheMode': 'temporary'},
          },
        )).isSuccess,
        isFalse,
      );
      await media.release(miniProgramId: 'coupon', mediaRef: 'voice_test');
      expect((await run()).errorCode, MiniProgramErrorCodes.mediaNotOwned);
      expect(provider.created, 1);
      await manager.dispose();
      await media.dispose();
      state.dispose();
    },
  );
  test(
    'microphone validator rejects unknown properties and invalid durations',
    () {
      for (final props in <Map<String, dynamic>>[
        {'maxDurationSeconds': 0},
        {'maxDurationSeconds': 601},
        {'maxDurationSeconds': 1.5},
        {'targetState': ''},
        {'path': '/audio.m4a'},
        {'mimeType': 'audio/mp3'},
        {'background': true},
        {'sampleRate': 44100},
      ]) {
        expect(
          () => const MpScreenValidator().validate(
            _cacheActionScreen('microphone.record', {
              'targetState': 'voice',
              ...props,
            }),
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
      for (final action in ['microphone.stop', 'microphone.cancel']) {
        expect(
          () => const MpScreenValidator().validate(
            _cacheActionScreen(action, {'nativePath': '/audio'}),
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
      final valid = Mp.audio
          .play(audioId: 'voice', source: MpAudioSource.hostMedia('voice_1'))
          .toJson();
      for (final source in [
        {'kind': 'hostMedia', 'mediaRef': 'content://private/audio'},
        {'kind': 'hostMedia', 'mediaRef': 'voice_1', 'uri': 'file:///audio'},
        {'kind': 'hostMedia', 'mediaRef': 'prefix{{state.voice}}'},
      ]) {
        expect(
          () => const MpScreenValidator().validate(
            _cacheActionScreen('audio.play', {
              ...valid['props'] as Map<String, dynamic>,
              'source': source,
            }),
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
    },
  );
}

class _ResultMicrophoneProvider implements MiniProgramMicrophoneProvider {
  bool cancelled = false;
  final released = <String>[];
  @override
  Future<MiniProgramMicrophoneResult> record(
    MiniProgramMicrophoneRequest request, {
    required VoidCallback onStarted,
  }) async {
    if (cancelled) {
      throw const MiniProgramMicrophoneException(
        errorCode: MiniProgramErrorCodes.microphoneRecordingCancelled,
        message: 'Cancelled.',
      );
    }
    onStarted();
    return MiniProgramMicrophoneResult(
      recordingId: request.recordingId,
      mediaRef: 'voice_test',
      fileName: 'voice_test.m4a',
      bytes: 8000,
      durationMs: 1000,
      stopReason: 'user',
      recordedAtUtc: DateTime.utc(2026),
    );
  }

  @override
  Future<bool> stop(String recordingId, {bool background = false}) async =>
      true;
  @override
  Future<bool> cancel(String recordingId) async => true;
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
