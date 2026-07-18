import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test(
    'build pipeline public API remains available from the package barrel',
    () {
      const request = MiniProgramBuildRequest(
        miniProgramId: 'public_build_app',
        skipPubGet: true,
      );
      const result = MiniProgramBuildResult(
        repoRootPath: 'repo',
        miniProgramRootPath: 'repo/mini_programs/public_build_app',
        miniProgramId: 'public_build_app',
        outputDirectoryPath: 'repo/mini_programs/public_build_app/mp/.build',
        screensDirectoryPath:
            'repo/mini_programs/public_build_app/mp/.build/screens',
        entryScreenJsonPath:
            'repo/mini_programs/public_build_app/mp/.build/screens/home.json',
        screenFormat: 'mp',
        screenSchemaVersion: 1,
        cliSource: 'mp_build_script',
        invocation: <String>['dart', 'run', 'tool/build_mp.dart'],
        pubGetRan: false,
      );
      const exception = MiniProgramBuildException('build failed');
      final ProcessRunner runner = _successfulRunner;
      final builder = MiniProgramBuilder(processRunner: runner);

      expect(request.miniProgramId, 'public_build_app');
      expect(builder, isA<MiniProgramBuilder>());
      expect(exception.toString(), 'build failed');
      expect(result.toJson().keys.toList(), <String>[
        'repoRootPath',
        'miniProgramRootPath',
        'miniProgramId',
        'outputDirectoryPath',
        'screensDirectoryPath',
        'entryScreenJsonPath',
        'screenFormat',
        'screenSchemaVersion',
        'cliSource',
        'invocation',
        'pubGetRan',
      ]);
    },
  );
}

Future<ProcessResult> _successfulRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async => ProcessResult(1, 0, '', '');
