import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('serializes host media preview and release deterministically', () {
    expect(MpImageSource.hostMedia.wireName, 'hostMedia');
    expect(
      Mp.media
          .release(
            mediaRef: '{{state.drive.photo.mediaRef}}',
            targetState: 'drive.release',
            statusState: 'drive.media_status',
            errorState: 'drive.media_error',
            requestId: 'release-photo',
          )
          .toJson(),
      <String, Object?>{
        'type': 'media.release',
        'props': <String, Object?>{
          'errorState': 'drive.media_error',
          'mediaRef': '{{state.drive.photo.mediaRef}}',
          'requestId': 'release-photo',
          'statusState': 'drive.media_status',
          'targetState': 'drive.release',
        },
      },
    );
    expect(
      Mp.image(
        src: '{{state.drive.photo.mediaRef}}',
        source: MpImageSource.hostMedia,
      ).toJson(),
      containsPair('type', 'image'),
    );
  });

  test('rejects partial media bindings', () {
    expect(
      () => Mp.media.release(mediaRef: 'photo-{{state.drive.photo}}'),
      throwsArgumentError,
    );
  });
}
