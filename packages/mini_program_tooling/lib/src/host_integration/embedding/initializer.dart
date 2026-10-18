import 'dart:io';

import 'package:path/path.dart' as path;

import '../capabilities/file_transaction.dart';
import '../capabilities/models.dart';
import 'android_integration.dart';
import 'android_tasks/native_templates.dart';
import 'android_tasks/planner.dart';
import 'dart_templates.dart';
import 'models.dart';
import 'pubspec_editor.dart';
import 'readme_template.dart';

const String _miniProgramSdkConstraint = '^0.6.14';
const String _miniProgramContractsConstraint = '^0.3.16';

Future<MiniProgramEmbeddingInitResult> initializeMiniProgramEmbedding(
  MiniProgramEmbeddingInitRequest request,
) async {
  final projectRootPath = path.normalize(
    path.absolute(request.projectRootPath),
  );
  final repoRootPath = request.repoRootPath == null
      ? null
      : path.normalize(path.absolute(request.repoRootPath!));

  final projectRootDir = Directory(projectRootPath);
  if (!await projectRootDir.exists()) {
    throw MiniProgramEmbeddingInitException(
      'Project root does not exist: $projectRootPath',
    );
  }

  final pubspecPath = path.join(projectRootPath, 'pubspec.yaml');
  final libDirPath = path.join(projectRootPath, 'lib');
  final pubspecFile = File(pubspecPath);
  if (!await pubspecFile.exists()) {
    throw MiniProgramEmbeddingInitException(
      'Flutter project is missing pubspec.yaml: $projectRootPath',
    );
  }
  if (!await Directory(libDirPath).exists()) {
    throw MiniProgramEmbeddingInitException(
      'Flutter project is missing lib/: $projectRootPath',
    );
  }

  final pubspecSource = await pubspecFile.readAsString();
  final packageName = extractEmbeddingPubspecField(
    pubspecSource,
    'name',
    fallbackValue: path.basename(projectRootPath),
  );
  final resolvedHostAppId = request.hostAppId?.trim().isNotEmpty == true
      ? request.hostAppId!.trim()
      : packageName;
  final resolvedHostVersion = request.hostVersion?.trim().isNotEmpty == true
      ? request.hostVersion!.trim()
      : extractEmbeddingVersion(pubspecSource);
  final normalizedRoutePath = _normalizeRoutePath(request.nativeRoutePath);
  final tasksFile = File(
    path.join(
      projectRootPath,
      'lib',
      'mini_program',
      'mini_program_android_tasks.dart',
    ),
  );
  // A scaffold refresh must not silently disable a previously opted-in host.
  final androidSeparateTasks =
      request.androidSeparateTasks ||
      (await tasksFile.exists() &&
          (await tasksFile.readAsString()).contains(
            androidTasksGeneratedMarker,
          ));
  final sdkConstraint = _miniProgramSdkConstraint;
  final updatedPubspecSource = ensureEmbeddingDependencies(
    pubspecSource,
    projectRootPath: projectRootPath,
    repoRootPath: repoRootPath,
    sdkConstraint: sdkConstraint,
    contractsConstraint: _miniProgramContractsConstraint,
  );

  final integrationRootPath = path.join(projectRootPath, 'lib', 'mini_program');
  final integrationRootDir = Directory(integrationRootPath);

  final scaffoldGeneratedFiles = <String, String>{
    path.join(
      integrationRootPath,
      'mini_program_runtime_setup.dart',
    ): buildEmbeddingRuntimeSetup(
      hostAppId: resolvedHostAppId,
      hostVersion: resolvedHostVersion,
    ),
    path.join(integrationRootPath, 'mini_program_launcher.dart'):
        buildEmbeddingLauncher(),
    path.join(integrationRootPath, 'mini_program.dart'): buildEmbeddingBarrel(
      androidSeparateTasks: androidSeparateTasks,
    ),
    path.join(integrationRootPath, 'README.md'): buildEmbeddingReadme(
      packageName: packageName,
      repoRootPath: repoRootPath,
      hostAppId: resolvedHostAppId,
      hostVersion: resolvedHostVersion,
      sdkConstraint: sdkConstraint,
      contractsConstraint: _miniProgramContractsConstraint,
      androidSeparateTasks: androidSeparateTasks,
    ),
  };
  final endpointImportGeneratedFiles = <String, String>{
    path.join(integrationRootPath, 'mini_program_endpoints.dart'):
        buildEmptyEmbeddingEndpoints(),
    path.join(integrationRootPath, 'mini_program_registry.dart'):
        buildEmptyEmbeddingRegistry(),
    path.join(integrationRootPath, 'mini_program_policy_resolver.dart'):
        buildEmptyEmbeddingPolicyResolver(),
  };
  final hostOwnedFiles = <String, String>{
    path.join(integrationRootPath, 'app_host_bridge.dart'):
        buildEmbeddingHostBridge(logPrefix: resolvedHostAppId),
    path.join(integrationRootPath, 'mini_program_host_setup.dart'):
        buildEmbeddingHostSetup(),
    path.join(integrationRootPath, 'mini_program_policies.json'):
        buildEmptyEmbeddingPolicies(),
  };
  final platformIntegrationFiles = buildEmbeddingPlatformIntegrationFiles(
    projectRootPath: projectRootPath,
  );

  if (await integrationRootDir.exists() &&
      !request.force &&
      await _directoryHasEntries(integrationRootDir)) {
    throw MiniProgramEmbeddingInitException(
      'Embedding adapter already exists: $integrationRootPath '
      '(use --force to overwrite scaffold-managed files)',
    );
  }

  if (androidSeparateTasks) {
    final nativeTaskFiles = await planAndroidSeparateTasks(
      projectRootPath: projectRootPath,
      platformFiles: platformIntegrationFiles,
    );
    final writes = <String, String>{
      if (updatedPubspecSource != pubspecSource)
        pubspecPath: updatedPubspecSource,
      ...scaffoldGeneratedFiles,
      for (final entry in endpointImportGeneratedFiles.entries)
        if (!await File(entry.key).exists()) entry.key: entry.value,
      for (final entry in hostOwnedFiles.entries)
        if (!await File(entry.key).exists()) entry.key: entry.value,
      ...platformIntegrationFiles,
      ...nativeTaskFiles,
    };
    try {
      await writeCapabilityFiles(
        projectRootPath: projectRootPath,
        capability: 'android-separate-tasks',
        platform: 'android',
        writes: writes,
      );
    } on MiniProgramHostCapabilityException catch (error) {
      throw MiniProgramEmbeddingInitException(error.message);
    }
    return MiniProgramEmbeddingInitResult(
      projectRootPath: projectRootPath,
      repoRootPath: repoRootPath,
      packageName: packageName,
      hostAppId: resolvedHostAppId,
      hostVersion: resolvedHostVersion,
      nativeRoutePath: normalizedRoutePath,
      createdPaths: writes.keys.toList(),
    );
  }

  await integrationRootDir.create(recursive: true);

  final createdPaths = <String>[];
  if (updatedPubspecSource != pubspecSource) {
    await pubspecFile.writeAsString(updatedPubspecSource);
    createdPaths.add(pubspecFile.path);
  }
  for (final entry in scaffoldGeneratedFiles.entries) {
    final file = File(entry.key);
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    createdPaths.add(file.path);
  }
  for (final entry in endpointImportGeneratedFiles.entries) {
    final file = File(entry.key);
    if (await file.exists()) {
      continue;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    createdPaths.add(file.path);
  }
  for (final entry in hostOwnedFiles.entries) {
    final file = File(entry.key);
    if (await file.exists()) {
      continue;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    createdPaths.add(file.path);
  }
  for (final entry in platformIntegrationFiles.entries) {
    final file = File(entry.key);
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    createdPaths.add(file.path);
  }

  return MiniProgramEmbeddingInitResult(
    projectRootPath: projectRootPath,
    repoRootPath: repoRootPath,
    packageName: packageName,
    hostAppId: resolvedHostAppId,
    hostVersion: resolvedHostVersion,
    nativeRoutePath: normalizedRoutePath,
    createdPaths: createdPaths,
  );
}

Future<bool> _directoryHasEntries(Directory directory) async {
  await for (final _ in directory.list(followLinks: false)) {
    return true;
  }
  return false;
}

String _normalizeRoutePath(String rawRoutePath) {
  final trimmed = rawRoutePath.trim();
  if (trimmed.isEmpty) {
    throw const MiniProgramEmbeddingInitException(
      'Native route path must not be blank.',
    );
  }
  return trimmed.startsWith('/') ? trimmed : '/$trimmed';
}
