import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('camera actions serialize deterministic optional bounds', () {
    expect(
      Mp.camera
          .capturePhoto(
            maxWidth: 1920,
            maxHeight: 1080,
            quality: 90,
            targetState: 'camera.photo',
            statusState: 'camera.status',
            errorState: 'camera.error',
            requestId: 'photo-1',
          )
          .toJson(),
      <String, Object?>{
        'type': 'camera.capturePhoto',
        'props': <String, Object?>{
          'errorState': 'camera.error',
          'maxHeight': 1080,
          'maxWidth': 1920,
          'quality': 90,
          'requestId': 'photo-1',
          'statusState': 'camera.status',
          'targetState': 'camera.photo',
        },
      },
    );
    expect(
      Mp.camera.cancel(targetState: 'camera.cancelled').toJson(),
      <String, Object?>{
        'type': 'camera.cancel',
        'props': <String, Object?>{'targetState': 'camera.cancelled'},
      },
    );
  });

  test('camera actions reject invalid dimensions quality and state keys', () {
    expect(
      () => Mp.camera.capturePhoto(maxWidth: 63, targetState: 'camera.photo'),
      throwsArgumentError,
    );
    expect(
      () => Mp.camera.capturePhoto(quality: 101, targetState: 'camera.photo'),
      throwsArgumentError,
    );
    expect(
      () => Mp.camera.capturePhoto(targetState: 'camera..photo'),
      throwsArgumentError,
    );
  });
}
