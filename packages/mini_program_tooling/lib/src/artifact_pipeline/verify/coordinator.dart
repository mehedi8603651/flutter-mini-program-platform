import 'dart:io';

import 'package:path/path.dart' as path;

import '../models.dart';
import '../shared/constants.dart';
import '../shared/document_validation.dart';
import '../shared/json_io.dart';
import '../shared/paths.dart';
import 'version.dart';
import 'versions.dart';

Future<MiniProgramArtifactVerifyResult> verifyPortableMiniProgramArtifact(
  MiniProgramArtifactVerifyRequest request,
) async {
  final miniProgramRoot = path.normalize(
    path.absolute(request.miniProgramRootPath),
  );
  try {
    final sourceManifestPath = path.join(miniProgramRoot, 'manifest.json');
    final sourceManifest = await readArtifactJsonMap(
      sourceManifestPath,
      code: MiniProgramArtifactErrorCodes.manifestInvalid,
      label: 'Source manifest',
    );
    final appId = request.miniProgramId?.trim().isNotEmpty == true
        ? request.miniProgramId!.trim()
        : '${sourceManifest['id'] ?? ''}'.trim();
    if (appId.isEmpty) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.manifestInvalid,
        message: 'Could not resolve an appId for artifact verification.',
      );
    }
    final artifactsRoot = path.normalize(
      path.absolute(
        request.artifactsRootPath?.trim().isNotEmpty == true
            ? request.artifactsRootPath!.trim()
            : path.join(miniProgramRoot, 'artifacts'),
      ),
    );
    final appArtifacts = path.join(artifactsRoot, appId);
    assertArtifactPathContained(appArtifacts, artifactsRoot);
    if (!await Directory(appArtifacts).exists()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message: 'App artifact directory was not found: $appArtifacts',
      );
    }

    final latestPath = path.join(appArtifacts, 'latest.json');
    final latestJson = await readArtifactJsonMap(
      latestPath,
      code: MiniProgramArtifactErrorCodes.latestInvalid,
      label: 'Latest manifest',
    );
    validateArtifactLayout(latestJson, latestPath);
    final latestManifest = parseArtifactManifest(latestJson, latestPath);
    if (latestManifest.id != appId) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.latestInvalid,
        message:
            'Latest manifest appId "${latestManifest.id}" does not match '
            '"$appId".',
      );
    }
    parseArtifactVersion(latestManifest.version, latestPath);

    final versionNames = await discoverVerifiedArtifactVersions(appArtifacts);
    if (versionNames.isEmpty) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'No immutable artifact versions were found: $appArtifacts',
      );
    }
    if (!versionNames.contains(latestManifest.version)) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.latestInvalid,
        message:
            'Latest manifest references missing version '
            '"${latestManifest.version}".',
      );
    }

    var fileCount = 0;
    var totalBytes = 0;
    for (final version in versionNames) {
      final metrics = await verifyArtifactVersion(
        path.join(appArtifacts, version),
        expectedAppId: appId,
        expectedVersion: version,
      );
      fileCount += metrics.fileCount;
      totalBytes += metrics.totalBytes;
    }

    final versionManifestPath = path.join(
      appArtifacts,
      latestManifest.version,
      'manifest.json',
    );
    final versionManifestJson = await readArtifactJsonMap(
      versionManifestPath,
      code: MiniProgramArtifactErrorCodes.fileMissing,
      label: 'Latest version manifest',
    );
    if (canonicalArtifactJson(latestJson) !=
        canonicalArtifactJson(versionManifestJson)) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.latestInvalid,
        message:
            'latest.json does not match '
            '${latestManifest.version}/manifest.json.',
      );
    }

    final catalogPath = path.join(appArtifacts, 'catalog.json');
    final catalog = await readArtifactJsonMap(
      catalogPath,
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      label: 'Artifact catalog',
    );
    if (catalog['schemaVersion'] != 1 ||
        catalog['artifactLayoutVersion'] != artifactLayoutVersion ||
        catalog['appId'] != appId ||
        catalog['latestVersion'] != latestManifest.version) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Artifact catalog metadata is inconsistent: $catalogPath',
      );
    }
    final catalogVersions = catalog['versions'];
    if (catalogVersions is! List ||
        canonicalArtifactJson(catalogVersions) !=
            canonicalArtifactJson(versionNames)) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Artifact catalog versions do not match version folders.',
      );
    }

    return MiniProgramArtifactVerifyResult(
      artifactsRootPath: artifactsRoot,
      appArtifactsPath: appArtifacts,
      miniProgramId: appId,
      latestVersion: latestManifest.version,
      versions: versionNames,
      fileCount: fileCount,
      totalBytes: totalBytes,
    );
  } on MiniProgramArtifactException {
    rethrow;
  } on FileSystemException catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.ioFailed,
      message: 'Artifact verification could not read files: ${error.message}',
      details: <String, Object?>{'path': error.path},
    );
  }
}
