import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('file policy supports wildcards and an optional byte cap', () {
    const policy = MiniProgramFilePolicy(
      enabled: true,
      allowUpload: true,
      allowedMimeTypes: <String>{'image/*', 'application/pdf'},
      maxFileBytes: null,
    );
    expect(policy.acceptsMimeType('image/png'), isTrue);
    expect(policy.acceptsMimeType('application/pdf'), isTrue);
    expect(policy.acceptsMimeType('video/mp4'), isFalse);
    expect(policy.maxFileBytes, isNull);
  });

  test('transfer manager isolates cancellation by mini-program', () async {
    final provider = _BlockingFileProvider();
    final manager = MiniProgramFileTransferManager(provider);
    final request = MiniProgramFileDownloadRequest(
      transferId: 'transfer-1',
      miniProgramId: 'drive',
      backend: MiniProgramResolvedBackendTransfer(
        candidateUris: <Uri>[Uri.parse('https://api.example.com/download')],
        method: 'GET',
        headers: const <String, String>{},
        timeout: const Duration(seconds: 10),
      ),
      request: const <String, dynamic>{},
      destination: MiniProgramFileDownloadDestination.downloads,
      maxFileBytes: null,
      minimumFreeBytes: 0,
      maxConcurrentTransfers: 1,
    );
    final running = manager.download(request, onProgress: (_) {});
    await provider.started.future;

    await expectLater(
      manager.download(
        MiniProgramFileDownloadRequest(
          transferId: 'transfer-2',
          miniProgramId: 'drive',
          backend: request.backend,
          request: const <String, dynamic>{},
          destination: MiniProgramFileDownloadDestination.downloads,
          maxFileBytes: null,
          minimumFreeBytes: 0,
          maxConcurrentTransfers: 1,
        ),
        onProgress: (_) {},
      ),
      throwsA(
        isA<MiniProgramFileException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.fileTransferLimitExceeded,
        ),
      ),
    );

    expect(await manager.cancel('other-app', 'transfer-1'), isFalse);
    expect(await manager.cancel('drive', 'transfer-1'), isTrue);
    expect(provider.cancelled, contains('transfer-1'));
    provider.complete();
    await running;
    await manager.dispose();
  });

  test('lifecycle cleanup contains provider cancellation failures', () async {
    final provider = _BlockingFileProvider(throwOnCancel: true);
    final manager = MiniProgramFileTransferManager(provider);
    final running = manager.download(
      MiniProgramFileDownloadRequest(
        transferId: 'transfer-1',
        miniProgramId: 'drive',
        backend: MiniProgramResolvedBackendTransfer(
          candidateUris: <Uri>[Uri.parse('https://api.example.com/download')],
          method: 'GET',
          headers: const <String, String>{},
          timeout: const Duration(seconds: 10),
        ),
        request: const <String, dynamic>{},
        destination: MiniProgramFileDownloadDestination.downloads,
        maxFileBytes: null,
        minimumFreeBytes: 0,
        maxConcurrentTransfers: 1,
      ),
      onProgress: (_) {},
    );
    await provider.started.future;

    await expectLater(manager.dispose(), completes);
    provider.complete();
    await running;
  });
}

class _BlockingFileProvider implements MiniProgramFileTransferProvider {
  _BlockingFileProvider({this.throwOnCancel = false});

  final bool throwOnCancel;
  final started = Completer<void>();
  final result = Completer<MiniProgramFileTransferResult>();
  final Set<String> cancelled = <String>{};

  void complete() {
    if (!result.isCompleted) {
      result.complete(
        const MiniProgramFileTransferResult(
          transferId: 'transfer-1',
          direction: MiniProgramFileTransferDirection.download,
          statusCode: 200,
          bytesTransferred: 0,
        ),
      );
    }
  }

  @override
  Future<MiniProgramFileTransferResult> download(
    MiniProgramFileDownloadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) {
    started.complete();
    return result.future;
  }

  @override
  Future<MiniProgramFileTransferResult> upload(
    MiniProgramFileUploadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) => throw UnimplementedError();

  @override
  Future<bool> cancel(String transferId) async {
    if (throwOnCancel) {
      throw StateError('cancel failed');
    }
    return cancelled.add(transferId);
  }
}
