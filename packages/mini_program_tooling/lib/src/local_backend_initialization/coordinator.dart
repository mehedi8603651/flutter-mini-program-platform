import 'dart:io';

import 'dependencies.dart';
import 'models.dart';
import 'paths.dart';
import 'state_persistence.dart';
import 'template_copy.dart';
import 'template_discovery.dart';

Future<LocalBackendInitResult> initializeLocalBackendWorkspace(
  LocalBackendInitializationDependencies dependencies,
  LocalBackendInitRequest request,
) async {
  final paths = resolveLocalBackendWorkspacePaths(dependencies, request);
  final templateRootPath = await resolveLocalBackendTemplateRootPath(
    dependencies,
  );
  final templateDirectory = Directory(templateRootPath);
  if (!await templateDirectory.exists()) {
    throw LocalBackendInitException(
      'Backend workspace template was not found: $templateRootPath',
    );
  }

  final createdPaths = <String>[];
  await copyLocalBackendTemplateTree(
    sourceRootPath: templateRootPath,
    destinationRootPath: paths.backendRootPath,
    force: request.force,
    createdPaths: createdPaths,
  );

  final statePaths = await persistLocalBackendWorkspaceState(
    dependencies,
    paths,
  );
  if (!createdPaths.contains(statePaths.stateFilePath)) {
    createdPaths.add(statePaths.stateFilePath);
  }
  if (!createdPaths.contains(statePaths.globalStateFilePath)) {
    createdPaths.add(statePaths.globalStateFilePath);
  }
  createdPaths.sort();

  return LocalBackendInitResult(
    backendRootPath: paths.backendRootPath,
    apiRootPath: paths.apiRootPath,
    serviceDirectoryPath: paths.serviceDirectoryPath,
    stateFilePath: statePaths.stateFilePath,
    globalStateFilePath: statePaths.globalStateFilePath,
    createdPaths: createdPaths,
  );
}
