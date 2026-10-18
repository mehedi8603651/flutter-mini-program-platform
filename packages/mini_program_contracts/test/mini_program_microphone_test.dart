import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  final result = MiniProgramMicrophoneResult(
    recordingId: 'recording_1',
    mediaRef: 'voice_1',
    fileName: 'voice_1.m4a',
    bytes: 8000,
    durationMs: 1000,
    stopReason: 'user',
    recordedAtUtc: DateTime.utc(2026, 10, 18),
  );
  test('recording metadata round trips and strips native-only fields', () {
    final json = result.toJson();
    expect(
      MiniProgramMicrophoneResult.fromJson({
        ...json,
        'uri': 'content://private/audio',
        'path': '/private/audio',
      }).toJson(),
      json,
    );
    expect(json['mimeType'], 'audio/mp4');
    expect(json['codec'], 'aac');
    expect(json.keys, isNot(contains('uri')));
    for (final reason in ['user', 'durationLimit', 'sizeLimit', 'background']) {
      expect(
        MiniProgramMicrophoneResult.fromJson({
          ...json,
          'stopReason': reason,
        }).stopReason,
        reason,
      );
    }
  });
  test('recording rejects unsafe metadata, formats and limits', () {
    for (final patch in <Map<String, dynamic>>[
      {'recordingId': ''},
      {'mediaRef': 'content://recordings/1'},
      {'fileName': '../voice.m4a'},
      {'fileName': 'voice.mp3'},
      {'bytes': 0},
      {'bytes': 104857601},
      {'bytes': 1.5},
      {'durationMs': 0},
      {'durationMs': 601001},
      {'stopReason': 'unknown'},
      {'mimeType': 'audio/mpeg'},
      {'codec': 'mp3'},
      {'sampleRate': 44100},
      {'channels': 2},
      {'recordedAtUtc': '2026-01-01'},
      {'recordedAtUtc': 'invalid'},
    ]) {
      expect(
        () => MiniProgramMicrophoneResult.fromJson({
          ...result.toJson(),
          ...patch,
        }),
        throwsFormatException,
        reason: '$patch',
      );
    }
  });
}
