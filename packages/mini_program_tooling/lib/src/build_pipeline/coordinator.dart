import 'dart:io';

import 'package:path/path.dart' as p;

import 'commands.dart';
import 'data_assets.dart';
import 'manifest.dart';
import 'models.dart';
import 'paths.dart';
import 'process.dart';
import 'screen_validation.dart';
import 'specification.dart';

Future<MiniProgramBuildResult> buildMiniProgramDevelopmentOutput(
  MiniProgramBuildRequest request, {
  required ProcessRunner processRunner,
}) async {
  final specification = await _resolveBuildSpecification(request);

  if (!specification.skipPubGet) {
    await runMiniProgramBuildProcessOrThrow(
      processRunner: processRunner,
      executable: 'dart',
      arguments: const <String>['pub', 'get'],
      workingDirectory: specification.paths.miniProgramRootPath,
      failureLabel:
          'dart pub get failed for '
          '${specification.requestedMiniProgramId ?? specification.paths.miniProgramRootPath}',
    );
  }

  final command = specification.command;
  await runMiniProgramBuildProcessOrThrow(
    processRunner: processRunner,
    executable: command.executable,
    arguments: command.arguments,
    workingDirectory: command.workingDirectory,
    environment: command.environment,
    failureLabel: 'Mp build failed for ${specification.manifest.miniProgramId}',
  );

  final paths = specification.paths;
  if (!await File(paths.entryScreenJsonPath).exists()) {
    throw MiniProgramBuildException(
      'Build completed but entry screen JSON was not found: '
      '${paths.entryScreenJsonPath}',
    );
  }
  final manifest = specification.manifest;
  if (manifest.screenFormat == 'mp') {
    await validateMiniProgramBuildEntryScreen(
      entryScreenJsonPath: paths.entryScreenJsonPath,
      entryScreenId: manifest.entryScreenId,
      screenSchemaVersion: manifest.screenSchemaVersion,
    );
    await validateMiniProgramBuildJsonDataAssets(
      screensDirectoryPath: paths.screensDirectoryPath,
      assetsDirectoryPath: paths.assetsDirectoryPath,
    );
  }

  return MiniProgramBuildResult(
    repoRootPath: specification.repoRootPath,
    miniProgramRootPath: paths.miniProgramRootPath,
    miniProgramId: manifest.miniProgramId,
    outputDirectoryPath: paths.outputDirectoryPath,
    screensDirectoryPath: paths.screensDirectoryPath,
    entryScreenJsonPath: paths.entryScreenJsonPath,
    screenFormat: manifest.screenFormat,
    screenSchemaVersion: manifest.screenSchemaVersion,
    cliSource: command.source,
    invocation: <String>[command.executable, ...command.arguments],
    pubGetRan: !specification.skipPubGet,
  );
}

Future<MiniProgramBuildSpecification> _resolveBuildSpecification(
  MiniProgramBuildRequest request,
) async {
  final repoRootPath = normalizeMiniProgramBuildRepoRootPath(
    request.repoRootPath,
  );
  final miniProgramRootPath = resolveMiniProgramBuildRootPath(
    repoRootPath: repoRootPath,
    miniProgramId: request.miniProgramId,
    miniProgramRootPath: request.miniProgramRootPath,
  );
  await validateMiniProgramBuildProject(miniProgramRootPath);

  final manifestPath = p.join(miniProgramRootPath, 'manifest.json');
  final manifest = await loadMiniProgramBuildManifest(
    manifestPath: manifestPath,
    requestedMiniProgramId: request.miniProgramId,
  );
  final outputDirectoryPath = await resolveMiniProgramBuildOutputDirectory(
    miniProgramRootPath: miniProgramRootPath,
    screenFormat: manifest.screenFormat,
  );
  final paths = createMiniProgramBuildPaths(
    miniProgramRootPath: miniProgramRootPath,
    outputDirectoryPath: outputDirectoryPath,
    entryScreenId: manifest.entryScreenId,
  );
  final command = await resolveMiniProgramBuildCommand(
    miniProgramRootPath: miniProgramRootPath,
    outputDirectoryPath: outputDirectoryPath,
    mpBuildScriptPath: request.mpBuildScriptPath,
  );
  return MiniProgramBuildSpecification(
    repoRootPath: repoRootPath,
    paths: paths,
    manifest: manifest,
    command: command,
    requestedMiniProgramId: request.miniProgramId,
    skipPubGet: request.skipPubGet,
  );
}
