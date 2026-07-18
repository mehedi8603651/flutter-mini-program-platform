import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('development build pipeline parity', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'mini_program_build_pipeline_parity_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test(
      'preserves process order, arguments, environment, and result',
      () async {
        final root = path.join(temporaryDirectory.path, 'ordered_build');
        await _writeBuildFixture(root, miniProgramId: 'ordered_build');
        final calls = <_ProcessCall>[];

        Future<ProcessResult> runner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
        }) async {
          calls.add(
            _ProcessCall(
              executable: executable,
              arguments: List<String>.of(arguments),
              workingDirectory: workingDirectory,
              environment: environment == null
                  ? null
                  : Map<String, String>.of(environment),
            ),
          );
          if (arguments.isNotEmpty && arguments.first == 'run') {
            final outputIndex = arguments.indexOf('--output');
            final outputPath = arguments[outputIndex + 1];
            await _writeBuiltEntryScreen(
              outputPath,
              screenId: 'ordered_build_home',
            );
          }
          return ProcessResult(1, 0, '', '');
        }

        final result = await MiniProgramBuilder(
          processRunner: runner,
        ).build(MiniProgramBuildRequest(miniProgramRootPath: root));
        final outputPath = path.join(root, 'mp', '.build');
        final scriptPath = path.join(root, 'tool', 'build_mp.dart');

        expect(calls, <_ProcessCall>[
          _ProcessCall(
            executable: 'dart',
            arguments: const <String>['pub', 'get'],
            workingDirectory: root,
          ),
          _ProcessCall(
            executable: 'dart',
            arguments: <String>['run', scriptPath, '--output', outputPath],
            workingDirectory: root,
            environment: const <String, String>{},
          ),
        ]);
        expect(result.toJson(), <String, dynamic>{
          'repoRootPath': null,
          'miniProgramRootPath': root,
          'miniProgramId': 'ordered_build',
          'outputDirectoryPath': outputPath,
          'screensDirectoryPath': path.join(outputPath, 'screens'),
          'entryScreenJsonPath': path.join(
            outputPath,
            'screens',
            'ordered_build_home.json',
          ),
          'screenFormat': 'mp',
          'screenSchemaVersion': 1,
          'cliSource': 'mp_build_script',
          'invocation': <String>[
            'dart',
            'run',
            scriptPath,
            '--output',
            outputPath,
          ],
          'pubGetRan': true,
        });
      },
    );

    test('preserves pre-process validation order and exact errors', () async {
      final missingRoot = path.join(temporaryDirectory.path, 'missing');
      await _expectBuildFailure(
        MiniProgramBuildRequest(
          miniProgramRootPath: missingRoot,
          skipPubGet: true,
        ),
        'Mini-program root does not exist: $missingRoot',
      );

      final incompleteRoot = path.join(temporaryDirectory.path, 'incomplete');
      await Directory(incompleteRoot).create(recursive: true);
      await _expectBuildFailure(
        MiniProgramBuildRequest(
          miniProgramRootPath: incompleteRoot,
          skipPubGet: true,
        ),
        'Required file is missing: '
        '${path.join(incompleteRoot, 'manifest.json')}',
      );

      final mismatchRoot = path.join(temporaryDirectory.path, 'mismatch');
      await _writeBuildFixture(mismatchRoot, miniProgramId: 'actual_app');
      await _expectBuildFailure(
        MiniProgramBuildRequest(
          miniProgramRootPath: mismatchRoot,
          miniProgramId: 'requested_app',
          skipPubGet: true,
        ),
        'Manifest id "actual_app" does not match requested id '
        '"requested_app".',
      );

      final noScriptRoot = path.join(temporaryDirectory.path, 'no_script');
      await _writeBuildFixture(noScriptRoot, miniProgramId: 'no_script');
      await File(path.join(noScriptRoot, 'tool', 'build_mp.dart')).delete();
      var processCalls = 0;
      Future<ProcessResult> runner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        Map<String, String>? environment,
      }) async {
        processCalls += 1;
        return ProcessResult(1, 0, '', '');
      }

      await _expectBuildFailure(
        MiniProgramBuildRequest(
          miniProgramRootPath: noScriptRoot,
          skipPubGet: false,
        ),
        'Mp build script was not found: '
        '${path.join(noScriptRoot, 'tool', 'build_mp.dart')}\n'
        'Create tool/build_mp.dart or pass --mp-build-script <path>.',
        processRunner: runner,
      );
      expect(processCalls, 0);
    });

    test('preserves process failure formatting and stops the build', () async {
      final root = path.join(
        temporaryDirectory.path,
        'mini_programs',
        'failed_build',
      );
      await _writeBuildFixture(root, miniProgramId: 'failed_build');
      var processCalls = 0;
      Future<ProcessResult> runner(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        Map<String, String>? environment,
      }) async {
        processCalls += 1;
        return ProcessResult(1, 7, ' pub output ', ' stderr output ');
      }

      await _expectBuildFailure(
        MiniProgramBuildRequest(
          repoRootPath: temporaryDirectory.path,
          miniProgramId: 'failed_build',
        ),
        'dart pub get failed for failed_build\n'
        'Command: dart pub get\n'
        'stdout:\n'
        'pub output\n'
        'stderr:\n'
        'stderr output',
        processRunner: runner,
      );
      expect(processCalls, 1);
    });
  });
}

Future<void> _expectBuildFailure(
  MiniProgramBuildRequest request,
  String expectedMessage, {
  ProcessRunner? processRunner,
}) async {
  final builder = processRunner == null
      ? const MiniProgramBuilder()
      : MiniProgramBuilder(processRunner: processRunner);
  await expectLater(
    builder.build(request),
    throwsA(
      isA<MiniProgramBuildException>().having(
        (error) => error.message,
        'message',
        expectedMessage,
      ),
    ),
  );
}

Future<void> _writeBuildFixture(
  String root, {
  required String miniProgramId,
}) async {
  await Directory(path.join(root, 'tool')).create(recursive: true);
  await File(path.join(root, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0
environment:
  sdk: ^3.10.0
''');
  await File(path.join(root, 'manifest.json')).writeAsString(
    jsonEncode(<String, Object?>{
      'id': miniProgramId,
      'entry': '${miniProgramId}_home',
      'screenFormat': 'mp',
      'screenSchemaVersion': 1,
    }),
  );
  await File(
    path.join(root, 'tool', 'build_mp.dart'),
  ).writeAsString('// test build script');
}

Future<void> _writeBuiltEntryScreen(
  String outputPath, {
  required String screenId,
}) async {
  final screens = Directory(path.join(outputPath, 'screens'));
  await screens.create(recursive: true);
  await File(path.join(screens.path, '$screenId.json')).writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': screenId,
      'root': <String, Object?>{
        'type': 'text',
        'props': <String, Object?>{'data': 'Hello'},
        'children': <Object?>[],
      },
    }),
  );
}

class _ProcessCall {
  const _ProcessCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    this.environment,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  @override
  bool operator ==(Object other) =>
      other is _ProcessCall &&
      executable == other.executable &&
      _listEquals(arguments, other.arguments) &&
      workingDirectory == other.workingDirectory &&
      _mapEquals(environment, other.environment);

  @override
  int get hashCode => Object.hash(
    executable,
    Object.hashAll(arguments),
    workingDirectory,
    environment == null ? null : Object.hashAllUnordered(environment!.entries),
  );

  @override
  String toString() =>
      '_ProcessCall($executable, $arguments, $workingDirectory, $environment)';
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _mapEquals(Map<String, String>? left, Map<String, String>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
