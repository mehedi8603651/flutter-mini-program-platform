import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('microphone actions emit deterministic bounded JSON', () {
    expect(
      Mp.microphone
          .record(
            targetState: 'voice.note',
            statusState: 'voice.status',
            errorState: 'voice.error',
            requestId: 'rec-1',
          )
          .toJson(),
      {
        'type': 'microphone.record',
        'props': {
          'maxDurationSeconds': 60,
          'targetState': 'voice.note',
          'statusState': 'voice.status',
          'errorState': 'voice.error',
          'requestId': 'rec-1',
        },
      },
    );
    for (final action in [Mp.microphone.stop(), Mp.microphone.cancel()]) {
      expect(action.toJson()['props'], isEmpty);
    }
    expect(Mp.microphone.stop().type, 'microphone.stop');
    expect(Mp.microphone.cancel().type, 'microphone.cancel');
  });
  test('microphone authoring rejects invalid duration and state', () {
    for (final seconds in [0, 601]) {
      expect(
        () => Mp.microphone.record(
          targetState: 'voice',
          maxDurationSeconds: seconds,
        ),
        throwsArgumentError,
      );
    }
    expect(() => Mp.microphone.record(targetState: ''), throwsArgumentError);
    expect(
      () => Mp.microphone.record(targetState: 'voice', statusState: ''),
      throwsArgumentError,
    );
  });
  test(
    'owned audio sources accept opaque references and full bindings only',
    () {
      expect(
        MpAudioSource.hostMedia('{{state.voice.note.mediaRef}}').toJson(),
        {'kind': 'hostMedia', 'mediaRef': '{{state.voice.note.mediaRef}}'},
      );
      expect(
        MpAudioSource.hostMedia('voice_1').toJson()['mediaRef'],
        'voice_1',
      );
      for (final ref in [
        '',
        'content://private/audio',
        '/audio.m4a',
        'prefix{{state.voice}}',
        'https://audio.example',
      ]) {
        expect(() => MpAudioSource.hostMedia(ref), throwsArgumentError);
      }
    },
  );
}
