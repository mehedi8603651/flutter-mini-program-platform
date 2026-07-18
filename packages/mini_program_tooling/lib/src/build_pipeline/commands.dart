import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<MiniProgramBuildCommand> resolveMiniProgramBuildCommand({
  required String miniProgramRootPath,
  required String outputDirectoryPath,
  required String? mpBuildScriptPath,
}) async {
  final scriptPath =
      mpBuildScriptPath != null && mpBuildScriptPath.trim().isNotEmpty
      ? p.normalize(p.absolute(mpBuildScriptPath.trim()))
      : p.join(miniProgramRootPath, 'tool', 'build_mp.dart');

  if (!await File(scriptPath).exists()) {
    throw MiniProgramBuildException(
      'Mp build script was not found: $scriptPath\n'
      'Create tool/build_mp.dart or pass --mp-build-script <path>.',
    );
  }

  return MiniProgramBuildCommand(
    source: mpBuildScriptPath != null && mpBuildScriptPath.trim().isNotEmpty
        ? 'explicit_mp_build_script'
        : 'mp_build_script',
    executable: 'dart',
    arguments: <String>['run', scriptPath, '--output', outputDirectoryPath],
    workingDirectory: miniProgramRootPath,
    environment: const <String, String>{},
  );
}
