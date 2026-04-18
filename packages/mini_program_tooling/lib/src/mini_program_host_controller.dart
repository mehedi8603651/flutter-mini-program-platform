import 'dart:io';

import 'package:path/path.dart' as p;

typedef MiniProgramHostProcessRunner =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

Future<int> _defaultMiniProgramHostProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

class MiniProgramHostException implements Exception {
  const MiniProgramHostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramHostRunRequest {
  const MiniProgramHostRunRequest({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
}

class MiniProgramHostRunResult {
  const MiniProgramHostRunResult({
    required this.projectRootPath,
    required this.deviceId,
    required this.backendApiBaseUrl,
    required this.invocation,
    required this.exitCode,
  });

  final String projectRootPath;
  final String deviceId;
  final String backendApiBaseUrl;
  final List<String> invocation;
  final int exitCode;
}

class MiniProgramHostController {
  MiniProgramHostController({
    MiniProgramHostProcessRunner processRunner =
        _defaultMiniProgramHostProcessRunner,
  }) : _processRunner = processRunner;

  final MiniProgramHostProcessRunner _processRunner;

  Future<MiniProgramHostRunResult> run(
    MiniProgramHostRunRequest request,
  ) async {
    final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
    final projectDirectory = Directory(projectRootPath);
    if (!await projectDirectory.exists()) {
      throw MiniProgramHostException(
        'Flutter host project root does not exist: $projectRootPath',
      );
    }

    final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostException(
        'Flutter host project is missing pubspec.yaml: $projectRootPath',
      );
    }

    final generatedRuntimeSetup = File(
      p.join(
        projectRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    );
    if (!await generatedRuntimeSetup.exists()) {
      throw const MiniProgramHostException(
        'The generated mini-program embedding adapter was not found. Run '
        '`miniprogram embed init` in the host Flutter app first.',
      );
    }

    final trimmedBackendApiBaseUrl = request.backendApiBaseUrl.trim();
    if (trimmedBackendApiBaseUrl.isEmpty) {
      throw const MiniProgramHostException(
        'A backend API base URL is required to run the embedded host app.',
      );
    }

    final invocation = <String>[
      'run',
      '-d',
      request.deviceId,
      '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=$trimmedBackendApiBaseUrl',
    ];
    final exitCode = await _processRunner(
      'flutter',
      invocation,
      workingDirectory: projectRootPath,
    );

    return MiniProgramHostRunResult(
      projectRootPath: projectRootPath,
      deviceId: request.deviceId,
      backendApiBaseUrl: trimmedBackendApiBaseUrl,
      invocation: invocation,
      exitCode: exitCode,
    );
  }
}
