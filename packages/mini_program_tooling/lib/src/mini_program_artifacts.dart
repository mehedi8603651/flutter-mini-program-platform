import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'mini_program_builder.dart';

abstract final class MiniProgramArtifactErrorCodes {
  static const buildFailed = 'artifact_build_failed';
  static const manifestInvalid = 'artifact_manifest_invalid';
  static const versionInvalid = 'artifact_version_invalid';
  static const versionConflict = 'artifact_version_conflict';
  static const structureInvalid = 'artifact_structure_invalid';
  static const fileMissing = 'artifact_file_missing';
  static const checksumMismatch = 'artifact_checksum_mismatch';
  static const latestInvalid = 'artifact_latest_invalid';
  static const publisherBackendInvalid = 'artifact_publisher_backend_invalid';
  static const pathUnsafe = 'artifact_path_unsafe';
  static const ioFailed = 'artifact_io_failed';
}

class MiniProgramArtifactException implements Exception {
  const MiniProgramArtifactException({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => '[$code] $message';
}

class MiniProgramArtifactBuildRequest {
  const MiniProgramArtifactBuildRequest({
    this.repoRootPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.artifactsRootPath,
    this.mpBuildScriptPath,
    this.skipPubGet = false,
  });

  final String? repoRootPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? artifactsRootPath;
  final String? mpBuildScriptPath;
  final bool skipPubGet;
}

class MiniProgramArtifactBuildResult {
  const MiniProgramArtifactBuildResult({
    required this.buildResult,
    required this.artifactsRootPath,
    required this.appArtifactsPath,
    required this.versionArtifactsPath,
    required this.latestManifestPath,
    required this.catalogPath,
    required this.version,
    required this.fileCount,
    required this.totalBytes,
    required this.created,
    required this.latestUpdated,
  });

  final MiniProgramBuildResult buildResult;
  final String artifactsRootPath;
  final String appArtifactsPath;
  final String versionArtifactsPath;
  final String latestManifestPath;
  final String catalogPath;
  final String version;
  final int fileCount;
  final int totalBytes;
  final bool created;
  final bool latestUpdated;

  Map<String, Object?> toJson() => <String, Object?>{
    'appId': buildResult.miniProgramId,
    'version': version,
    'artifactsRootPath': artifactsRootPath,
    'appArtifactsPath': appArtifactsPath,
    'versionArtifactsPath': versionArtifactsPath,
    'latestManifestPath': latestManifestPath,
    'catalogPath': catalogPath,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
    'created': created,
    'latestUpdated': latestUpdated,
    'build': buildResult.toJson(),
  };
}

class MiniProgramArtifactVerifyRequest {
  const MiniProgramArtifactVerifyRequest({
    required this.miniProgramRootPath,
    this.miniProgramId,
    this.artifactsRootPath,
  });

  final String miniProgramRootPath;
  final String? miniProgramId;
  final String? artifactsRootPath;
}

class MiniProgramArtifactVerifyResult {
  const MiniProgramArtifactVerifyResult({
    required this.artifactsRootPath,
    required this.appArtifactsPath,
    required this.miniProgramId,
    required this.latestVersion,
    required this.versions,
    required this.fileCount,
    required this.totalBytes,
  });

  final String artifactsRootPath;
  final String appArtifactsPath;
  final String miniProgramId;
  final String latestVersion;
  final List<String> versions;
  final int fileCount;
  final int totalBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'valid': true,
    'appId': miniProgramId,
    'latestVersion': latestVersion,
    'versions': versions,
    'artifactsRootPath': artifactsRootPath,
    'appArtifactsPath': appArtifactsPath,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
  };
}

class MiniProgramArtifactBuilder {
  const MiniProgramArtifactBuilder({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
  }) : _builder = builder;

  static const int artifactLayoutVersion = 1;

  final MiniProgramBuilder _builder;

  Future<MiniProgramArtifactBuildResult> build(
    MiniProgramArtifactBuildRequest request,
  ) async {
    late final MiniProgramBuildResult buildResult;
    try {
      buildResult = await _builder.build(
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

    final miniProgramRoot = p.normalize(
      p.absolute(buildResult.miniProgramRootPath),
    );
    final artifactsRoot = p.normalize(
      p.absolute(
        request.artifactsRootPath?.trim().isNotEmpty == true
            ? request.artifactsRootPath!.trim()
            : p.join(miniProgramRoot, 'artifacts'),
      ),
    );
    final appArtifacts = p.join(artifactsRoot, buildResult.miniProgramId);
    _assertContained(appArtifacts, artifactsRoot);

    String? stagingRootPath;
    String? stagingPath;
    try {
      final sourceManifestPath = p.join(miniProgramRoot, 'manifest.json');
      final sourceManifest = await _readJsonMap(
        sourceManifestPath,
        code: MiniProgramArtifactErrorCodes.manifestInvalid,
        label: 'Source manifest',
      );
      final manifest = _parseManifest(sourceManifest, sourceManifestPath);
      final version = manifest.version.trim();
      final parsedVersion = _parseVersion(version, sourceManifestPath);
      if (manifest.id != buildResult.miniProgramId) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.manifestInvalid,
          message:
              'Manifest id "${manifest.id}" does not match build appId '
              '"${buildResult.miniProgramId}".',
        );
      }

      await Directory(appArtifacts).create(recursive: true);
      final stagingRoot = p.join(appArtifacts, '.staging');
      stagingRootPath = stagingRoot;
      await Directory(stagingRoot).create(recursive: true);
      stagingPath = p.join(
        stagingRoot,
        '$version-$pid-${DateTime.now().microsecondsSinceEpoch}',
      );
      final staging = Directory(stagingPath);
      await staging.create(recursive: true);

      final generatedManifest = <String, Object?>{
        ...sourceManifest,
        'artifactLayoutVersion': artifactLayoutVersion,
      };
      await _writeCanonicalJson(
        p.join(stagingPath, 'manifest.json'),
        generatedManifest,
      );

      final screensTarget = p.join(stagingPath, 'screens');
      await Directory(screensTarget).create(recursive: true);
      final screenFiles = await _listFiles(
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
        if (p.extension(screenFile.path).toLowerCase() != '.json') {
          throw MiniProgramArtifactException(
            code: MiniProgramArtifactErrorCodes.structureInvalid,
            message:
                'Unexpected non-JSON screen build output: ${screenFile.path}',
          );
        }
        final screenId = p.basenameWithoutExtension(screenFile.path);
        final screenJson = await _readJsonMap(
          screenFile.path,
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          label: 'Built screen',
        );
        _validateScreen(
          screenJson,
          expectedScreenId: screenId,
          expectedSchemaVersion: buildResult.screenSchemaVersion ?? 1,
          path: screenFile.path,
        );
        await _writeCanonicalJson(
          p.join(screensTarget, '$screenId.json'),
          screenJson,
        );
      }
      if (!File(p.join(screensTarget, '${manifest.entry}.json')).existsSync()) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.fileMissing,
          message:
              'Manifest entry screen "${manifest.entry}" was not produced by '
              'the build.',
        );
      }

      final assetsTarget = p.join(stagingPath, 'assets');
      await Directory(assetsTarget).create(recursive: true);
      final assetsSource = p.join(miniProgramRoot, 'assets');
      if (await Directory(assetsSource).exists()) {
        await _copyDirectoryFiles(
          sourceRoot: assetsSource,
          targetRoot: assetsTarget,
        );
      }
      await _validateReferencedJsonAssets(
        screenFiles: screenFiles,
        assetsRoot: assetsTarget,
      );

      final publisherBackendSourcePath = p.join(
        miniProgramRoot,
        'publisher_backend.json',
      );
      MiniProgramPublisherBackendContract? publisherBackendContract;
      if (await File(publisherBackendSourcePath).exists()) {
        publisherBackendContract = await _readPublisherBackendContract(
          publisherBackendSourcePath,
          expectedAppId: buildResult.miniProgramId,
        );
        await _writeCanonicalJson(
          p.join(stagingPath, 'publisher_backend.json'),
          publisherBackendContract.toJson(),
        );
      }

      await _writeCanonicalJson(p.join(stagingPath, 'release.json'), {
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

      final payloadFiles = await _listFiles(stagingPath, recursive: true);
      final checksumRecords = <Map<String, Object?>>[];
      for (final file in payloadFiles) {
        final relativePath = _relativePortablePath(file.path, stagingPath);
        if (relativePath == 'checksums.json') {
          continue;
        }
        final bytes = await file.readAsBytes();
        checksumRecords.add(<String, Object?>{
          'path': relativePath,
          'bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        });
      }
      checksumRecords.sort(
        (left, right) => '${left['path']}'.compareTo('${right['path']}'),
      );
      await _writeCanonicalJson(p.join(stagingPath, 'checksums.json'), {
        'schemaVersion': 1,
        'algorithm': 'sha256',
        'files': checksumRecords,
      });

      final versionArtifacts = p.join(appArtifacts, version);
      _assertContained(versionArtifacts, appArtifacts);
      var created = true;
      final existingVersion = Directory(versionArtifacts);
      if (await existingVersion.exists()) {
        if (!await _directoriesEqual(stagingPath, versionArtifacts)) {
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

      final versions = await _discoverVersions(appArtifacts);
      final latestPath = p.join(appArtifacts, 'latest.json');
      final catalogPath = p.join(appArtifacts, 'catalog.json');
      final existingLatestVersion = await _readExistingLatestVersion(
        latestPath,
        expectedAppId: buildResult.miniProgramId,
      );
      final shouldSelectLatest =
          existingLatestVersion == null ||
          parsedVersion >= existingLatestVersion;

      await _writeCanonicalJsonAtomic(catalogPath, {
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
        latestUpdated = await _writeCanonicalJsonAtomic(
          latestPath,
          generatedManifest,
        );
      }

      final versionFiles = await _listFiles(versionArtifacts, recursive: true);
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

  Future<Version?> _readExistingLatestVersion(
    String latestPath, {
    required String expectedAppId,
  }) async {
    final latestFile = File(latestPath);
    if (!await latestFile.exists()) {
      return null;
    }
    final latest = await _readJsonMap(
      latestPath,
      code: MiniProgramArtifactErrorCodes.latestInvalid,
      label: 'Existing latest manifest',
    );
    final id = '${latest['id'] ?? ''}'.trim();
    if (id != expectedAppId) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.latestInvalid,
        message:
            'Existing latest manifest appId "$id" does not match '
            '"$expectedAppId".',
      );
    }
    return _parseVersion('${latest['version'] ?? ''}', latestPath);
  }

  Future<List<String>> _discoverVersions(String appArtifactsPath) async {
    final versions = <Version, String>{};
    await for (final entity in Directory(
      appArtifactsPath,
    ).list(followLinks: false)) {
      if (entity is! Directory || p.basename(entity.path).startsWith('.')) {
        continue;
      }
      final rawVersion = p.basename(entity.path);
      try {
        versions[Version.parse(rawVersion)] = rawVersion;
      } on FormatException {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Unexpected directory in app artifacts: ${entity.path}',
        );
      }
    }
    final sorted = versions.keys.toList()..sort();
    return sorted.map((version) => versions[version]!).toList(growable: false);
  }
}

class MiniProgramArtifactVerifier {
  const MiniProgramArtifactVerifier();

  Future<MiniProgramArtifactVerifyResult> verify(
    MiniProgramArtifactVerifyRequest request,
  ) async {
    final miniProgramRoot = p.normalize(
      p.absolute(request.miniProgramRootPath),
    );
    try {
      final sourceManifestPath = p.join(miniProgramRoot, 'manifest.json');
      final sourceManifest = await _readJsonMap(
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
      final artifactsRoot = p.normalize(
        p.absolute(
          request.artifactsRootPath?.trim().isNotEmpty == true
              ? request.artifactsRootPath!.trim()
              : p.join(miniProgramRoot, 'artifacts'),
        ),
      );
      final appArtifacts = p.join(artifactsRoot, appId);
      _assertContained(appArtifacts, artifactsRoot);
      if (!await Directory(appArtifacts).exists()) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.fileMissing,
          message: 'App artifact directory was not found: $appArtifacts',
        );
      }

      final latestPath = p.join(appArtifacts, 'latest.json');
      final latestJson = await _readJsonMap(
        latestPath,
        code: MiniProgramArtifactErrorCodes.latestInvalid,
        label: 'Latest manifest',
      );
      _validateLayout(latestJson, latestPath);
      final latestManifest = _parseManifest(latestJson, latestPath);
      if (latestManifest.id != appId) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.latestInvalid,
          message:
              'Latest manifest appId "${latestManifest.id}" does not match '
              '"$appId".',
        );
      }
      _parseVersion(latestManifest.version, latestPath);

      final versionNames = await _discoverVersionNames(appArtifacts);
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
        final metrics = await _verifyVersion(
          p.join(appArtifacts, version),
          expectedAppId: appId,
          expectedVersion: version,
        );
        fileCount += metrics.fileCount;
        totalBytes += metrics.totalBytes;
      }

      final versionManifestPath = p.join(
        appArtifacts,
        latestManifest.version,
        'manifest.json',
      );
      final versionManifestJson = await _readJsonMap(
        versionManifestPath,
        code: MiniProgramArtifactErrorCodes.fileMissing,
        label: 'Latest version manifest',
      );
      if (_canonicalJson(latestJson) != _canonicalJson(versionManifestJson)) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.latestInvalid,
          message:
              'latest.json does not match '
              '${latestManifest.version}/manifest.json.',
        );
      }

      final catalogPath = p.join(appArtifacts, 'catalog.json');
      final catalog = await _readJsonMap(
        catalogPath,
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        label: 'Artifact catalog',
      );
      if (catalog['schemaVersion'] != 1 ||
          catalog['artifactLayoutVersion'] !=
              MiniProgramArtifactBuilder.artifactLayoutVersion ||
          catalog['appId'] != appId ||
          catalog['latestVersion'] != latestManifest.version) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Artifact catalog metadata is inconsistent: $catalogPath',
        );
      }
      final catalogVersions = catalog['versions'];
      if (catalogVersions is! List ||
          _canonicalJson(catalogVersions) != _canonicalJson(versionNames)) {
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

  Future<_ArtifactMetrics> _verifyVersion(
    String versionRoot, {
    required String expectedAppId,
    required String expectedVersion,
  }) async {
    final manifestPath = p.join(versionRoot, 'manifest.json');
    final manifestJson = await _readJsonMap(
      manifestPath,
      code: MiniProgramArtifactErrorCodes.fileMissing,
      label: 'Version manifest',
    );
    _validateLayout(manifestJson, manifestPath);
    final manifest = _parseManifest(manifestJson, manifestPath);
    if (manifest.id != expectedAppId || manifest.version != expectedVersion) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.manifestInvalid,
        message:
            'Version manifest identity does not match its directory: '
            '$manifestPath',
      );
    }
    _parseVersion(manifest.version, manifestPath);

    final releasePath = p.join(versionRoot, 'release.json');
    final release = await _readJsonMap(
      releasePath,
      code: MiniProgramArtifactErrorCodes.fileMissing,
      label: 'Release metadata',
    );
    final expectedRelease = <String, Object?>{
      'schemaVersion': 1,
      'artifactLayoutVersion': MiniProgramArtifactBuilder.artifactLayoutVersion,
      'appId': expectedAppId,
      'version': expectedVersion,
      'manifest': 'manifest.json',
      'screensPath': 'screens/',
      'assetsPath': 'assets/',
      if (await File(p.join(versionRoot, 'publisher_backend.json')).exists())
        'publisherBackend': 'publisher_backend.json',
      'checksums': 'checksums.json',
    };
    if (_canonicalJson(release) != _canonicalJson(expectedRelease)) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Release metadata is invalid: $releasePath',
      );
    }

    final publisherBackendPath = p.join(versionRoot, 'publisher_backend.json');
    if (await File(publisherBackendPath).exists()) {
      await _readPublisherBackendContract(
        publisherBackendPath,
        expectedAppId: expectedAppId,
      );
    }

    final checksumsPath = p.join(versionRoot, 'checksums.json');
    final checksums = await _readJsonMap(
      checksumsPath,
      code: MiniProgramArtifactErrorCodes.fileMissing,
      label: 'Checksums document',
    );
    if (checksums['schemaVersion'] != 1 || checksums['algorithm'] != 'sha256') {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Unsupported checksums document: $checksumsPath',
      );
    }
    final rawRecords = checksums['files'];
    if (rawRecords is! List || rawRecords.isEmpty) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Checksums document must contain file records.',
      );
    }

    final records = <String, Map<String, Object?>>{};
    for (final rawRecord in rawRecords) {
      if (rawRecord is! Map) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Checksums document contains a non-object record.',
        );
      }
      final record = rawRecord.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final path = '${record['path'] ?? ''}'.trim();
      _validatePortableRelativePath(path);
      if (path == 'checksums.json' || records.containsKey(path)) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Invalid or duplicate checksum path: $path',
        );
      }
      if (record['bytes'] is! int ||
          (record['bytes'] as int) < 0 ||
          !_isSha256('${record['sha256'] ?? ''}')) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Invalid checksum record for: $path',
        );
      }
      records[path] = record;
    }

    final files = await _listFiles(versionRoot, recursive: true);
    final actualPaths = <String>{};
    var totalBytes = 0;
    for (final file in files) {
      final relativePath = _relativePortablePath(file.path, versionRoot);
      totalBytes += await file.length();
      if (relativePath == 'checksums.json') {
        continue;
      }
      actualPaths.add(relativePath);
      final record = records[relativePath];
      if (record == null) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Artifact file is not recorded in checksums: $relativePath',
        );
      }
      final bytes = await file.readAsBytes();
      final actualHash = sha256.convert(bytes).toString();
      if (record['bytes'] != bytes.length || record['sha256'] != actualHash) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.checksumMismatch,
          message: 'Artifact checksum mismatch: $relativePath',
          details: <String, Object?>{
            'path': relativePath,
            'expectedBytes': record['bytes'],
            'actualBytes': bytes.length,
            'expectedSha256': record['sha256'],
            'actualSha256': actualHash,
          },
        );
      }
    }
    if (actualPaths.length != records.length ||
        !actualPaths.containsAll(records.keys)) {
      final missing = records.keys
          .where((path) => !actualPaths.contains(path))
          .toList();
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message:
            'Checksums reference missing artifact files: ${missing.join(', ')}',
      );
    }

    final screensPath = p.join(versionRoot, 'screens');
    final screenFiles = await _listFiles(
      screensPath,
      recursive: false,
      required: true,
    );
    for (final screenFile in screenFiles) {
      if (p.extension(screenFile.path).toLowerCase() != '.json') {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message: 'Unexpected file in screens directory: ${screenFile.path}',
        );
      }
      final screenId = p.basenameWithoutExtension(screenFile.path);
      final screenJson = await _readJsonMap(
        screenFile.path,
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        label: 'Artifact screen',
      );
      _validateScreen(
        screenJson,
        expectedScreenId: screenId,
        expectedSchemaVersion: manifest.screenSchemaVersion ?? 1,
        path: screenFile.path,
      );
    }
    if (!File(p.join(screensPath, '${manifest.entry}.json')).existsSync()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message: 'Artifact entry screen is missing for $expectedVersion.',
      );
    }
    if (!await Directory(p.join(versionRoot, 'assets')).exists()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message: 'Artifact assets directory is missing for $expectedVersion.',
      );
    }
    await _validateReferencedJsonAssets(
      screenFiles: screenFiles,
      assetsRoot: p.join(versionRoot, 'assets'),
    );
    return _ArtifactMetrics(fileCount: files.length, totalBytes: totalBytes);
  }

  Future<List<String>> _discoverVersionNames(String appArtifactsPath) async {
    final versions = <Version, String>{};
    await for (final entity in Directory(
      appArtifactsPath,
    ).list(followLinks: false)) {
      if (entity is Link) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.pathUnsafe,
          message:
              'Symbolic links are not allowed in artifacts: ${entity.path}',
        );
      }
      if (entity is! Directory || p.basename(entity.path).startsWith('.')) {
        continue;
      }
      final rawVersion = p.basename(entity.path);
      versions[_parseVersion(rawVersion, entity.path)] = rawVersion;
    }
    final sorted = versions.keys.toList()..sort();
    return sorted.map((version) => versions[version]!).toList(growable: false);
  }
}

class _ArtifactMetrics {
  const _ArtifactMetrics({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

const int _jsonDataAssetMaxBytes = 2 * 1024 * 1024;
const int _jsonDataAssetMaxDepth = 32;
const int _jsonDataAssetMaxMembers = 50000;
const int _jsonDataAssetPathMaxLength = 256;

Future<void> _validateReferencedJsonAssets({
  required List<File> screenFiles,
  required String assetsRoot,
}) async {
  final references = <String, String>{};
  for (final screenFile in screenFiles) {
    final screen = await _readJsonMap(
      screenFile.path,
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      label: 'Screen data reference source',
    );
    void visit(Object? value, String jsonPath) {
      if (value is Map) {
        final map = value.map((key, item) => MapEntry(key.toString(), item));
        if (map['type'] == 'data.loadJsonAsset') {
          final props = map['props'];
          final asset = props is Map ? props['asset'] : null;
          if (asset is! String || asset.trim().isEmpty) {
            throw MiniProgramArtifactException(
              code: MiniProgramArtifactErrorCodes.structureInvalid,
              message:
                  'data.loadJsonAsset requires a static asset path in '
                  '${screenFile.path} at $jsonPath.',
            );
          }
          references.putIfAbsent(asset, () => '${screenFile.path}:$jsonPath');
        }
        for (final entry in map.entries) {
          visit(entry.value, '$jsonPath.${entry.key}');
        }
      } else if (value is List) {
        for (var index = 0; index < value.length; index += 1) {
          visit(value[index], '$jsonPath[$index]');
        }
      }
    }

    visit(screen, r'$');
  }

  final normalizedAssetsRoot = p.normalize(p.absolute(assetsRoot));
  for (final entry in references.entries) {
    final asset = entry.key;
    final validPath =
        asset.length <= _jsonDataAssetPathMaxLength &&
        RegExp(
          r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
        ).hasMatch(asset) &&
        !asset.contains('..');
    if (!validPath) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message:
            'Unsafe JSON data asset path "$asset" referenced by ${entry.value}.',
      );
    }
    final assetPath = p.normalize(
      p.absolute(
        p.joinAll(<String>[normalizedAssetsRoot, ...asset.split('/')]),
      ),
    );
    _assertContained(assetPath, normalizedAssetsRoot);
    final file = File(assetPath);
    if (!await file.exists()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message:
            'Referenced JSON data asset was not found: $asset '
            '(from ${entry.value}).',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > _jsonDataAssetMaxBytes) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message:
            'JSON data asset "$asset" exceeds the '
            '$_jsonDataAssetMaxBytes byte limit.',
      );
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (error) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Referenced JSON data asset is malformed: $asset\n$error',
      );
    }
    if (decoded is! Map && decoded is! List) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'JSON data asset root must be an object or list: $asset',
      );
    }
    var members = 0;
    void validateValue(Object? value, int depth) {
      if (depth > _jsonDataAssetMaxDepth) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message:
              'JSON data asset "$asset" exceeds depth '
              '$_jsonDataAssetMaxDepth.',
        );
      }
      if (value is Map) {
        members += value.length;
        for (final nested in value.values) {
          validateValue(nested, depth + 1);
        }
      } else if (value is List) {
        members += value.length;
        for (final nested in value) {
          validateValue(nested, depth + 1);
        }
      }
      if (members > _jsonDataAssetMaxMembers) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message:
              'JSON data asset "$asset" exceeds '
              '$_jsonDataAssetMaxMembers members.',
        );
      }
    }

    validateValue(decoded, 1);
  }
}

MiniProgramManifest _parseManifest(
  Map<String, dynamic> json,
  String manifestPath,
) {
  try {
    return MiniProgramManifest.fromJson(json);
  } catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.manifestInvalid,
      message: 'Manifest could not be parsed: $manifestPath\n$error',
    );
  }
}

Future<MiniProgramPublisherBackendContract> _readPublisherBackendContract(
  String contractPath, {
  required String expectedAppId,
}) async {
  final json = await _readJsonMap(
    contractPath,
    code: MiniProgramArtifactErrorCodes.publisherBackendInvalid,
    label: 'Publisher API contract',
  );
  try {
    final contract = MiniProgramPublisherBackendContract.fromJson(json);
    if (contract.appId != expectedAppId) {
      throw FormatException(
        'Publisher API contract appId "${contract.appId}" does not match '
        'artifact appId "$expectedAppId".',
      );
    }
    return contract;
  } catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.publisherBackendInvalid,
      message: 'Publisher API contract is invalid: $contractPath\n$error',
    );
  }
}

Version _parseVersion(String rawVersion, String sourcePath) {
  final value = rawVersion.trim();
  try {
    return Version.parse(value);
  } on FormatException {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.versionInvalid,
      message: 'Invalid semantic version "$value": $sourcePath',
    );
  }
}

void _validateLayout(Map<String, dynamic> json, String sourcePath) {
  if (json['artifactLayoutVersion'] !=
      MiniProgramArtifactBuilder.artifactLayoutVersion) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message:
          'Expected artifactLayoutVersion '
          '${MiniProgramArtifactBuilder.artifactLayoutVersion}: $sourcePath',
    );
  }
}

void _validateScreen(
  Map<String, dynamic> json, {
  required String expectedScreenId,
  required int expectedSchemaVersion,
  required String path,
}) {
  if (json['schemaVersion'] != expectedSchemaVersion ||
      json['screenId'] != expectedScreenId ||
      json['root'] is! Map) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'Screen identity, schemaVersion, or root is invalid: $path',
    );
  }
}

Future<Map<String, dynamic>> _readJsonMap(
  String filePath, {
  required String code,
  required String label,
}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.fileMissing,
      message: '$label was not found: $filePath',
    );
  }
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw MiniProgramArtifactException(
        code: code,
        message: '$label must be a JSON object: $filePath',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on FormatException catch (error) {
    throw MiniProgramArtifactException(
      code: code,
      message: '$label contains invalid JSON: $filePath\n${error.message}',
    );
  }
}

Future<void> _writeCanonicalJson(
  String filePath,
  Map<String, Object?> json,
) async {
  await Directory(p.dirname(filePath)).create(recursive: true);
  await File(filePath).writeAsString('${_canonicalJson(json)}\n', flush: true);
}

Future<bool> _writeCanonicalJsonAtomic(
  String filePath,
  Map<String, Object?> json,
) async {
  await Directory(p.dirname(filePath)).create(recursive: true);
  final contents = '${_canonicalJson(json)}\n';
  final target = File(filePath);
  if (await target.exists() && await target.readAsString() == contents) {
    return false;
  }
  final temporaryPath =
      '$filePath.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}';
  final temporaryFile = File(temporaryPath);
  await temporaryFile.writeAsString(contents, flush: true);
  try {
    await temporaryFile.rename(filePath);
  } on FileSystemException {
    if (await target.exists()) {
      await target.delete();
    }
    await temporaryFile.rename(filePath);
  }
  return true;
}

String _canonicalJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return <String, Object?>{
      for (final entry in entries) entry.key: _canonicalize(entry.value),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}

Future<List<File>> _listFiles(
  String directoryPath, {
  required bool recursive,
  bool required = false,
}) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) {
    if (required) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message: 'Required artifact directory was not found: $directoryPath',
      );
    }
    return <File>[];
  }
  final files = <File>[];
  await for (final entity in directory.list(
    recursive: recursive,
    followLinks: false,
  )) {
    if (entity is Link) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message: 'Symbolic links are not allowed in artifacts: ${entity.path}',
      );
    }
    if (entity is File) {
      files.add(entity);
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

Future<void> _copyDirectoryFiles({
  required String sourceRoot,
  required String targetRoot,
}) async {
  final files = await _listFiles(sourceRoot, recursive: true);
  for (final file in files) {
    final relativePath = p.relative(file.path, from: sourceRoot);
    final targetPath = p.normalize(p.join(targetRoot, relativePath));
    _assertContained(targetPath, targetRoot);
    await Directory(p.dirname(targetPath)).create(recursive: true);
    await file.copy(targetPath);
  }
}

Future<bool> _directoriesEqual(String leftPath, String rightPath) async {
  final leftFiles = await _listFiles(leftPath, recursive: true);
  final rightFiles = await _listFiles(rightPath, recursive: true);
  final leftByPath = <String, File>{
    for (final file in leftFiles)
      _relativePortablePath(file.path, leftPath): file,
  };
  final rightByPath = <String, File>{
    for (final file in rightFiles)
      _relativePortablePath(file.path, rightPath): file,
  };
  if (leftByPath.length != rightByPath.length ||
      !leftByPath.keys.toSet().containsAll(rightByPath.keys)) {
    return false;
  }
  for (final path in leftByPath.keys) {
    final left = leftByPath[path]!;
    final right = rightByPath[path]!;
    if (await left.length() != await right.length()) {
      return false;
    }
    if (sha256.convert(await left.readAsBytes()) !=
        sha256.convert(await right.readAsBytes())) {
      return false;
    }
  }
  return true;
}

String _relativePortablePath(String filePath, String rootPath) =>
    p.relative(filePath, from: rootPath).replaceAll('\\', '/');

void _validatePortableRelativePath(String value) {
  if (value.isEmpty ||
      value.contains('\\') ||
      value.startsWith('/') ||
      p.posix.isAbsolute(value) ||
      p.posix.normalize(value) != value ||
      value.split('/').any((segment) => segment.isEmpty || segment == '..')) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.pathUnsafe,
      message: 'Unsafe artifact path in checksums: $value',
    );
  }
}

void _assertContained(String candidatePath, String rootPath) {
  final candidate = p.normalize(p.absolute(candidatePath));
  final root = p.normalize(p.absolute(rootPath));
  if (candidate != root && !p.isWithin(root, candidate)) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.pathUnsafe,
      message: 'Artifact path escaped its root: $candidate',
      details: <String, Object?>{'root': root},
    );
  }
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
