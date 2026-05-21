import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

typedef ManagedStacProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class ManagedStacBuilderException implements Exception {
  const ManagedStacBuilderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManagedStacBuilderStatus {
  const ManagedStacBuilderStatus({
    required this.pinnedVersion,
    required this.templateRootPath,
    required this.cacheRootPath,
    required this.bundledTemplateAvailable,
    required this.cachePrepared,
    required this.dependenciesResolved,
  });

  final String pinnedVersion;
  final String? templateRootPath;
  final String cacheRootPath;
  final bool bundledTemplateAvailable;
  final bool cachePrepared;
  final bool dependenciesResolved;

  bool get ready => bundledTemplateAvailable && dependenciesResolved;
}

class ManagedStacBuilderResolution {
  const ManagedStacBuilderResolution({
    required this.pinnedVersion,
    required this.packageRootPath,
    required this.entrypointPath,
  });

  final String pinnedVersion;
  final String packageRootPath;
  final String entrypointPath;
}

class ManagedStacBuilder {
  const ManagedStacBuilder({
    String? homeDirectoryPath,
    String? packageRootPath,
    ManagedStacProcessRunner processRunner = _defaultProcessRunner,
  }) : _homeDirectoryPath = homeDirectoryPath,
       _packageRootPath = packageRootPath,
       _processRunner = processRunner;

  static const String pinnedVersion = '1.6.0';

  final String? _homeDirectoryPath;
  final String? _packageRootPath;
  final ManagedStacProcessRunner _processRunner;

  Future<ManagedStacBuilderStatus> inspect() async {
    final templateRootPath = await _resolveTemplateRootPath();
    final cacheRootPath = _cacheRootPath();
    final cachePrepared = await Directory(cacheRootPath).exists();
    final dependenciesResolved = await File(
      p.join(cacheRootPath, '.dart_tool', 'package_config.json'),
    ).exists();

    return ManagedStacBuilderStatus(
      pinnedVersion: pinnedVersion,
      templateRootPath: templateRootPath,
      cacheRootPath: cacheRootPath,
      bundledTemplateAvailable:
          templateRootPath != null &&
          await _looksLikeTemplateRoot(templateRootPath),
      cachePrepared: cachePrepared,
      dependenciesResolved: dependenciesResolved,
    );
  }

  Future<ManagedStacBuilderResolution> ensureReady() async {
    final templateRootPath = await _requireTemplateRootPath();
    final cacheRootPath = _cacheRootPath();

    if (!await _looksLikeTemplateRoot(cacheRootPath)) {
      if (await Directory(cacheRootPath).exists()) {
        await Directory(cacheRootPath).delete(recursive: true);
      }
      await _copyDirectory(
        from: Directory(templateRootPath),
        to: Directory(cacheRootPath),
      );
    }

    final packageConfigFile = File(
      p.join(cacheRootPath, '.dart_tool', 'package_config.json'),
    );
    if (!await packageConfigFile.exists()) {
      final result = await _processRunner('dart', const <String>[
        'pub',
        'get',
      ], workingDirectory: cacheRootPath);
      if (result.exitCode != 0) {
        final stdoutText = '${result.stdout}'.trim();
        final stderrText = '${result.stderr}'.trim();
        final details = <String>[
          'Failed to bootstrap the managed pinned Stac builder.',
          'Pinned version: $pinnedVersion',
          'Cache root: $cacheRootPath',
          if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
          if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
        ].join('\n');
        throw ManagedStacBuilderException(details);
      }
    }

    return ManagedStacBuilderResolution(
      pinnedVersion: pinnedVersion,
      packageRootPath: cacheRootPath,
      entrypointPath: p.join(cacheRootPath, 'bin', 'stac_cli.dart'),
    );
  }

  Future<String> _requireTemplateRootPath() async {
    final templateRootPath = await _resolveTemplateRootPath();
    if (templateRootPath == null ||
        !await _looksLikeTemplateRoot(templateRootPath)) {
      throw const ManagedStacBuilderException(
        'The managed pinned Stac builder template is missing from '
        'mini_program_tooling.',
      );
    }
    return templateRootPath;
  }

  Future<String?> _resolveTemplateRootPath() async {
    final packageRootPath = await _resolvePackageRootPath();
    if (packageRootPath == null) {
      return null;
    }
    return p.join(packageRootPath, 'templates', 'pinned_stac_cli');
  }

  Future<String?> _resolvePackageRootPath() async {
    if (_packageRootPath != null && _packageRootPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(_packageRootPath));
    }

    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
    );
    if (packageUri == null || packageUri.scheme != 'file') {
      return null;
    }

    final libFilePath = p.fromUri(packageUri);
    return p.dirname(p.dirname(libFilePath));
  }

  String _cacheRootPath() => p.join(
    _normalizeHomeDirectoryPath(),
    '.mini_program',
    'cache',
    'stac_cli',
    pinnedVersion,
  );

  String _normalizeHomeDirectoryPath() => p.normalize(
    p.absolute(_homeDirectoryPath ?? _resolveHomeDirectoryPath()),
  );

  String _resolveHomeDirectoryPath() {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return home;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return userProfile;
    }

    final homeDrive = Platform.environment['HOMEDRIVE'];
    final homePath = Platform.environment['HOMEPATH'];
    if (homeDrive != null &&
        homeDrive.trim().isNotEmpty &&
        homePath != null &&
        homePath.trim().isNotEmpty) {
      return '$homeDrive$homePath';
    }

    return Directory.current.path;
  }

  Future<bool> _looksLikeTemplateRoot(String rootPath) async {
    final normalizedRootPath = p.normalize(p.absolute(rootPath));
    return await File(p.join(normalizedRootPath, 'pubspec.yaml')).exists() &&
        await File(
          p.join(normalizedRootPath, 'bin', 'stac_cli.dart'),
        ).exists() &&
        await File(p.join(normalizedRootPath, 'lib', 'stac_cli.dart')).exists();
  }

  Future<void> _copyDirectory({
    required Directory from,
    required Directory to,
  }) async {
    await to.create(recursive: true);
    await for (final entity in from.list(recursive: true, followLinks: false)) {
      final relativePath = p.relative(entity.path, from: from.path);
      final targetPath = p.join(to.path, relativePath);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );
  }
}
