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
  });
}
