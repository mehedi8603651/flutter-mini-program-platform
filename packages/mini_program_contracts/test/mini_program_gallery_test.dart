import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  final image = MiniProgramGalleryImage(
    mediaRef: 'gallery_abc',
    fileName: 'photo.jpg',
    mimeType: 'image/jpeg',
    bytes: 1234,
    width: 800,
    height: 600,
  );
  test('gallery metadata round trips without native locations', () {
    final result = MiniProgramGalleryResult(
      selectionId: 'selection_1',
      images: [image],
      selectedAtUtc: DateTime.utc(2026),
    );
    expect(
      MiniProgramGalleryResult.fromJson(result.toJson()).toJson(),
      result.toJson(),
    );
    expect(
      image.toJson().keys,
      unorderedEquals([
        'mediaRef',
        'fileName',
        'mimeType',
        'bytes',
        'width',
        'height',
        'source',
      ]),
    );
    expect(() => result.images.clear(), throwsUnsupportedError);
  });
  test(
    'rejects paths, unsafe MIME, dimensions, duplicate refs and timestamps',
    () {
      for (final patch in <Map<String, dynamic>>[
        {'mediaRef': 'content://photos/1'},
        {'fileName': '../photo.jpg'},
        {'mimeType': 'text/html'},
        {'bytes': 0},
        {'width': 8193},
        {'source': 'camera'},
        {'width': 8192, 'height': 8192},
      ]) {
        expect(
          () => MiniProgramGalleryImage.fromJson({...image.toJson(), ...patch}),
          throwsFormatException,
        );
      }
      expect(
        () => MiniProgramGalleryResult(
          selectionId: 's',
          images: [image, image],
          selectedAtUtc: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(
        () => MiniProgramGalleryResult.fromJson({
          'selectionId': 's',
          'images': [image.toJson()],
          'selectedAtUtc': '2026-01-01',
        }),
        throwsFormatException,
      );
    },
  );
}
