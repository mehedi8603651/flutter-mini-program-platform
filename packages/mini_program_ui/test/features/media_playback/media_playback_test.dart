import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('audio play serializes a trusted publisher source', () {
    expect(
      Mp.audio
          .play(
            audioId: 'success-sound',
            source: MpAudioSource.publisher(
              endpoint: 'media/audio',
              parameters: const <String, Object?>{'id': 'correct'},
            ),
            volume: 0.8,
            loop: true,
            cacheMode: 'temporary',
            statusState: 'audio.status',
          )
          .toJson(),
      <String, Object?>{
        'type': 'audio.play',
        'props': <String, Object?>{
          'playerId': 'success-sound',
          'source': <String, Object?>{
            'kind': 'publisher',
            'endpoint': 'media/audio',
            'parameters': <String, Object?>{'id': 'correct'},
          },
          'cacheMode': 'temporary',
          'loop': true,
          'volume': 0.8,
          'statusState': 'audio.status',
        },
      },
    );
  });

  test('video view serializes an artifact source and controls', () {
    expect(
      Mp.videoView(
        playerId: 'product-demo',
        source: MpVideoSource.asset('video/product.mp4'),
        autoplay: true,
        muted: true,
        statusState: 'video.status',
      ).toJson(),
      <String, Object?>{
        'type': 'videoView',
        'props': <String, Object?>{
          'aspectRatio': 16 / 9,
          'autoplay': true,
          'cacheMode': 'streaming',
          'controls': true,
          'fit': 'contain',
          'loop': false,
          'muted': true,
          'playerId': 'product-demo',
          'semanticLabel': 'Video player',
          'source': <String, Object?>{
            'kind': 'asset',
            'asset': 'video/product.mp4',
          },
          'speed': 1.0,
          'volume': 1.0,
          'statusState': 'video.status',
        },
        'children': <Object?>[],
      },
    );
  });

  test('phase two controls and video lifecycle actions serialize', () {
    expect(
      Mp.audio.setVolume(audioId: 'lesson', volume: 0.4).toJson(),
      <String, Object?>{
        'type': 'audio.setVolume',
        'props': <String, Object?>{'playerId': 'lesson', 'volume': 0.4},
      },
    );
    expect(
      Mp.audio.setSpeed(audioId: 'lesson', speed: 1.25).toJson(),
      <String, Object?>{
        'type': 'audio.setSpeed',
        'props': <String, Object?>{'playerId': 'lesson', 'speed': 1.25},
      },
    );
    expect(
      Mp.video.enterFullscreen(playerId: 'demo').toJson()['type'],
      'video.enterFullscreen',
    );
    expect(
      Mp.video.exitFullscreen(playerId: 'demo').toJson()['type'],
      'video.exitFullscreen',
    );
    final node = Mp.videoView(
      playerId: 'demo',
      source: MpVideoSource.asset('video/demo.mp4'),
      onReady: Mp.state.set('events.ready', true),
      onEnded: Mp.state.increment('events.ended'),
      onError: Mp.state.set('events.error', true),
    ).toJson();
    final props = Map<String, Object?>.from(node['props']! as Map);
    expect((props['onReady']! as Map)['type'], 'state.set');
    expect((props['onEnded']! as Map)['type'], 'state.increment');
    expect((props['onError']! as Map)['type'], 'state.set');
  });

  test('media playback rejects arbitrary URLs and unsafe controls', () {
    expect(
      () => MpVideoSource.asset('https://example.com/video.mp4'),
      throwsArgumentError,
    );
    expect(
      () => MpAudioSource.publisher(endpoint: '../secret'),
      throwsArgumentError,
    );
    expect(
      () => Mp.video.setSpeed(playerId: 'demo', speed: 4),
      throwsArgumentError,
    );
    expect(
      () => Mp.audio.setVolume(audioId: 'demo', volume: -0.1),
      throwsArgumentError,
    );
    expect(
      () => Mp.audio.setSpeed(audioId: 'demo', speed: 3.1),
      throwsArgumentError,
    );
  });
}
