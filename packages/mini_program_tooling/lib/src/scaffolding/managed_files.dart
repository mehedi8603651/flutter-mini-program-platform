import 'dart:io';

import 'package:path/path.dart' as p;

import '../publisher_backend/generated_files.dart';
import 'dependencies.dart';
import 'models.dart';
import 'templates/dart_sources.dart';
import 'templates/manifest.dart';
import 'templates/project_files.dart';
import 'validation.dart';

Future<Map<String, String>> buildScaffoldManagedFiles(
  MiniProgramScaffoldSpecification specification,
) async {
  final homeFunctionName =
      'build${scaffoldPascalCase(specification.miniProgramId)}Home';
  final detailsFunctionName =
      'build${scaffoldPascalCase(specification.miniProgramId)}Details';
  final miniProgramUiDependency =
      await resolveScaffoldMiniProgramUiDependency();
  final dependencyOverrides = await resolveScaffoldDependencyOverrides();
  final root = specification.miniProgramRootPath;

  final files = <String, String>{
    p.join(root, 'manifest.json'): buildScaffoldManifest(
      miniProgramId: specification.miniProgramId,
      capabilities: specification.capabilities,
      entryScreenId: specification.entryScreenId,
    ),
    p.join(root, 'README.md'): buildScaffoldReadme(
      miniProgramId: specification.miniProgramId,
      title: specification.title,
      description: specification.description,
      capabilities: specification.capabilities,
      entryScreenId: specification.entryScreenId,
      withMockBackend: specification.withMockBackend,
    ),
    p.join(root, 'pubspec.yaml'): buildScaffoldPubspec(
      packageName: specification.packageName,
      title: specification.title,
      miniProgramUiDependency: miniProgramUiDependency,
      dependencyOverrides: dependencyOverrides,
    ),
    p.join(root, '.gitignore'): buildScaffoldGitignore(),
    p.join(root, 'tool', 'build_mp.dart'): buildScaffoldBuildScript(),
    p.join(root, 'mp', 'program.dart'): buildScaffoldProgram(
      entryScreenId: specification.entryScreenId,
      detailsScreenId: specification.detailsScreenId,
      homeFunctionName: homeFunctionName,
      detailsFunctionName: detailsFunctionName,
    ),
    p.join(
      root,
      'mp',
      'screens',
      '${specification.entryScreenId}.dart',
    ): buildScaffoldHomeScreen(
      title: specification.title,
      capabilities: specification.capabilities,
      detailsScreenId: specification.detailsScreenId,
      homeFunctionName: homeFunctionName,
      withMockBackend: specification.withMockBackend,
    ),
    p.join(
      root,
      'mp',
      'screens',
      '${specification.detailsScreenId}.dart',
    ): buildScaffoldDetailsScreen(
      title: specification.title,
      detailsFunctionName: detailsFunctionName,
    ),
    p.join(root, 'assets', '.gitkeep'): '',
  };

  if (specification.withMockBackend) {
    files.addAll(_buildMockBackendFiles(specification));
  }
  return files;
}

Future<List<String>> writeScaffoldManagedFiles(
  Map<String, String> managedFiles,
) async {
  final createdPaths = <String>[];
  for (final entry in managedFiles.entries) {
    final file = File(entry.key);
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    createdPaths.add(file.path);
  }
  return createdPaths;
}

Map<String, String> _buildMockBackendFiles(
  MiniProgramScaffoldSpecification specification,
) =>
    buildMockPublisherBackendFiles(
      miniProgramRootPath: specification.miniProgramRootPath,
      miniProgramId: specification.miniProgramId,
      title: specification.title,
    ).map(
      (relativePath, contents) => MapEntry(
        p.join(
          specification.miniProgramRootPath,
          'backend',
          'mock',
          relativePath,
        ),
        contents,
      ),
    );
