import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'mini_program_builder.dart';
import 'mini_program_publisher.dart';

class MiniProgramStaticPublishRequest {
  const MiniProgramStaticPublishRequest({
    required this.repoRootPath,
    required this.outputPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.stacCliScriptPath,
    this.mpBuildScriptPath,
    this.skipBuildPubGet = false,
    this.clean = false,
  });

  final String repoRootPath;
  final String outputPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? stacCliScriptPath;
  final String? mpBuildScriptPath;
  final bool skipBuildPubGet;
  final bool clean;
}

class StaticPublishedFileRecord {
  const StaticPublishedFileRecord({
    required this.relativePath,
    required this.localSourcePath,
  });

  final String relativePath;
  final String localSourcePath;
}

class MiniProgramStaticPublishResult {
  const MiniProgramStaticPublishResult({
    required this.outputPath,
    required this.miniProgramId,
    required this.version,
    required this.buildResult,
    required this.manifestLatestPath,
    required this.manifestVersionPath,
    required this.screensDirectoryPath,
    required this.metadataReleasePath,
    required this.metadataCatalogPath,
    required this.instructionsPath,
    required this.nojekyllPath,
    required this.publishedAtUtc,
    required this.writtenFiles,
    this.cleaned = false,
    this.assetsDirectoryPath,
  });

  final String outputPath;
  final String miniProgramId;
  final String version;
  final MiniProgramBuildResult buildResult;
  final String manifestLatestPath;
  final String manifestVersionPath;
  final String screensDirectoryPath;
  final String? assetsDirectoryPath;
  final String metadataReleasePath;
  final String metadataCatalogPath;
  final String instructionsPath;
  final String nojekyllPath;
  final String publishedAtUtc;
  final List<StaticPublishedFileRecord> writtenFiles;
  final bool cleaned;
}

class MiniProgramStaticPublisher {
  const MiniProgramStaticPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
  }) : _builder = builder;

  final MiniProgramBuilder _builder;

  Future<MiniProgramStaticPublishResult> publish(
    MiniProgramStaticPublishRequest request,
  ) async {
    final repoRootPath = p.normalize(p.absolute(request.repoRootPath));
    final outputPath = p.normalize(p.absolute(request.outputPath));
    final buildResult = await _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: repoRootPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: request.miniProgramRootPath,
        stacCliScriptPath: request.stacCliScriptPath,
        mpBuildScriptPath: request.mpBuildScriptPath,
        skipPubGet: request.skipBuildPubGet,
      ),
    );

    final manifestPath = p.join(
      buildResult.miniProgramRootPath,
      'manifest.json',
    );
    final manifestJson = await _readManifestJson(manifestPath);
    final manifest = _parseManifest(manifestJson, manifestPath);
    final version = manifest.version.trim();
    if (version.isEmpty) {
      throw MiniProgramPublishException(
        'Manifest is missing a usable version: $manifestPath',
      );
    }
    _validateSemanticVersion(version, manifestPath);

    final publishedAtUtc = DateTime.now().toUtc().toIso8601String();
    final manifestDirectoryPath = p.join(
      outputPath,
      'manifests',
      buildResult.miniProgramId,
    );
    final manifestVersionsDirectoryPath = p.join(
      manifestDirectoryPath,
      'versions',
    );
    final screensDirectoryPath = p.join(
      outputPath,
      'screens',
      buildResult.miniProgramId,
      version,
    );
    final assetsSourceDirectory = Directory(
      p.join(buildResult.miniProgramRootPath, 'assets'),
    );
    final assetsDirectoryPath = await assetsSourceDirectory.exists()
        ? p.join(outputPath, 'assets', buildResult.miniProgramId, version)
        : null;
    final releaseMetadataPath = p.join(
      outputPath,
      'metadata',
      'releases',
      buildResult.miniProgramId,
      '$version.json',
    );
    final catalogMetadataPath = p.join(
      outputPath,
      'metadata',
      'catalog',
      '${buildResult.miniProgramId}.json',
    );
    final instructionsPath = p.join(outputPath, 'PUBLISH_INSTRUCTIONS.md');
    final nojekyllPath = p.join(outputPath, '.nojekyll');

    if (request.clean) {
      await _cleanGeneratedStaticOutput(outputPath);
    }

    await Directory(manifestVersionsDirectoryPath).create(recursive: true);
    await _replaceDirectory(screensDirectoryPath, outputRoot: outputPath);
    if (assetsDirectoryPath != null) {
      await _replaceDirectory(assetsDirectoryPath, outputRoot: outputPath);
    }
    await Directory(p.dirname(releaseMetadataPath)).create(recursive: true);
    await Directory(p.dirname(catalogMetadataPath)).create(recursive: true);

    final writtenFiles = <StaticPublishedFileRecord>[];
    Future<void> copyFile(File source, String targetPath) async {
      _assertContainedPath(path: targetPath, root: outputPath);
      await Directory(p.dirname(targetPath)).create(recursive: true);
      await source.copy(targetPath);
      writtenFiles.add(
        StaticPublishedFileRecord(
          relativePath: _relativeStaticPath(targetPath, outputPath),
          localSourcePath: source.path,
        ),
      );
    }

    final manifestLatestPath = p.join(manifestDirectoryPath, 'latest.json');
    final manifestVersionPath = p.join(
      manifestVersionsDirectoryPath,
      '$version.json',
    );
    await copyFile(File(manifestPath), manifestLatestPath);
    await copyFile(File(manifestPath), manifestVersionPath);

    final screenFiles = await _listJsonFiles(buildResult.screensDirectoryPath);
    if (screenFiles.isEmpty) {
      throw MiniProgramPublishException(
        'No built screen JSON files were found in '
        '${buildResult.screensDirectoryPath}',
      );
    }
    for (final screenFile in screenFiles) {
      await copyFile(
        screenFile,
        p.join(screensDirectoryPath, p.basename(screenFile.path)),
      );
    }

    if (assetsDirectoryPath != null) {
      final assetFiles = await _listAllFiles(assetsSourceDirectory.path);
      for (final assetFile in assetFiles) {
        final relativePath = p.relative(
          assetFile.path,
          from: assetsSourceDirectory.path,
        );
        await copyFile(assetFile, p.join(assetsDirectoryPath, relativePath));
      }
    }

    await _writeJsonFile(
      releaseMetadataPath,
      <String, Object?>{
        'schemaVersion': 1,
        'provider': 'static',
        'miniProgramId': buildResult.miniProgramId,
        'version': version,
        'publishedAtUtc': publishedAtUtc,
        'artifacts': <String, Object?>{
          'manifestPath':
              'manifests/${buildResult.miniProgramId}/versions/$version.json',
          'latestManifestPath':
              'manifests/${buildResult.miniProgramId}/latest.json',
          'screensBasePath': 'screens/${buildResult.miniProgramId}/$version/',
          if (assetsDirectoryPath != null)
            'assetsBasePath': 'assets/${buildResult.miniProgramId}/$version/',
        },
      },
      outputRoot: outputPath,
      writtenFiles: writtenFiles,
    );
    await _writeJsonFile(
      catalogMetadataPath,
      <String, Object?>{
        'schemaVersion': 1,
        'provider': 'static',
        'miniProgramId': buildResult.miniProgramId,
        'latestVersion': version,
        'updatedAtUtc': publishedAtUtc,
        'releasePath':
            'metadata/releases/${buildResult.miniProgramId}/$version.json',
      },
      outputRoot: outputPath,
      writtenFiles: writtenFiles,
    );
    await _writeInstructions(
      instructionsPath: instructionsPath,
      outputRoot: outputPath,
      miniProgramId: buildResult.miniProgramId,
      version: version,
      writtenFiles: writtenFiles,
    );
    await _writeTextFile(
      nojekyllPath,
      '',
      outputRoot: outputPath,
      writtenFiles: writtenFiles,
    );

    return MiniProgramStaticPublishResult(
      outputPath: outputPath,
      miniProgramId: buildResult.miniProgramId,
      version: version,
      buildResult: buildResult,
      manifestLatestPath: manifestLatestPath,
      manifestVersionPath: manifestVersionPath,
      screensDirectoryPath: screensDirectoryPath,
      assetsDirectoryPath: assetsDirectoryPath,
      metadataReleasePath: releaseMetadataPath,
      metadataCatalogPath: catalogMetadataPath,
      instructionsPath: instructionsPath,
      nojekyllPath: nojekyllPath,
      publishedAtUtc: publishedAtUtc,
      writtenFiles: writtenFiles,
      cleaned: request.clean,
    );
  }

  Future<Map<String, dynamic>> _readManifestJson(String manifestPath) async {
    final file = File(manifestPath);
    if (!await file.exists()) {
      throw MiniProgramPublishException(
        'Manifest was not found: $manifestPath',
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw MiniProgramPublishException(
        'Manifest is not a JSON object: $manifestPath',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  MiniProgramManifest _parseManifest(
    Map<String, dynamic> manifestJson,
    String manifestPath,
  ) {
    try {
      return MiniProgramManifest.fromJson(manifestJson);
    } catch (error) {
      throw MiniProgramPublishException(
        'Manifest could not be parsed: $manifestPath\n$error',
      );
    }
  }

  void _validateSemanticVersion(String value, String manifestPath) {
    try {
      Version.parse(value);
    } on FormatException {
      throw MiniProgramPublishException(
        'Manifest version "$value" is not a valid semantic version: '
        '$manifestPath',
      );
    }
  }

  Future<List<File>> _listJsonFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw MiniProgramPublishException(
        'Built screens directory does not exist: $directoryPath',
      );
    }

    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<File>> _listAllFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return <File>[];
    }

    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _replaceDirectory(
    String directoryPath, {
    required String outputRoot,
  }) async {
    _assertContainedPath(path: directoryPath, root: outputRoot);
    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }

  Future<void> _cleanGeneratedStaticOutput(String outputRoot) async {
    final generatedDirectoryNames = <String>[
      'manifests',
      'screens',
      'assets',
      'metadata',
    ];
    for (final directoryName in generatedDirectoryNames) {
      final directoryPath = p.join(outputRoot, directoryName);
      _assertContainedPath(path: directoryPath, root: outputRoot);
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    for (final fileName in <String>['PUBLISH_INSTRUCTIONS.md', '.nojekyll']) {
      final filePath = p.join(outputRoot, fileName);
      _assertContainedPath(path: filePath, root: outputRoot);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _writeJsonFile(
    String filePath,
    Map<String, Object?> json, {
    required String outputRoot,
    required List<StaticPublishedFileRecord> writtenFiles,
  }) async {
    _assertContainedPath(path: filePath, root: outputRoot);
    await Directory(p.dirname(filePath)).create(recursive: true);
    await File(
      filePath,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(json)}\n');
    writtenFiles.add(
      StaticPublishedFileRecord(
        relativePath: _relativeStaticPath(filePath, outputRoot),
        localSourcePath: filePath,
      ),
    );
  }

  Future<void> _writeTextFile(
    String filePath,
    String value, {
    required String outputRoot,
    required List<StaticPublishedFileRecord> writtenFiles,
  }) async {
    _assertContainedPath(path: filePath, root: outputRoot);
    await Directory(p.dirname(filePath)).create(recursive: true);
    await File(filePath).writeAsString(value);
    writtenFiles.add(
      StaticPublishedFileRecord(
        relativePath: _relativeStaticPath(filePath, outputRoot),
        localSourcePath: filePath,
      ),
    );
  }

  Future<void> _writeInstructions({
    required String instructionsPath,
    required String outputRoot,
    required String miniProgramId,
    required String version,
    required List<StaticPublishedFileRecord> writtenFiles,
  }) async {
    _assertContainedPath(path: instructionsPath, root: outputRoot);
    await File(instructionsPath).writeAsString('''
# MiniProgram Static Publish

This folder contains public/static delivery artifacts for `$miniProgramId`
version `$version`.

Upload the contents of this folder to GitHub Pages, a CDN, S3 public hosting,
Cloudflare Pages, Netlify, Vercel static hosting, or another public static host.

GitHub Pages users should keep the generated `.nojekyll` file so generated
paths are served as normal static files. If this folder is committed inside a
larger Pages repo, also keep a `.nojekyll` file at the repo root.

Use the public URL for this folder as the endpoint base URI:

```dart
MiniProgramEndpoint.public(
  apiBaseUri: Uri.parse('https://your-cdn.example.com/public_mini_program/'),
)
```

Public static delivery is unauthenticated. Do not publish private data or
business-only mini-programs with this mode. Use protected AWS/GCP/backend
delivery with a MiniProgram access key for production partner access control.
''');
    writtenFiles.add(
      StaticPublishedFileRecord(
        relativePath: _relativeStaticPath(instructionsPath, outputRoot),
        localSourcePath: instructionsPath,
      ),
    );
  }

  void _assertContainedPath({required String path, required String root}) {
    final resolvedPath = p.normalize(p.absolute(path));
    final resolvedRoot = p.normalize(p.absolute(root));
    if (!p.isWithin(resolvedRoot, resolvedPath) &&
        resolvedPath != resolvedRoot) {
      throw MiniProgramPublishException(
        'Static publish target escaped output root: $resolvedPath',
      );
    }
  }

  String _relativeStaticPath(String path, String outputRoot) =>
      p.relative(path, from: outputRoot).replaceAll('\\', '/');
}
