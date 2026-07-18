import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('MiniProgramHostController run', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_host_run_',
      );
      await File(
        path.join(tempDirectory.path, 'pubspec.yaml'),
      ).writeAsString('name: host_app\n');
      await File(
        path.join(
          tempDirectory.path,
          'lib',
          'mini_program',
          'mini_program_runtime_setup.dart',
        ),
      ).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('preserves the flutter invocation and backend define', () async {
      String? executable;
      List<String>? arguments;
      String? capturedWorkingDirectory;
      final controller = MiniProgramHostController(
        processRunner:
            (
              String nextExecutable,
              List<String> nextArguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              executable = nextExecutable;
              arguments = nextArguments;
              capturedWorkingDirectory = workingDirectory;
              return 7;
            },
      );

      final result = await controller.run(
        MiniProgramHostRunRequest(
          projectRootPath: tempDirectory.path,
          deviceId: 'emulator-5554',
          backendApiBaseUrl: '  https://api.example.com  ',
        ),
      );

      expect(executable, 'flutter');
      expect(arguments, <String>[
        'run',
        '-d',
        'emulator-5554',
        '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://api.example.com',
      ]);
      expect(capturedWorkingDirectory, tempDirectory.path);
      expect(result.invocation, arguments);
      expect(result.backendApiBaseUrl, 'https://api.example.com');
      expect(result.exitCode, 7);
    });

    test(
      'fails before launch when generated runtime setup is missing',
      () async {
        await File(
          path.join(
            tempDirectory.path,
            'lib',
            'mini_program',
            'mini_program_runtime_setup.dart',
          ),
        ).delete();

        await expectLater(
          MiniProgramHostController().run(
            MiniProgramHostRunRequest(
              projectRootPath: tempDirectory.path,
              deviceId: 'windows',
              backendApiBaseUrl: '',
            ),
          ),
          throwsA(
            isA<MiniProgramHostException>().having(
              (error) => error.message,
              'message',
              contains('miniprogram embed init'),
            ),
          ),
        );
      },
    );
  });
}
