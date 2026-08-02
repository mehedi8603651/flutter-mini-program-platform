part of '../mp_screen_renderer_test.dart';

void _mpMediaPlaybackTests() {
  group('media playback', () {
    test('validator accepts inline video and rejects arbitrary URLs', () {
      const validator = MpScreenValidator();
      expect(
        () => validator.validate(<String, dynamic>{
          'schemaVersion': 1,
          'screenId': 'media',
          'root': <String, dynamic>{
            'type': 'videoView',
            'props': <String, dynamic>{
              'aspectRatio': 16 / 9,
              'autoplay': false,
              'cacheMode': 'streaming',
              'controls': true,
              'fit': 'contain',
              'loop': false,
              'muted': false,
              'playerId': 'demo',
              'semanticLabel': 'Product demo',
              'source': <String, dynamic>{
                'kind': 'asset',
                'asset': 'media/demo.mp4',
              },
              'speed': 1,
              'volume': 1,
            },
            'children': <Object?>[],
          },
        }, expectedScreenId: 'media'),
        returnsNormally,
      );
      expect(
        () => validator.validate(<String, dynamic>{
          'schemaVersion': 1,
          'screenId': 'media',
          'root': <String, dynamic>{
            'type': 'videoView',
            'props': <String, dynamic>{
              'aspectRatio': 1,
              'autoplay': false,
              'cacheMode': 'streaming',
              'controls': true,
              'fit': 'contain',
              'loop': false,
              'muted': false,
              'playerId': 'demo',
              'semanticLabel': 'Demo',
              'source': <String, dynamic>{
                'kind': 'asset',
                'asset': 'https://example.com/demo.mp4',
              },
              'speed': 1,
              'volume': 1,
            },
            'children': <Object?>[],
          },
        }, expectedScreenId: 'media'),
        throwsA(isA<MiniProgramRenderException>()),
      );
    });

    testWidgets('audio action resolves a trusted source and updates status', (
      tester,
    ) async {
      final provider = _TestPlaybackProvider();
      final manager = MiniProgramMediaPlaybackManager(provider);
      final state = MpStateManager();
      final result = await _runMpAction(
        tester,
        Mp.audio
            .play(
              audioId: 'notice',
              source: MpAudioSource.asset('audio/notice.mp3'),
              statusState: 'audio.status',
              errorState: 'audio.error',
            )
            .toJson(),
        miniProgramVersion: '1.0.0',
        stateManager: state,
        mediaPlaybackManager: manager,
        mediaPlaybackPolicy: const MiniProgramMediaPlaybackPolicy(
          audioEnabled: true,
        ),
        mediaAssetSource: const _TestMediaAssetSource(),
      );

      expect(result, isA<HostActionResult>());
      expect((result! as HostActionResult).isSuccess, isTrue);
      expect(state.get('audio.status'), 'success');
      expect(provider.created, 1);
      expect(
        provider.lastRequest?.source.candidateUris.single.toString(),
        'https://assets.example/audio/notice.mp3',
      );
      await manager.dispose();
    });

    testWidgets('host policy denial preserves target state', (tester) async {
      final state = MpStateManager()..set('audio.status', 'old');
      final result = await _runMpAction(
        tester,
        Mp.audio
            .play(
              audioId: 'notice',
              source: MpAudioSource.asset('audio/notice.mp3'),
              statusState: 'audio.runtime',
              errorState: 'audio.error',
            )
            .toJson(),
        stateManager: state,
      );

      expect(
        (result! as HostActionResult).errorCode,
        MiniProgramErrorCodes.mediaNotAccepted,
      );
      expect(state.get('audio.status'), 'old');
      expect(state.get('audio.runtime'), 'error');
    });

    testWidgets('phase two audio and fullscreen controls reach the session', (
      tester,
    ) async {
      final provider = _TestPlaybackProvider();
      final manager = MiniProgramMediaPlaybackManager(provider);
      await manager.load(_testPlaybackRequest(sourceKey: 'audio'));

      final volumeResult = await _runMpAction(
        tester,
        Mp.audio.setVolume(audioId: 'player', volume: 0.35).toJson(),
        miniProgramId: 'media-app',
        mediaPlaybackManager: manager,
        mediaPlaybackPolicy: const MiniProgramMediaPlaybackPolicy(
          audioEnabled: true,
        ),
      );
      final speedResult = await _runMpAction(
        tester,
        Mp.audio.setSpeed(audioId: 'player', speed: 1.5).toJson(),
        miniProgramId: 'media-app',
        mediaPlaybackManager: manager,
        mediaPlaybackPolicy: const MiniProgramMediaPlaybackPolicy(
          audioEnabled: true,
        ),
      );
      expect((volumeResult! as HostActionResult).isSuccess, isTrue);
      expect((speedResult! as HostActionResult).isSuccess, isTrue);
      expect(provider.lastSession?.volume, 0.35);
      expect(provider.lastSession?.speed, 1.5);

      await manager.releaseAllFor('media-app');
      await manager.load(
        _testPlaybackRequest(
          sourceKey: 'video',
          kind: MiniProgramMediaPlaybackKind.video,
        ),
      );
      final fullscreenResult = await _runMpAction(
        tester,
        Mp.video.enterFullscreen(playerId: 'player').toJson(),
        miniProgramId: 'media-app',
        mediaPlaybackManager: manager,
        mediaPlaybackPolicy: const MiniProgramMediaPlaybackPolicy(
          videoEnabled: true,
        ),
      );
      expect((fullscreenResult! as HostActionResult).isSuccess, isTrue);
      expect(provider.lastSession?.fullscreen, isTrue);
      await manager.dispose();
    });

    test(
      'app lifecycle pause affects only sessions owned by that app',
      () async {
        final provider = _TestPlaybackProvider();
        final manager = MiniProgramMediaPlaybackManager(provider);
        await manager.load(_testPlaybackRequest(sourceKey: 'first'));
        final session = provider.lastSession!;
        await session.play();

        await manager.pauseAllFor('other-app');
        expect(session.status, MiniProgramMediaPlaybackStatus.playing);
        await manager.pauseAllFor('media-app');
        expect(session.status, MiniProgramMediaPlaybackStatus.paused);
        await manager.dispose();
      },
    );

    testWidgets('video lifecycle actions run once per status transition', (
      tester,
    ) async {
      final provider = _TestPlaybackProvider();
      final manager = MiniProgramMediaPlaybackManager(provider);
      final state = MpStateManager()..set('events.ended', 0);
      final backendStore = MiniProgramBackendStore();
      final root = Mp.videoView(
        playerId: 'demo',
        source: MpVideoSource.asset('video/demo.mp4'),
        errorState: 'video.error',
        onReady: Mp.state.set('events.ready', true),
        onEnded: Mp.state.increment('events.ended'),
        onError: Mp.state.set('events.error', true),
      ).toJson();
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          mediaPlaybackManager: manager,
          mediaPlaybackPolicy: const MiniProgramMediaPlaybackPolicy(
            videoEnabled: true,
          ),
          mediaAssetSource: const _TestMediaAssetSource(),
          miniProgramVersion: '1.0.0',
          screenJson: <String, dynamic>{
            'schemaVersion': 1,
            'screenId': 'coupon_home',
            'root': root,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(state.get('events.ready'), isTrue);

      provider.lastSession!.status = MiniProgramMediaPlaybackStatus.completed;
      provider.lastSession!.notifyListeners();
      await tester.pumpAndSettle();
      expect(state.get('events.ended'), 1);

      provider.lastSession!.status = MiniProgramMediaPlaybackStatus.error;
      provider.lastSession!.notifyListeners();
      await tester.pumpAndSettle();
      expect(state.get('events.error'), isTrue);
      expect(
        (state.get('video.error')! as Map)['code'],
        MiniProgramErrorCodes.mediaPlaybackFailed,
      );
      provider.lastSession!.notifyListeners();
      await tester.pumpAndSettle();
      expect(state.get('events.ended'), 1);

      await manager.dispose();
      backendStore.dispose();
    });

    test('release invalidates an in-flight player load', () async {
      final provider = _DelayedPlaybackProvider();
      final manager = MiniProgramMediaPlaybackManager(provider);
      final load = manager.load(_testPlaybackRequest(sourceKey: 'first'));
      await provider.started.future;

      expect(await manager.release('media-app', 'player'), isTrue);
      final session = _TestPlaybackSession(
        _testPlaybackRequest(sourceKey: 'first'),
      );
      provider.completer.complete(session);

      await expectLater(
        load,
        throwsA(
          isA<MiniProgramMediaPlaybackException>().having(
            (error) => error.errorCode,
            'errorCode',
            MiniProgramErrorCodes.mediaSourceExpired,
          ),
        ),
      );
      expect(session.disposed, isTrue);
      expect(manager.sessionFor('media-app', 'player'), isNull);
      await manager.dispose();
    });
  });
}

MiniProgramMediaPlaybackRequest _testPlaybackRequest({
  required String sourceKey,
  MiniProgramMediaPlaybackKind kind = MiniProgramMediaPlaybackKind.audio,
}) => MiniProgramMediaPlaybackRequest(
  miniProgramId: 'media-app',
  playerId: 'player',
  kind: kind,
  sourceKey: sourceKey,
  source: MiniProgramResolvedPlaybackSource(
    candidateUris: <Uri>[Uri.parse('https://assets.example/audio.mp3')],
  ),
  cacheMode: MiniProgramMediaCacheMode.streaming,
  autoplay: false,
  loop: false,
  volume: 1,
  speed: 1,
  muted: false,
);

class _TestPlaybackProvider implements MiniProgramMediaPlaybackProvider {
  int created = 0;
  MiniProgramMediaPlaybackRequest? lastRequest;
  _TestPlaybackSession? lastSession;

  @override
  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  ) async {
    created++;
    lastRequest = request;
    return lastSession = _TestPlaybackSession(request);
  }
}

class _TestPlaybackSession extends ChangeNotifier
    implements
        MiniProgramMediaPlaybackSession,
        MiniProgramFullscreenMediaPlaybackSession {
  _TestPlaybackSession(this.request)
    : volume = request.volume,
      speed = request.speed,
      muted = request.muted;

  final MiniProgramMediaPlaybackRequest request;
  var status = MiniProgramMediaPlaybackStatus.ready;
  double volume;
  double speed;
  bool muted;
  bool fullscreen = false;
  bool disposed = false;

  @override
  String get sourceKey => request.sourceKey;

  @override
  MiniProgramMediaPlaybackSnapshot get snapshot =>
      MiniProgramMediaPlaybackSnapshot(
        playerId: request.playerId,
        kind: request.kind,
        status: status,
        volume: volume,
        speed: speed,
        muted: muted,
      );

  @override
  Widget buildVideoView({
    required BoxFit fit,
    required bool controls,
    required String semanticLabel,
  }) => const SizedBox.shrink();

  @override
  Future<void> play() async {
    status = MiniProgramMediaPlaybackStatus.playing;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    status = MiniProgramMediaPlaybackStatus.paused;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {
    status = MiniProgramMediaPlaybackStatus.ready;
    notifyListeners();
  }

  @override
  Future<void> setMuted(bool value) async {
    muted = value;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
    notifyListeners();
  }

  @override
  Future<void> enterFullscreen() async => fullscreen = true;

  @override
  Future<void> exitFullscreen() async => fullscreen = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

class _DelayedPlaybackProvider implements MiniProgramMediaPlaybackProvider {
  final started = Completer<void>();
  final completer = Completer<MiniProgramMediaPlaybackSession>();

  @override
  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  ) {
    started.complete();
    return completer.future;
  }
}

class _TestMediaAssetSource implements MiniProgramMediaAssetSource {
  const _TestMediaAssetSource();

  @override
  MiniProgramResolvedMediaAsset resolveMediaAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) => MiniProgramResolvedMediaAsset(
    candidateUris: <Uri>[Uri.parse('https://assets.example/$assetPath')],
  );
}
