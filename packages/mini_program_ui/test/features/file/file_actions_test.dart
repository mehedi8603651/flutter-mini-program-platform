import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('Mp.file', () {
    test('serializes upload, download, and cancel deterministically', () {
      expect(
        Mp.file
            .upload(
              endpoint: 'files/upload',
              mimeTypes: const <String>['image/*', 'application/pdf'],
              multiple: true,
              fieldName: 'documents',
              metadata: const <String, Object?>{'folderId': 'inbox'},
              progressState: 'files.progress',
              targetState: 'files.upload',
              statusState: 'files.status',
              errorState: 'files.error',
              requestId: 'upload-files',
            )
            .toJson(),
        <String, Object?>{
          'type': 'file.upload',
          'props': <String, Object?>{
            'endpoint': 'files/upload',
            'errorState': 'files.error',
            'fieldName': 'documents',
            'metadata': <String, Object?>{'folderId': 'inbox'},
            'mimeTypes': <String>['image/*', 'application/pdf'],
            'multiple': true,
            'progressState': 'files.progress',
            'requestId': 'upload-files',
            'statusState': 'files.status',
            'targetState': 'files.upload',
          },
        },
      );

      expect(
        Mp.file
            .download(
              endpoint: '/files/download',
              method: 'post',
              request: const <String, Object?>{'fileId': 'file-1'},
              destination: 'choose',
              suggestedName: '{{state.files.name}}',
              expectedMimeType: 'application/pdf',
              progressState: 'files.progress',
              targetState: 'files.download',
            )
            .toJson(),
        <String, Object?>{
          'type': 'file.download',
          'props': <String, Object?>{
            'destination': 'choose',
            'endpoint': 'files/download',
            'expectedMimeType': 'application/pdf',
            'method': 'POST',
            'progressState': 'files.progress',
            'request': <String, Object?>{'fileId': 'file-1'},
            'suggestedName': '{{state.files.name}}',
            'targetState': 'files.download',
          },
        },
      );

      expect(
        Mp.file
            .cancel(
              transferId: '{{state.files.progress.transferId}}',
              statusState: 'files.status',
            )
            .toJson(),
        <String, Object?>{
          'type': 'file.cancel',
          'props': <String, Object?>{
            'statusState': 'files.status',
            'transferId': '{{state.files.progress.transferId}}',
          },
        },
      );
    });

    test('rejects unsafe endpoints, MIME types, and invalid state', () {
      expect(
        () => Mp.file.upload(
          endpoint: 'https://evil.example/upload',
          progressState: 'files.progress',
          targetState: 'files.result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.file.upload(
          endpoint: '../upload',
          progressState: 'files.progress',
          targetState: 'files.result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.file.upload(
          endpoint: 'upload',
          mimeTypes: const <String>['not-a-mime'],
          progressState: 'files.progress',
          targetState: 'files.result',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.file.download(
          endpoint: 'download',
          destination: 'private-path',
          progressState: 'files..progress',
          targetState: 'files.result',
        ),
        throwsArgumentError,
      );
    });
  });
}
