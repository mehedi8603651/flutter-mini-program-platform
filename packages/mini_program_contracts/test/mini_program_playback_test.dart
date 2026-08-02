import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('media playback identifiers remain stable', () {
    expect(ActionNames.audioPlay, 'audio.play');
    expect(ActionNames.audioPreload, 'audio.preload');
    expect(ActionNames.audioRelease, 'audio.release');
    expect(ActionNames.videoPlay, 'video.play');
    expect(ActionNames.videoSetMuted, 'video.setMuted');
    expect(ActionNames.videoRelease, 'video.release');
    expect(CapabilityIds.mediaAudio, 'media.audio');
    expect(CapabilityIds.mediaVideo, 'media.video');
    expect(CapabilityIds.standardValues, contains(CapabilityIds.mediaAudio));
    expect(CapabilityIds.standardValues, contains(CapabilityIds.mediaVideo));
  });

  test('media playback snapshot validates and round-trips', () {
    final snapshot = MiniProgramMediaPlaybackSnapshot(
      playerId: 'course-video',
      kind: MiniProgramMediaPlaybackKind.video,
      status: MiniProgramMediaPlaybackStatus.playing,
      position: const Duration(seconds: 12),
      duration: const Duration(minutes: 3),
      buffered: const Duration(seconds: 30),
      volume: 0.8,
      speed: 1.25,
    );

    expect(
      MiniProgramMediaPlaybackSnapshot.fromJson(snapshot.toJson()).toJson(),
      snapshot.toJson(),
    );
  });

  test('media playback snapshot rejects unsafe values', () {
    expect(
      () => MiniProgramMediaPlaybackSnapshot(
        playerId: '../player',
        kind: MiniProgramMediaPlaybackKind.audio,
        status: MiniProgramMediaPlaybackStatus.ready,
      ),
      throwsFormatException,
    );
    expect(
      () => MiniProgramMediaPlaybackSnapshot(
        playerId: 'player',
        kind: MiniProgramMediaPlaybackKind.audio,
        status: MiniProgramMediaPlaybackStatus.ready,
        volume: double.nan,
      ),
      throwsFormatException,
    );
  });

  test('media playback errors remain stable', () {
    expect(MiniProgramErrorCodes.mediaNotAccepted, 'media_not_accepted');
    expect(
      MiniProgramErrorCodes.mediaProviderUnavailable,
      'media_provider_unavailable',
    );
    expect(
      MiniProgramErrorCodes.mediaUnsupportedFormat,
      'media_unsupported_format',
    );
    expect(
      MiniProgramErrorCodes.mediaRequestInProgress,
      'media_request_in_progress',
    );
  });
}
