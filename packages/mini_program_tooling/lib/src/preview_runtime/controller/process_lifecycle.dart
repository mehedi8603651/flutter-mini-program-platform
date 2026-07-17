import 'dart:io';

import 'package:path/path.dart' as p;

import '../server/models.dart';
import 'models.dart';

Future<void> resetTransientPreviewHostState(String hostRootPath) async {
  final buildDirectory = Directory(p.join(hostRootPath, 'build'));
  final flutterBuildDirectory = Directory(
    p.join(hostRootPath, '.dart_tool', 'flutter_build'),
  );

  await _deleteDirectoryIfExists(
    buildDirectory,
    label: 'preview host build output',
  );
  await _deleteDirectoryIfExists(
    flutterBuildDirectory,
    label: 'preview host flutter build cache',
  );
  await _deleteCrashLogs(hostRootPath);
}

Future<void> _deleteDirectoryIfExists(
  Directory directory, {
  required String label,
}) async {
  if (!await directory.exists()) {
    return;
  }

  await _withCleanupRetries(
    () => directory.delete(recursive: true),
    label: label,
    path: directory.path,
  );
}

Future<void> _deleteCrashLogs(String hostRootPath) async {
  final hostRootDirectory = Directory(hostRootPath);
  if (!await hostRootDirectory.exists()) {
    return;
  }

  await for (final entity in hostRootDirectory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    final basename = p.basename(entity.path);
    if (!RegExp(r'^flutter_\d+\.log$').hasMatch(basename)) {
      continue;
    }

    await _withCleanupRetries(
      () => entity.delete(),
      label: 'preview host crash log',
      path: entity.path,
    );
  }
}

Future<void> _withCleanupRetries(
  Future<void> Function() operation, {
  required String label,
  required String path,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 0; attempt < 4; attempt += 1) {
    try {
      await operation();
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      if (attempt == 3) {
        break;
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
  }

  Error.throwWithStackTrace(
    MiniProgramPreviewException(
      'Failed to clear $label at $path before launch. '
      'Close any leftover Chrome or Flutter preview windows and try again. '
      'Original error: $lastError',
    ),
    lastStackTrace ?? StackTrace.current,
  );
}

List<String> buildPreviewFlutterRunArguments({
  required String hostRootPath,
  required String deviceId,
  required String previewBaseUrl,
  required String miniProgramId,
  required String title,
}) {
  return <String>[
    'run',
    '--project-root',
    hostRootPath,
    '-d',
    deviceId,
    '--no-hot',
    '--dart-define=MINI_PROGRAM_PREVIEW_BASE_URL=$previewBaseUrl',
    '--dart-define=MINI_PROGRAM_PREVIEW_MINI_PROGRAM_ID=$miniProgramId',
    '--dart-define=MINI_PROGRAM_PREVIEW_TITLE=$title',
  ];
}

Future<StartedPreviewProcess> defaultPreviewProcessStarter({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
  );
  return StartedPreviewProcess(
    pid: process.pid,
    stdout: process.stdout,
    stderr: process.stderr,
    exitCode: process.exitCode,
    kill: ([signal = ProcessSignal.sigterm]) => process.kill(signal),
  );
}

Future<ProcessResult> defaultPreviewShellRunner(
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
