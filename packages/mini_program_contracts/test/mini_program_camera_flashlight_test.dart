import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('camera result preserves opaque metadata and validates UTC', () {
    final result = MiniProgramCameraPhotoResult(
      captureId: 'capture-1',
      mediaRef: 'media-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: 1234,
      width: 1280,
      height: 720,
      capturedAtUtc: DateTime.utc(2026, 8, 1, 10),
    );
    expect(
      MiniProgramCameraPhotoResult.fromJson(result.toJson()).toJson(),
      result.toJson(),
    );
    expect(result.toJson(), isNot(contains('path')));
    expect(result.toJson(), isNot(contains('uri')));
    expect(
      () => MiniProgramCameraPhotoResult(
        captureId: 'capture-1',
        mediaRef: 'media-1',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        bytes: 1,
        width: 1,
        height: 1,
        capturedAtUtc: DateTime(2026),
      ),
      throwsFormatException,
    );
  });

  test('flashlight status and stable identifiers remain valid', () {
    const status = MiniProgramFlashlightStatus(available: true, enabled: true);
    expect(
      MiniProgramFlashlightStatus.fromJson(status.toJson()).toJson(),
      status.toJson(),
    );
    expect(
      () => MiniProgramFlashlightStatus.fromJson(const <String, dynamic>{
        'available': false,
        'enabled': true,
      }),
      throwsFormatException,
    );
    expect(ActionNames.cameraCapturePhoto, 'camera.capturePhoto');
    expect(ActionNames.flashlightToggle, 'flashlight.toggle');
    expect(CapabilityIds.cameraCapturePhoto, 'camera.capture_photo');
    expect(CapabilityIds.flashlightControl, 'flashlight.control');
  });
}
