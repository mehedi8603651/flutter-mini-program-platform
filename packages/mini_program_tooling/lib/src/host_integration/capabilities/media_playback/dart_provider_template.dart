const String androidMediaPlaybackProviderSource = r'''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:video_player/video_player.dart';

/// Host-owned Android adapter for streamed audio and inline video playback.
///
/// The SDK resolves trusted artifact or Publisher API URLs before this
/// provider receives them. Native paths and source URLs are never written to
/// mini-program state.
class AppAndroidMediaPlaybackProvider
    implements MiniProgramMediaPlaybackProvider {
  const AppAndroidMediaPlaybackProvider();

  @override
  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  ) async {
    Object? lastError;
    for (final uri in request.source.candidateUris) {
      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.networkUrl(
          uri,
          httpHeaders: request.source.headers,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers:
                request.kind == MiniProgramMediaPlaybackKind.audio,
          ),
        );
        await controller.initialize().timeout(request.source.timeout);
        final session = _AppMediaPlaybackSession(
          controller: controller,
          request: request,
        );
        await session.configure();
        return session;
      } catch (error) {
        lastError = error;
        await controller?.dispose();
      }
    }
    throw MiniProgramMediaPlaybackException(
      errorCode: MiniProgramErrorCodes.mediaLoadFailed,
      message: 'Android could not load the media stream.',
      details: <String, Object?>{
        if (lastError != null) 'cause': lastError.runtimeType.toString(),
      },
    );
  }
}

class _AppMediaPlaybackSession extends ChangeNotifier
    implements MiniProgramMediaPlaybackSession {
  _AppMediaPlaybackSession({
    required VideoPlayerController controller,
    required this.request,
  }) : _controller = controller,
       _volume = request.volume,
       _muted = request.muted {
    _controller.addListener(_handleControllerChanged);
  }

  final VideoPlayerController _controller;
  final MiniProgramMediaPlaybackRequest request;
  double _volume;
  bool _muted;
  bool _disposed = false;

  Future<void> configure() async {
    await _controller.setLooping(request.loop);
    await _controller.setPlaybackSpeed(request.speed);
    await _controller.setVolume(_muted ? 0 : _volume);
    if (request.autoplay) await _controller.play();
  }

  @override
  String get sourceKey => request.sourceKey;

  @override
  MiniProgramMediaPlaybackSnapshot get snapshot {
    final value = _controller.value;
    final duration = value.duration;
    final position = value.position > duration && duration > Duration.zero
        ? duration
        : value.position;
    final buffered = value.buffered.isEmpty
        ? Duration.zero
        : value.buffered.last.end;
    final completed = duration > Duration.zero &&
        position >= duration &&
        !value.isPlaying;
    final status = value.hasError
        ? MiniProgramMediaPlaybackStatus.error
        : value.isBuffering
        ? MiniProgramMediaPlaybackStatus.buffering
        : value.isPlaying
        ? MiniProgramMediaPlaybackStatus.playing
        : completed
        ? MiniProgramMediaPlaybackStatus.completed
        : position > Duration.zero
        ? MiniProgramMediaPlaybackStatus.paused
        : MiniProgramMediaPlaybackStatus.ready;
    return MiniProgramMediaPlaybackSnapshot(
      playerId: request.playerId,
      kind: request.kind,
      status: status,
      position: position,
      duration: duration,
      buffered: buffered,
      volume: _volume,
      speed: value.playbackSpeed,
      muted: _muted,
    );
  }

  @override
  Widget buildVideoView({
    required BoxFit fit,
    required bool controls,
    required String semanticLabel,
  }) {
    if (request.kind != MiniProgramMediaPlaybackKind.video) {
      return const SizedBox.shrink();
    }
    return _AppInlineVideoView(
      session: this,
      fit: fit,
      controls: controls,
      semanticLabel: semanticLabel,
    );
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seek(Duration position) async {
    final duration = _controller.value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : duration > Duration.zero && position > duration
        ? duration
        : position;
    await _controller.seekTo(target);
  }

  @override
  Future<void> stop() async {
    await _controller.pause();
    await _controller.seekTo(Duration.zero);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _controller.setVolume(muted ? 0 : _volume);
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 1).toDouble();
    await _controller.setVolume(_muted ? 0 : _volume);
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double speed) =>
      _controller.setPlaybackSpeed(speed.clamp(0.25, 3).toDouble());

  void _handleControllerChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_handleControllerChanged);
    await _controller.dispose();
    super.dispose();
  }
}

class _AppInlineVideoView extends StatelessWidget {
  const _AppInlineVideoView({
    required this.session,
    required this.fit,
    required this.controls,
    required this.semanticLabel,
  });

  final _AppMediaPlaybackSession session;
  final BoxFit fit;
  final bool controls;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final controller = session._controller;
        final value = controller.value;
        final size = value.size.isEmpty ? const Size(16, 9) : value.size;
        return Semantics(
          label: semanticLabel,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ClipRect(
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              if (controls)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          color: Colors.white,
                          onPressed: value.isPlaying
                              ? session.pause
                              : session.play,
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        IconButton(
                          tooltip: session._muted ? 'Unmute' : 'Mute',
                          color: Colors.white,
                          onPressed: () => session.setMuted(!session._muted),
                          icon: Icon(
                            session._muted
                                ? Icons.volume_off
                                : Icons.volume_up,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
''';
