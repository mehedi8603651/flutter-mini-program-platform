import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('file action and capability identifiers are stable', () {
    expect(ActionNames.fileUpload, 'file.upload');
    expect(ActionNames.fileDownload, 'file.download');
    expect(ActionNames.fileCancel, 'file.cancel');
    expect(ActionNames.mediaRelease, 'media.release');
    expect(CapabilityIds.standardValues, contains(CapabilityIds.fileUpload));
    expect(CapabilityIds.standardValues, contains(CapabilityIds.fileDownload));
    expect(CapabilityIds.standardValues, contains(CapabilityIds.mediaPreview));
  });

  test('file progress validates and serializes a bounded state projection', () {
    final progress = MiniProgramFileTransferProgress(
      transferId: 'transfer-1',
      direction: MiniProgramFileTransferDirection.download,
      status: MiniProgramFileTransferStatus.running,
      bytesTransferred: 25,
      totalBytes: 100,
      fileName: 'report.pdf',
    );
    expect(progress.toJson(), <String, Object?>{
      'transferId': 'transfer-1',
      'direction': 'download',
      'status': 'running',
      'bytesTransferred': 25,
      'totalBytes': 100,
      'progress': 0.25,
      'fileName': 'report.pdf',
    });
    expect(
      () => MiniProgramFileTransferProgress(
        transferId: 'transfer-1',
        direction: MiniProgramFileTransferDirection.upload,
        status: MiniProgramFileTransferStatus.running,
        bytesTransferred: 11,
        totalBytes: 10,
      ),
      throwsFormatException,
    );
  });

  test('file errors remain stable', () {
    expect(MiniProgramErrorCodes.fileNotAccepted, 'file_not_accepted');
    expect(
      MiniProgramErrorCodes.fileTransferUnavailable,
      'file_transfer_unavailable',
    );
    expect(MiniProgramErrorCodes.filePickerCancelled, 'file_picker_cancelled');
    expect(MiniProgramErrorCodes.fileTooLarge, 'file_too_large');
    expect(
      MiniProgramErrorCodes.fileTransferCancelled,
      'file_transfer_cancelled',
    );
  });
}
