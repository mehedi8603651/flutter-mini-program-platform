import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('scaffolding parity', () {
    late Directory temporaryDirectory;
    late Directory miniProgramsDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'mini_program_scaffolding_parity_',
      );
      miniProgramsDirectory = Directory(
        path.join(temporaryDirectory.path, 'mini_programs'),
      );
      await miniProgramsDirectory.create(recursive: true);
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('preserves managed file order and representative bytes', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'phase_nine',
          capabilities: const <String>{
            'native_navigation',
            'secure_api',
            'analytics',
            'auth',
          },
          backendTemplate: 'mock',
        ),
      );
      final root = result.miniProgramRootPath;

      expect(
        result.createdPaths
            .map(
              (filePath) =>
                  path.relative(filePath, from: root).replaceAll('\\', '/'),
            )
            .toList(),
        <String>[
          'manifest.json',
          'README.md',
          'pubspec.yaml',
          '.gitignore',
          'tool/build_mp.dart',
          'mp/program.dart',
          'mp/screens/phase_nine_home.dart',
          'mp/screens/phase_nine_details.dart',
          'assets/.gitkeep',
          'backend/mock/pubspec.yaml',
          'backend/mock/README.md',
          'backend/mock/bin/server.dart',
          'backend/mock/data/home_bootstrap.json',
          'backend/mock/data/coupons_list.json',
          'backend/mock/data/session.json',
        ],
      );
      expect(
        await File(path.join(root, 'manifest.json')).readAsString(),
        _expectedManifest,
      );
      expect(
        await File(path.join(root, 'tool', 'build_mp.dart')).readAsString(),
        _expectedBuildScript,
      );
      expect(
        await File(path.join(root, '.gitignore')).readAsString(),
        _expectedGitignore,
      );
    });

    test(
      'force replaces managed files and preserves unrelated files',
      () async {
        final root = Directory(
          path.join(miniProgramsDirectory.path, 'force_app'),
        );
        await root.create(recursive: true);
        final unrelated = File(path.join(root.path, 'publisher_notes.txt'));
        await unrelated.writeAsString('keep this file');
        await File(path.join(root.path, 'manifest.json')).writeAsString('{}');

        await const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: temporaryDirectory.path,
            miniProgramId: 'force_app',
            force: true,
          ),
        );

        expect(await unrelated.readAsString(), 'keep this file');
        expect(
          await File(path.join(root.path, 'manifest.json')).readAsString(),
          contains('"id": "force_app"'),
        );
      },
    );

    test('preserves validation error messages', () async {
      await _expectFailure(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'Invalid-App',
        ),
        r'Mini-program ID must match ^[a-z][a-z0-9_]*$',
      );
      await _expectFailure(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'unknown_capability',
          capabilities: const <String>{'camera', 'analytics'},
        ),
        'Unknown capability values: camera',
      );
      await _expectFailure(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'unsupported_backend',
          backendTemplate: 'lambda',
        ),
        'Unsupported Publisher API starter template: lambda',
      );
      await _expectFailure(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'unsupported_screen',
          screenFormat: 'flutter',
        ),
        'Unsupported screen format: flutter',
      );

      final existing = Directory(
        path.join(miniProgramsDirectory.path, 'existing_app'),
      );
      await existing.create(recursive: true);
      await File(path.join(existing.path, 'notes.txt')).writeAsString('owned');
      await _expectFailure(
        MiniProgramScaffoldRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'existing_app',
        ),
        'Mini-program already exists: ${existing.path} '
        '(use --force to overwrite scaffold-managed files)',
      );
    });
  });
}

Future<void> _expectFailure(
  MiniProgramScaffoldRequest request,
  String expectedMessage,
) async {
  await expectLater(
    const MiniProgramScaffolder().scaffold(request),
    throwsA(
      isA<MiniProgramScaffoldException>().having(
        (error) => error.message,
        'message',
        expectedMessage,
      ),
    ),
  );
}

const String _expectedManifest = '''{
  "id": "phase_nine",
  "version": "1.0.0",
  "entry": "phase_nine_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": [
    "auth",
    "analytics",
    "secure_api",
    "native_navigation"
  ],
  "screenFormat": "mp",
  "screenSchemaVersion": 1,
  "cachePolicy": {
    "manifest": {
      "mode": "noCache"
    },
    "entryScreen": {
      "mode": "noCache"
    }
  },
  "fallback": {
    "strategy": "errorView",
    "message": "phase_nine is temporarily unavailable in this host app."
  }
}''';

const String _expectedBuildScript = '''
import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) async {
  await writeMpBuildOutput(miniProgram, arguments: arguments);
}
''';

const String _expectedGitignore = '''
.dart_tool/
.packages
.pub/
build/
mp/.build/
mp/.build/
*.log
''';
