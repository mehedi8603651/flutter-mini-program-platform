import 'dart:io';

import 'package:path/path.dart' as p;

import 'managed_files.dart';
import 'models.dart';
import 'paths.dart';
import 'validation.dart';

Future<MiniProgramScaffoldResult> scaffoldMiniProgram(
  MiniProgramScaffoldRequest request,
) async {
  final repoRootPath = request.repoRootPath == null
      ? null
      : p.normalize(p.absolute(request.repoRootPath!));
  final miniProgramId = normalizeScaffoldMiniProgramId(request.miniProgramId);
  final capabilities = normalizeScaffoldCapabilities(request.capabilities);
  final backendTemplate = normalizeScaffoldBackendTemplate(
    request.backendTemplate,
  );
  final screenFormat = normalizeScaffoldScreenFormat(request.screenFormat);
  final title = normalizeScaffoldTitle(request.title, miniProgramId);
  final description = normalizeScaffoldDescription(request.description, title);
  final miniProgramRootPath = await resolveMiniProgramScaffoldRootPath(
    repoRootPath: repoRootPath,
    outputRootPath: request.outputRootPath,
    miniProgramId: miniProgramId,
  );
  final miniProgramRootDirectory = Directory(miniProgramRootPath);

  if (await miniProgramRootDirectory.exists() &&
      !request.force &&
      await scaffoldDirectoryHasEntries(miniProgramRootDirectory)) {
    throw MiniProgramScaffoldException(
      'Mini-program already exists: $miniProgramRootPath '
      '(use --force to overwrite scaffold-managed files)',
    );
  }

  await miniProgramRootDirectory.create(recursive: true);
  final specification = MiniProgramScaffoldSpecification(
    repoRootPath: repoRootPath,
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: miniProgramId,
    title: title,
    description: description,
    capabilities: capabilities,
    backendTemplate: backendTemplate,
    screenFormat: screenFormat,
    force: request.force,
  );
  final managedFiles = await buildScaffoldManagedFiles(specification);
  final createdPaths = await writeScaffoldManagedFiles(managedFiles);

  return MiniProgramScaffoldResult(
    repoRootPath: repoRootPath,
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: miniProgramId,
    title: title,
    description: description,
    capabilities: capabilities,
    screenFormat: screenFormat,
    createdPaths: createdPaths,
  );
}
