import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'delivery_validation.dart';
import 'delivery_validator.dart';
import 'mini_program_builder.dart';

class MiniProgramPublishRequest {
  const MiniProgramPublishRequest({
    required this.repoRootPath,
    required this.miniProgramId,
    this.stacCliScriptPath,
    this.skipBuildPubGet = false,
  });

  final String repoRootPath;
  final String miniProgramId;
  final String? stacCliScriptPath;
  final bool skipBuildPubGet;
}

class MiniProgramPublishResult {
  const MiniProgramPublishResult({
    required this.repoRootPath,
    required this.miniProgramId,
    required this.version,
    required this.buildResult,
    required this.prePublishValidation,
    required this.postPublishValidation,
    required this.latestManifestPath,
    required this.versionedManifestPath,
    required this.screensDirectoryPath,
    required this.copiedScreenCount,
  });

  final String repoRootPath;
  final String miniProgramId;
  final String version;
  final MiniProgramBuildResult buildResult;
  final DeliveryValidationReport prePublishValidation;
  final DeliveryValidationReport postPublishValidation;
  final String latestManifestPath;
  final String versionedManifestPath;
  final String screensDirectoryPath;
  final int copiedScreenCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'miniProgramId': miniProgramId,
    'version': version,
    'buildResult': buildResult.toJson(),
    'prePublishValidation': prePublishValidation.toJson(),
    'postPublishValidation': postPublishValidation.toJson(),
    'latestManifestPath': latestManifestPath,
    'versionedManifestPath': versionedManifestPath,
    'screensDirectoryPath': screensDirectoryPath,
    'copiedScreenCount': copiedScreenCount,
  };
}

class MiniProgramPublishException implements Exception {
  const MiniProgramPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramPublisher {
  const MiniProgramPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
  }) : _builder = builder,
       _validator = validator;

  final MiniProgramBuilder _builder;
  final DeliveryRepositoryValidator _validator;

  Future<MiniProgramPublishResult> publish(
    MiniProgramPublishRequest request,
  ) async {
    final repoRootPath = p.normalize(p.absolute(request.repoRootPath));
    final buildResult = await _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: repoRootPath,
        miniProgramId: request.miniProgramId,
        stacCliScriptPath: request.stacCliScriptPath,
        skipPubGet: request.skipBuildPubGet,
      ),
    );

    final preValidation = await _validator.validate(
      repoRootPath: repoRootPath,
      miniProgramId: request.miniProgramId,
    );
    if (preValidation.hasErrors) {
      throw MiniProgramPublishException(
        'Delivery validation failed before publish for '
        '${request.miniProgramId}.\n'
        '${formatDeliveryValidationReport(preValidation)}',
      );
    }

    final manifestPath = p.join(buildResult.miniProgramRootPath, 'manifest.json');
    final manifest = jsonDecode(
      await File(manifestPath).readAsString(),
    ) as Map<String, dynamic>;
    final version = '${manifest['version']}'.trim();
    if (version.isEmpty) {
      throw MiniProgramPublishException(
        'Manifest is missing a usable version: $manifestPath',
      );
    }

    final publishResult = await _publishLocalBackendArtifacts(
      repoRootPath: repoRootPath,
      miniProgramId: request.miniProgramId,
      version: version,
      manifestPath: manifestPath,
      screensDirectoryPath: buildResult.screensDirectoryPath,
    );

    final postValidation = await _validator.validate(
      repoRootPath: repoRootPath,
      miniProgramId: request.miniProgramId,
    );
    if (postValidation.hasErrors) {
      throw MiniProgramPublishException(
        'Delivery validation failed after publish for '
        '${request.miniProgramId}.\n'
        '${formatDeliveryValidationReport(postValidation)}',
      );
    }

    return MiniProgramPublishResult(
      repoRootPath: repoRootPath,
      miniProgramId: request.miniProgramId,
      version: version,
      buildResult: buildResult,
      prePublishValidation: preValidation,
      postPublishValidation: postValidation,
      latestManifestPath: publishResult.latestManifestPath,
      versionedManifestPath: publishResult.versionedManifestPath,
      screensDirectoryPath: publishResult.screensDirectoryPath,
      copiedScreenCount: publishResult.copiedScreenCount,
    );
  }

  Future<_LocalPublishResult> _publishLocalBackendArtifacts({
    required String repoRootPath,
    required String miniProgramId,
    required String version,
    required String manifestPath,
    required String screensDirectoryPath,
  }) async {
    final backendRootPath = p.join(repoRootPath, 'backend');
    final backendRootDir = Directory(backendRootPath);
    if (!await backendRootDir.exists()) {
      throw MiniProgramPublishException(
        'Backend root does not exist: $backendRootPath',
      );
    }

    final screensDirectory = Directory(screensDirectoryPath);
    if (!await screensDirectory.exists()) {
      throw MiniProgramPublishException(
        'Built screens directory does not exist: $screensDirectoryPath',
      );
    }

    final apiRootPath = p.join(backendRootPath, 'api');
    final manifestTargetDirPath = p.join(apiRootPath, 'manifests', miniProgramId);
    final versionedManifestDirPath = p.join(manifestTargetDirPath, 'versions');
    final latestManifestPath = p.join(manifestTargetDirPath, 'latest.json');
    final versionedManifestPath = p.join(
      versionedManifestDirPath,
      '$version.json',
    );
    final screenTargetDirPath = p.join(
      apiRootPath,
      'screens',
      miniProgramId,
      version,
    );

    for (final path in <String>[
      manifestTargetDirPath,
      versionedManifestDirPath,
      screenTargetDirPath,
    ]) {
      _assertContainedPath(path: path, root: backendRootPath);
      await Directory(path).create(recursive: true);
    }

    await File(manifestPath).copy(latestManifestPath);
    await File(manifestPath).copy(versionedManifestPath);

    final existingScreenFiles = await Directory(screenTargetDirPath)
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path) == '.json')
        .toList();
    for (final file in existingScreenFiles) {
      await file.delete();
    }

    var copiedScreenCount = 0;
    final builtScreenFiles = await screensDirectory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path) == '.json')
        .toList();
    builtScreenFiles.sort((a, b) => a.path.compareTo(b.path));

    for (final sourceFile in builtScreenFiles) {
      final targetPath = p.join(screenTargetDirPath, p.basename(sourceFile.path));
      await sourceFile.copy(targetPath);
      copiedScreenCount += 1;
    }

    if (copiedScreenCount == 0) {
      throw MiniProgramPublishException(
        'No built screen JSON files were found in $screensDirectoryPath',
      );
    }

    return _LocalPublishResult(
      latestManifestPath: latestManifestPath,
      versionedManifestPath: versionedManifestPath,
      screensDirectoryPath: screenTargetDirPath,
      copiedScreenCount: copiedScreenCount,
    );
  }

  void _assertContainedPath({
    required String path,
    required String root,
  }) {
    final resolvedPath = p.normalize(p.absolute(path));
    final resolvedRoot = p.normalize(p.absolute(root));
    if (!p.isWithin(resolvedRoot, resolvedPath) &&
        resolvedPath != resolvedRoot) {
      throw MiniProgramPublishException(
        'Publish target escaped backend root: $resolvedPath',
      );
    }
  }
}

class _LocalPublishResult {
  const _LocalPublishResult({
    required this.latestManifestPath,
    required this.versionedManifestPath,
    required this.screensDirectoryPath,
    required this.copiedScreenCount,
  });

  final String latestManifestPath;
  final String versionedManifestPath;
  final String screensDirectoryPath;
  final int copiedScreenCount;
}
