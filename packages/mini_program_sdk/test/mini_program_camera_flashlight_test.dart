import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('camera manager isolates requests and releases owned media', () async {
    final provider = _CameraProvider();
    final manager = MiniProgramCameraManager(provider);
    final first = manager.capturePhoto(
      miniProgramId: 'camera-app',
      quality: 95,
    );
    await provider.started.future;

    await expectLater(
      manager.capturePhoto(miniProgramId: 'camera-app', quality: 95),
      throwsA(
        isA<MiniProgramCameraException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.cameraRequestInProgress,
        ),
      ),
    );
    expect(await manager.cancelFor('other-app'), isFalse);
    expect(await manager.cancelFor('camera-app'), isTrue);

    provider.complete();
    await expectLater(
      first,
      throwsA(
        isA<MiniProgramCameraException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.cameraCaptureCancelled,
        ),
      ),
    );
    expect(provider.released, <String>['media-1']);
    await manager.releaseAllFor('other-app');
    await manager.releaseAllFor('camera-app');
    expect(provider.released, <String>['media-1']);
    await manager.dispose();
  });

  test(
    'flashlight ownership prevents cross-app control and cleans up',
    () async {
      final provider = _FlashlightProvider();
      final manager = MiniProgramFlashlightManager(provider);
      expect((await manager.turnOn('app-a')).enabled, isTrue);
      await expectLater(
        manager.turnOff('app-b'),
        throwsA(
          isA<MiniProgramFlashlightException>().having(
            (error) => error.errorCode,
            'errorCode',
            MiniProgramErrorCodes.flashlightInUse,
          ),
        ),
      );
      expect(provider.enabled, isTrue);
      await manager.releaseFor('app-a');
      expect(provider.enabled, isFalse);
      await manager.dispose();
    },
  );
}

class _CameraProvider implements MiniProgramCameraProvider {
  final started = Completer<void>();
  final completed = Completer<MiniProgramCameraPhotoResult>();
  final List<String> released = <String>[];

  void complete() {
    completed.complete(
      MiniProgramCameraPhotoResult(
        captureId: 'capture-placeholder',
        mediaRef: 'media-1',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        bytes: 10,
        width: 10,
        height: 10,
        capturedAtUtc: DateTime.utc(2026, 8, 1),
      ),
    );
  }

  String? captureId;

  @override
  Future<MiniProgramCameraPhotoResult> capturePhoto(
    MiniProgramCameraCaptureRequest request,
  ) async {
    captureId = request.captureId;
    started.complete();
    final result = await completed.future;
    return MiniProgramCameraPhotoResult(
      captureId: request.captureId,
      mediaRef: result.mediaRef,
      fileName: result.fileName,
      mimeType: result.mimeType,
      bytes: result.bytes,
      width: result.width,
      height: result.height,
      capturedAtUtc: result.capturedAtUtc,
    );
  }

  @override
  Future<bool> cancel(String captureId) async => captureId == this.captureId;

  @override
  Future<void> release(String mediaRef) async => released.add(mediaRef);
}

class _FlashlightProvider implements MiniProgramFlashlightProvider {
  bool enabled = false;

  @override
  Future<MiniProgramFlashlightStatus> getStatus() async =>
      MiniProgramFlashlightStatus(available: true, enabled: enabled);

  @override
  Future<MiniProgramFlashlightStatus> setEnabled(bool value) async {
    enabled = value;
    return MiniProgramFlashlightStatus(available: true, enabled: enabled);
  }
}
