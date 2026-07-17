import 'dart:io';

import 'package:path/path.dart' as path;

import 'main_template.dart';
import 'models.dart';
import 'platform_files.dart';
import 'pubspec.dart';

const Set<String> supportedPreviewHostPlatforms = <String>{
  'android',
  'ios',
  'linux',
  'macos',
  'web',
  'windows',
};

Future<MiniProgramPreviewHostInitResult> initializeMiniProgramPreviewHost(
  MiniProgramPreviewHostInitRequest request, {
  required PreviewHostShellRunner shellRunner,
}) async {
  final hostRootPath = path.normalize(path.absolute(request.hostRootPath));
  final repoRootPath = request.repoRootPath == null
      ? null
      : path.normalize(path.absolute(request.repoRootPath!));
  final screenFormat = _normalizeScreenFormat(request.screenFormat);
  final requiredPlatforms = _normalizePlatforms(request.requiredPlatforms);

  await Directory(path.dirname(hostRootPath)).create(recursive: true);
  await _ensureFlutterProject(
    hostRootPath,
    requiredPlatforms: requiredPlatforms,
    shellRunner: shellRunner,
  );

  final managedPaths = <String>[];
  final pubspecPath = path.join(hostRootPath, 'pubspec.yaml');
  final mainPath = path.join(hostRootPath, 'lib', 'main.dart');

  await File(pubspecPath).writeAsString(
    buildPreviewHostPubspec(
      hostRootPath: hostRootPath,
      repoRootPath: repoRootPath,
    ),
  );
  managedPaths.add(pubspecPath);

  await File(mainPath).create(recursive: true);
  await File(mainPath).writeAsString(buildPreviewHostMainDart());
  managedPaths.add(mainPath);

  final platformFiles = buildPreviewHostPlatformFiles(hostRootPath);
  for (final entry in platformFiles.entries) {
    final file = File(entry.key);
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    managedPaths.add(file.path);
  }

  return MiniProgramPreviewHostInitResult(
    hostRootPath: hostRootPath,
    managedPaths: managedPaths,
    usedPathDependencies: repoRootPath != null,
    screenFormat: screenFormat,
  );
}

String _normalizeScreenFormat(String rawScreenFormat) {
  final screenFormat = rawScreenFormat.trim().toLowerCase();
  if (screenFormat == 'mp') {
    return screenFormat;
  }
  throw MiniProgramPreviewHostInitException(
    'Unsupported preview screen format "$rawScreenFormat".',
  );
}

Set<String> _normalizePlatforms(Set<String> rawPlatforms) {
  final normalized = rawPlatforms
      .map((platform) => platform.trim().toLowerCase())
      .where((platform) => platform.isNotEmpty)
      .toSet();

  if (normalized.isEmpty) {
    throw const MiniProgramPreviewHostInitException(
      'Preview host must request at least one Flutter platform.',
    );
  }

  final unsupported = normalized.difference(supportedPreviewHostPlatforms);
  if (unsupported.isNotEmpty) {
    throw MiniProgramPreviewHostInitException(
      'Unsupported preview host Flutter platforms: '
      '${(unsupported.toList()..sort()).join(', ')}',
    );
  }

  return normalized;
}

Future<void> _ensureFlutterProject(
  String hostRootPath, {
  required Set<String> requiredPlatforms,
  required PreviewHostShellRunner shellRunner,
}) async {
  final pubspecFile = File(path.join(hostRootPath, 'pubspec.yaml'));
  final missingPlatforms =
      requiredPlatforms
          .where(
            (platform) =>
                !Directory(path.join(hostRootPath, platform)).existsSync(),
          )
          .toList()
        ..sort();

  if (!await pubspecFile.exists()) {
    await _runFlutterCreate(
      workingDirectory: path.dirname(hostRootPath),
      targetDirectoryName: path.basename(hostRootPath),
      requiredPlatforms: requiredPlatforms,
      shellRunner: shellRunner,
    );
    return;
  }

  if (missingPlatforms.isNotEmpty) {
    await _runFlutterCreate(
      workingDirectory: hostRootPath,
      targetDirectoryName: '.',
      requiredPlatforms: requiredPlatforms,
      shellRunner: shellRunner,
    );
  }
}

Future<void> _runFlutterCreate({
  required String workingDirectory,
  required String targetDirectoryName,
  required Set<String> requiredPlatforms,
  required PreviewHostShellRunner shellRunner,
}) async {
  final sortedPlatforms = requiredPlatforms.toList()..sort();
  final result = await shellRunner('flutter', <String>[
    'create',
    '--platforms=${sortedPlatforms.join(',')}',
    '--project-name',
    previewHostProjectName,
    '--org',
    'dev.miniprogram',
    '--description',
    'Managed preview host for mini_program_tooling.',
    '--no-pub',
    targetDirectoryName,
  ], workingDirectory: workingDirectory);

  if (result.exitCode == 0) {
    return;
  }

  final stdoutText = '${result.stdout}'.trim();
  final stderrText = '${result.stderr}'.trim();
  throw MiniProgramPreviewHostInitException(
    [
      'Failed to bootstrap the managed preview host with `flutter create`.',
      if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
      if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
    ].join('\n'),
  );
}

Future<ProcessResult> defaultPreviewHostShellRunner(
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
    runInShell: Platform.isWindows,
  );
}
