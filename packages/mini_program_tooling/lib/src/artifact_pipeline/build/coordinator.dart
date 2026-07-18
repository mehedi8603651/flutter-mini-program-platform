import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../../mini_program_builder.dart';
import '../models.dart';
import '../shared/constants.dart';
import '../shared/data_assets.dart';
import '../shared/document_validation.dart';
import '../shared/files.dart';
import '../shared/json_io.dart';
import '../shared/paths.dart';
import 'catalog.dart';
import 'checksums.dart';

Future<MiniProgramArtifactBuildResult> buildPortableMiniProgramArtifact(
  MiniProgramBuilder builder,
  MiniProgramArtifactBuildRequest request,
) async {
  late final MiniProgramBuildResult buildResult;
  try {
    buildResult = await builder.build(
      MiniProgramBuildRequest(
        repoRootPath: request.repoRootPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: request.miniProgramRootPath,
        mpBuildScriptPath: request.mpBuildScriptPath,
        skipPubGet: request.skipPubGet,
      ),
    );
  } on MiniProgramBuildException catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.buildFailed,
      message: error.message,
    );
  }

  final miniProgramRoot = path.normalize(
    path.absolute(buildResult.miniProgramRootPath),
  );
  final artifactsRoot = path.normalize(
    path.absolute(
      request.artifactsRootPath?.trim().isNotEmpty == true
          ? request.artifactsRootPath!.trim()
          : path.join(miniProgramRoot, 'artifacts'),
    ),
  );
  final appArtifacts = path.join(artifactsRoot, buildResult.miniProgramId);
  assertArtifactPathContained(appArtifacts, artifactsRoot);

  String? stagingRootPath;
  String? stagingPath;
  try {
    final sourceManifestPath = path.join(miniProgramRoot, 'manifest.json');
    final sourceManifest = await readArtifactJsonMap(
      sourceManifestPath,
      code: MiniProgramArtifactErrorCodes.manifestInvalid,
      label: 'Source manifest',
    );
    final manifest = parseArtifactManifest(sourceManifest, sourceManifestPath);
    final version = manifest.version.trim();
    final parsedVersion = parseArtifactVersion(version, sourceManifestPath);
    if (manifest.id != buildResult.miniProgramId) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.manifestInvalid,
        message:
            'Manifest id "${manifest.id}" does not match build appId '
            '"${buildResult.miniProgramId}".',
      );
    }

    await Directory(appArtifacts).create(recursive: true);
    final stagingRoot = path.join(appArtifacts, '.staging');
    stagingRootPath = stagingRoot;
    await Directory(stagingRoot).create(recursive: true);
    stagingPath = path.join(
      stagingRoot,
      '$version-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    final staging = Directory(stagingPath);
    await staging.create(recursive: true);

    final generatedManifest = <String, Object?>{
      ...sourceManifest,
      'artifactLayoutVersion': artifactLayoutVersion,
    };
    await writeCanonicalArtifactJson(
      path.join(stagingPath, 'manifest.json'),
      generatedManifest,
    );

    final screensTarget = path.join(stagingPath, 'screens');
    await Directory(screensTarget).create(recursive: true);
    final screenFiles = await listArtifactFiles(
      buildResult.screensDirectoryPath,
      recursive: false,
      required: true,
    );
    if (screenFiles.isEmpty) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message:
            'Development build produced no screen JSON files: '
            '${buildResult.screensDirectoryPath}',
      );
    }
    for (final screenFile in screenFiles) {
      if (path.extension(screenFile.path).toLowerCase() != '.json') {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message:
              'Unexpected non-JSON screen build output: ${screenFile.path}',
        );
      }
      final screenId = path.basenameWithoutExtension(screenFile.path);
      final screenJson = await readArtifactJsonMap(
        screenFile.path,
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        label: 'Built screen',
      );
      validateArtifactScreen(
        screenJson,
        expectedScreenId: screenId,
        expectedSchemaVersion: buildResult.screenSchemaVersion ?? 1,
        path: screenFile.path,
      );
      await writeCanonicalArtifactJson(
        path.join(screensTarget, '$screenId.json'),
        screenJson,
      );
    }
    if (!File(
      path.join(screensTarget, '${manifest.entry}.json'),
    ).existsSync()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message:
            'Manifest entry screen "${manifest.entry}" was not produced by '
            'the build.',
      );
    }

    final assetsTarget = path.join(stagingPath, 'assets');
    await Directory(assetsTarget).create(recursive: true);
    final assetsSource = path.join(miniProgramRoot, 'assets');
    if (await Directory(assetsSource).exists()) {
      await copyArtifactDirectoryFiles(
        sourceRoot: assetsSource,
        targetRoot: assetsTarget,
      );
    }
    await validateReferencedArtifactJsonAssets(
      screenFiles: screenFiles,
      assetsRoot: assetsTarget,
    );

    final publisherBackendSourcePath = path.join(
      miniProgramRoot,
      'publisher_backend.json',
    );
    MiniProgramPublisherBackendContract? publisherBackendContract;
    if (await File(publisherBackendSourcePath).exists()) {
      publisherBackendContract = await readArtifactPublisherBackend(
        publisherBackendSourcePath,
        expectedAppId: buildResult.miniProgramId,
      );
      await writeCanonicalArtifactJson(
        path.join(stagingPath, 'publisher_backend.json'),
        publisherBackendContract.toJson(),
      );
    }

    await writeCanonicalArtifactJson(path.join(stagingPath, 'release.json'), {
      'schemaVersion': 1,
      'artifactLayoutVersion': artifactLayoutVersion,
      'appId': buildResult.miniProgramId,
      'version': version,
      'manifest': 'manifest.json',
      'screensPath': 'screens/',
      'assetsPath': 'assets/',
      if (publisherBackendContract != null)
        'publisherBackend': 'publisher_backend.json',
      'checksums': 'checksums.json',
    });

    await writeArtifactChecksums(stagingPath);

    final versionArtifacts = path.join(appArtifacts, version);
    assertArtifactPathContained(versionArtifacts, appArtifacts);
    var created = true;
    final existingVersion = Directory(versionArtifacts);
    if (await existingVersion.exists()) {
      if (!await artifactDirectoriesEqual(stagingPath, versionArtifacts)) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.versionConflict,
          message:
              'Artifact version $version already exists with different '
              'content. Change manifest.json to a new semantic version.',
          details: <String, Object?>{
            'appId': buildResult.miniProgramId,
            'version': version,
            'path': versionArtifacts,
          },
        );
      }
      created = false;
      await staging.delete(recursive: true);
      stagingPath = null;
    } else {
      await staging.rename(versionArtifacts);
      stagingPath = null;
    }

    final versions = await discoverBuildArtifactVersions(appArtifacts);
    final latestPath = path.join(appArtifacts, 'latest.json');
    final catalogPath = path.join(appArtifacts, 'catalog.json');
    final existingLatestVersion = await readExistingLatestArtifactVersion(
      latestPath,
      expectedAppId: buildResult.miniProgramId,
    );
    final shouldSelectLatest =
        existingLatestVersion == null || parsedVersion >= existingLatestVersion;

    await writeCanonicalArtifactJsonAtomic(catalogPath, {
      'schemaVersion': 1,
      'artifactLayoutVersion': artifactLayoutVersion,
      'appId': buildResult.miniProgramId,
      'latestVersion': shouldSelectLatest
          ? version
          : existingLatestVersion.toString(),
      'versions': versions,
    });
    var latestUpdated = false;
    if (shouldSelectLatest) {
      latestUpdated = await writeCanonicalArtifactJsonAtomic(
        latestPath,
        generatedManifest,
      );
    }

    final versionFiles = await listArtifactFiles(
      versionArtifacts,
      recursive: true,
    );
    var totalBytes = 0;
    for (final file in versionFiles) {
      totalBytes += await file.length();
    }
    return MiniProgramArtifactBuildResult(
      buildResult: buildResult,
      artifactsRootPath: artifactsRoot,
      appArtifactsPath: appArtifacts,
      versionArtifactsPath: versionArtifacts,
      latestManifestPath: latestPath,
      catalogPath: catalogPath,
      version: version,
      fileCount: versionFiles.length,
      totalBytes: totalBytes,
      created: created,
      latestUpdated: latestUpdated,
    );
  } on MiniProgramArtifactException {
    rethrow;
  } on FileSystemException catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.ioFailed,
      message: 'Artifact file operation failed: ${error.message}',
      details: <String, Object?>{'path': error.path},
    );
  } finally {
    if (stagingPath != null) {
      final staging = Directory(stagingPath);
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
    if (stagingRootPath != null) {
      final stagingRoot = Directory(stagingRootPath);
      try {
        if (await stagingRoot.exists() &&
            await stagingRoot.list(followLinks: false).isEmpty) {
          await stagingRoot.delete();
        }
      } on FileSystemException {
        // Another build may still own the shared staging directory.
      }
    }
  }
}
