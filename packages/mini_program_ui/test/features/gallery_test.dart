import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('gallery actions serialize deterministically', () {
    expect(
      Mp.gallery
          .pickImages(
            maxImages: 3,
            targetState: 'photos',
            statusState: 'status',
            errorState: 'error',
          )
          .toJson(),
      {
        'type': 'gallery.pickImages',
        'props': {
          'maxImages': 3,
          'maxWidth': 2048,
          'maxHeight': 2048,
          'quality': 90,
          'targetState': 'photos',
          'statusState': 'status',
          'errorState': 'error',
        },
      },
    );
    expect(Mp.gallery.cancel().toJson(), {
      'type': 'gallery.cancel',
      'props': <String, dynamic>{},
    });
  });
  test('gallery authoring rejects invalid limits and state keys', () {
    for (final count in [0, 31]) {
      expect(
        () => Mp.gallery.pickImages(maxImages: count, targetState: 'photos'),
        throwsArgumentError,
      );
    }
    expect(
      () => Mp.gallery.pickImages(quality: 0, targetState: 'photos'),
      throwsArgumentError,
    );
    expect(
      () => Mp.gallery.pickImages(maxWidth: 63, targetState: 'photos'),
      throwsArgumentError,
    );
    expect(() => Mp.gallery.pickImages(targetState: ''), throwsArgumentError);
  });
}
