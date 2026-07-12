import 'dart:io';

import 'package:path/path.dart' as p;

import 'mini_program_artifacts.dart';
import 'mini_program_builder.dart';
import 'mini_program_publisher.dart';

class MiniProgramStaticPublishRequest {
  const MiniProgramStaticPublishRequest({
    required this.repoRootPath,
    required this.outputPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.mpBuildScriptPath,
    this.skipBuildPubGet = false,
    this.clean = false,
  });

  final String repoRootPath;
  final String outputPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
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

/// Legacy directory adapter over the canonical portable artifact builder.
///
/// New workflows should use `miniprogram artifact build` and copy the generated
/// `artifacts/` directory manually. This adapter remains for existing scripts.
class MiniProgramStaticPublisher {
  const MiniProgramStaticPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
  }) : _builder = builder;

  final MiniProgramBuilder _builder;

  Future<MiniProgramStaticPublishResult> publish(
    MiniProgramStaticPublishRequest request,
  ) async {
    final outputPath = p.normalize(p.absolute(request.outputPath));
    final artifactsRoot = p.join(outputPath, 'artifacts');
    final requestedAppId = request.miniProgramId?.trim();

    if (request.clean && requestedAppId != null && requestedAppId.isNotEmpty) {
      final appArtifactsPath = p.join(artifactsRoot, requestedAppId);
      _assertContained(appArtifactsPath, artifactsRoot);
      final appArtifacts = Directory(appArtifactsPath);
      if (await appArtifacts.exists()) {
        await appArtifacts.delete(recursive: true);
      }
    }

    late final MiniProgramArtifactBuildResult artifactResult;
    try {
      artifactResult = await MiniProgramArtifactBuilder(builder: _builder)
          .build(
            MiniProgramArtifactBuildRequest(
              repoRootPath: request.repoRootPath,
              miniProgramId: request.miniProgramId,
              miniProgramRootPath: request.miniProgramRootPath,
              artifactsRootPath: artifactsRoot,
              mpBuildScriptPath: request.mpBuildScriptPath,
              skipPubGet: request.skipBuildPubGet,
            ),
          );
    } on MiniProgramArtifactException catch (error) {
      throw MiniProgramPublishException(error.toString());
    }

    await Directory(outputPath).create(recursive: true);
    final instructionsPath = p.join(outputPath, 'PUBLISH_INSTRUCTIONS.md');
    final nojekyllPath = p.join(outputPath, '.nojekyll');
    await File(instructionsPath).writeAsString(
      _instructions(
        miniProgramId: artifactResult.buildResult.miniProgramId,
        version: artifactResult.version,
      ),
    );
    await File(nojekyllPath).writeAsString('');

    final files = await _listFiles(artifactResult.appArtifactsPath);
    files.addAll(<File>[File(instructionsPath), File(nojekyllPath)]);
    files.sort((left, right) => left.path.compareTo(right.path));
    final writtenFiles = files
        .map(
          (file) => StaticPublishedFileRecord(
            relativePath: p
                .relative(file.path, from: outputPath)
                .replaceAll('\\', '/'),
            localSourcePath: file.path,
          ),
        )
        .toList(growable: false);

    return MiniProgramStaticPublishResult(
      outputPath: outputPath,
      miniProgramId: artifactResult.buildResult.miniProgramId,
      version: artifactResult.version,
      buildResult: artifactResult.buildResult,
      manifestLatestPath: artifactResult.latestManifestPath,
      manifestVersionPath: p.join(
        artifactResult.versionArtifactsPath,
        'manifest.json',
      ),
      screensDirectoryPath: p.join(
        artifactResult.versionArtifactsPath,
        'screens',
      ),
      assetsDirectoryPath: p.join(
        artifactResult.versionArtifactsPath,
        'assets',
      ),
      metadataReleasePath: p.join(
        artifactResult.versionArtifactsPath,
        'release.json',
      ),
      metadataCatalogPath: artifactResult.catalogPath,
      instructionsPath: instructionsPath,
      nojekyllPath: nojekyllPath,
      publishedAtUtc: DateTime.now().toUtc().toIso8601String(),
      writtenFiles: writtenFiles,
      cleaned: request.clean,
    );
  }

  Future<List<File>> _listFiles(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return <File>[];
    }
    return root
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
  }

  void _assertContained(String candidatePath, String rootPath) {
    final candidate = p.normalize(p.absolute(candidatePath));
    final root = p.normalize(p.absolute(rootPath));
    if (candidate != root && !p.isWithin(root, candidate)) {
      throw MiniProgramPublishException(
        'Static publish target escaped output root: $candidate',
      );
    }
  }

  String _instructions({
    required String miniProgramId,
    required String version,
  }) =>
      '''# MiniProgram Static Artifacts

This directory contains the portable artifact bundle for `$miniProgramId`
version `$version` under `artifacts/$miniProgramId/$version/`.

Upload the `artifacts/` directory to any public static file host. Upload the
immutable version directory first and `artifacts/$miniProgramId/latest.json`
last. GitHub Pages users should retain the generated `.nojekyll` marker.

Public artifacts must never contain secrets, private user data, authentication
state, payment data, or server-side business rules.
''';
}
