import 'dart:io';

import 'package:path/path.dart' as path;

import '../models.dart';
import '../shared/constants.dart';
import '../shared/data_assets.dart';
import '../shared/document_validation.dart';
import '../shared/files.dart';
import '../shared/json_io.dart';
import '../shared/metrics.dart';
import 'checksums.dart';

Future<ArtifactMetrics> verifyArtifactVersion(
  String versionRoot, {
  required String expectedAppId,
  required String expectedVersion,
}) async {
  final manifestPath = path.join(versionRoot, 'manifest.json');
  final manifestJson = await readArtifactJsonMap(
    manifestPath,
    code: MiniProgramArtifactErrorCodes.fileMissing,
    label: 'Version manifest',
  );
  validateArtifactLayout(manifestJson, manifestPath);
  final manifest = parseArtifactManifest(manifestJson, manifestPath);
  if (manifest.id != expectedAppId || manifest.version != expectedVersion) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.manifestInvalid,
      message:
          'Version manifest identity does not match its directory: '
          '$manifestPath',
    );
  }
  parseArtifactVersion(manifest.version, manifestPath);

  final releasePath = path.join(versionRoot, 'release.json');
  final release = await readArtifactJsonMap(
    releasePath,
    code: MiniProgramArtifactErrorCodes.fileMissing,
    label: 'Release metadata',
  );
  final expectedRelease = <String, Object?>{
    'schemaVersion': 1,
    'artifactLayoutVersion': artifactLayoutVersion,
    'appId': expectedAppId,
    'version': expectedVersion,
    'manifest': 'manifest.json',
    'screensPath': 'screens/',
    'assetsPath': 'assets/',
    if (await File(path.join(versionRoot, 'publisher_backend.json')).exists())
      'publisherBackend': 'publisher_backend.json',
    'checksums': 'checksums.json',
  };
  if (canonicalArtifactJson(release) !=
      canonicalArtifactJson(expectedRelease)) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'Release metadata is invalid: $releasePath',
    );
  }

  final publisherBackendPath = path.join(versionRoot, 'publisher_backend.json');
  if (await File(publisherBackendPath).exists()) {
    await readArtifactPublisherBackend(
      publisherBackendPath,
      expectedAppId: expectedAppId,
    );
  }

  final metrics = await verifyArtifactChecksums(versionRoot);

  final screensPath = path.join(versionRoot, 'screens');
  final screenFiles = await listArtifactFiles(
    screensPath,
    recursive: false,
    required: true,
  );
  for (final screenFile in screenFiles) {
    if (path.extension(screenFile.path).toLowerCase() != '.json') {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Unexpected file in screens directory: ${screenFile.path}',
      );
    }
    final screenId = path.basenameWithoutExtension(screenFile.path);
    final screenJson = await readArtifactJsonMap(
      screenFile.path,
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      label: 'Artifact screen',
    );
    validateArtifactScreen(
      screenJson,
      expectedScreenId: screenId,
      expectedSchemaVersion: manifest.screenSchemaVersion ?? 1,
      path: screenFile.path,
    );
  }
  if (!File(path.join(screensPath, '${manifest.entry}.json')).existsSync()) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.fileMissing,
      message: 'Artifact entry screen is missing for $expectedVersion.',
    );
  }
  if (!await Directory(path.join(versionRoot, 'assets')).exists()) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.fileMissing,
      message: 'Artifact assets directory is missing for $expectedVersion.',
    );
  }
  await validateReferencedArtifactJsonAssets(
    screenFiles: screenFiles,
    assetsRoot: path.join(versionRoot, 'assets'),
  );
  return metrics;
}
