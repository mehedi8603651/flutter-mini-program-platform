import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test(
    'media registry isolates ownership and caches trusted previews',
    () async {
      final provider = _MediaProvider();
      final manager = MiniProgramMediaManager(provider);
      manager.register(miniProgramId: 'drive', mediaRef: 'photo-1');

      final first = await manager.loadPreview(
        miniProgramId: 'drive',
        mediaRef: 'photo-1',
      );
      final second = await manager.loadPreview(
        miniProgramId: 'drive',
        mediaRef: 'photo-1',
      );
      expect(first.bytes, <int>[1, 2, 3]);
      expect(second.bytes, <int>[1, 2, 3]);
      expect(provider.previewCalls, 1);

      expect(
        () => manager.requireOwned('other-app', const <String>['photo-1']),
        throwsA(
          isA<MiniProgramMediaException>().having(
            (error) => error.errorCode,
            'errorCode',
            MiniProgramErrorCodes.mediaNotOwned,
          ),
        ),
      );

      expect(
        await manager.release(miniProgramId: 'drive', mediaRef: 'photo-1'),
        isTrue,
      );
      expect(provider.released, <String>['drive:photo-1']);
      expect(manager.owns('drive', 'photo-1'), isFalse);
      await manager.dispose();
    },
  );

  test(
    'camera registers captured output in the shared media registry',
    () async {
      final provider = _CombinedProvider();
      final mediaManager = MiniProgramMediaManager(provider);
      final cameraManager = MiniProgramCameraManager(
        provider,
        mediaManager: mediaManager,
      );

      final photo = await cameraManager.capturePhoto(
        miniProgramId: 'drive',
        quality: 85,
      );
      expect(mediaManager.owns('drive', photo.mediaRef), isTrue);
      await cameraManager.releaseAllFor('drive');
      expect(mediaManager.owns('drive', photo.mediaRef), isTrue);
      await mediaManager.releaseAllFor('drive');
      expect(provider.releasedMedia, <String>['drive:${photo.mediaRef}']);
      await cameraManager.dispose();
      await mediaManager.dispose();
    },
  );
}

class _MediaProvider implements MiniProgramMediaProvider {
  int previewCalls = 0;
  final List<String> released = <String>[];

  @override
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  ) async {
    previewCalls++;
    return MiniProgramMediaPreviewResult(
      mediaRef: request.mediaRef,
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
  }

  @override
  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request) async {
    released.add('${request.miniProgramId}:${request.mediaRef}');
    return true;
  }
}

class _CombinedProvider
    implements MiniProgramCameraProvider, MiniProgramMediaProvider {
  final List<String> releasedMedia = <String>[];

  @override
  Future<MiniProgramCameraPhotoResult> capturePhoto(
    MiniProgramCameraCaptureRequest request,
  ) async {
    return MiniProgramCameraPhotoResult(
      captureId: request.captureId,
      mediaRef: 'photo-${request.captureId}',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: 3,
      width: 10,
      height: 10,
      capturedAtUtc: DateTime.utc(2026, 8, 1),
    );
  }

  @override
  Future<bool> cancel(String captureId) async => false;

  @override
  Future<void> release(String mediaRef) async {}

  @override
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  ) async {
    return MiniProgramMediaPreviewResult(
      mediaRef: request.mediaRef,
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
  }

  @override
  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request) async {
    releasedMedia.add('${request.miniProgramId}:${request.mediaRef}');
    return true;
  }
}
