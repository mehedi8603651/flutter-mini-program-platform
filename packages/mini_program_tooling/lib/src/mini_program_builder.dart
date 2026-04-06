import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
});

class MiniProgramBuildRequest {
  const MiniProgramBuildRequest({
    required this.repoRootPath,
    required this.miniProgramId,
    this.stacCliScriptPath,
    this.skipPubGet = false,
  });

  final String repoRootPath;
  final String miniProgramId;
  final String? stacCliScriptPath;
  final bool skipPubGet;
}

class MiniProgramBuildResult {
  const MiniProgramBuildResult({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.outputDirectoryPath,
    required this.screensDirectoryPath,
    required this.entryScreenJsonPath,
    required this.cliSource,
    required this.invocation,
    required this.pubGetRan,
  });

  final String repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String outputDirectoryPath;
  final String screensDirectoryPath;
  final String entryScreenJsonPath;
  final String cliSource;
  final List<String> invocation;
  final bool pubGetRan;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'miniProgramRootPath': miniProgramRootPath,
    'miniProgramId': miniProgramId,
    'outputDirectoryPath': outputDirectoryPath,
    'screensDirectoryPath': screensDirectoryPath,
    'entryScreenJsonPath': entryScreenJsonPath,
    'cliSource': cliSource,
    'invocation': invocation,
    'pubGetRan': pubGetRan,
  };
}

class MiniProgramBuildException implements Exception {
  const MiniProgramBuildException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramBuilder {
  const MiniProgramBuilder({
    ProcessRunner processRunner = _defaultProcessRunner,
  }) : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async {
    final repoRootPath = p.normalize(p.absolute(request.repoRootPath));
    final miniProgramRootPath = p.join(
      repoRootPath,
      'mini_programs',
      request.miniProgramId,
    );
    final miniProgramRootDir = Directory(miniProgramRootPath);

    if (!await miniProgramRootDir.exists()) {
      throw MiniProgramBuildException(
        'Mini-program root does not exist: $miniProgramRootPath',
      );
    }

    final manifestPath = p.join(miniProgramRootPath, 'manifest.json');
    final pubspecPath = p.join(miniProgramRootPath, 'pubspec.yaml');
    final defaultOptionsPath = p.join(
      miniProgramRootPath,
      'lib',
      'default_stac_options.dart',
    );

    for (final path in <String>[manifestPath, pubspecPath]) {
      if (!await File(path).exists()) {
        throw MiniProgramBuildException('Required file is missing: $path');
      }
    }

    final manifest = jsonDecode(
      await File(manifestPath).readAsString(),
    ) as Map<String, dynamic>;
    final entryScreenId = manifest['entry'] as String?;
    if (entryScreenId == null || entryScreenId.trim().isEmpty) {
      throw MiniProgramBuildException(
        'Manifest is missing a usable entry screen: $manifestPath',
      );
    }

    final outputDirectoryPath = await _resolveOutputDirectory(
      miniProgramRootPath: miniProgramRootPath,
      defaultOptionsPath: defaultOptionsPath,
    );
    final screensDirectoryPath = p.join(outputDirectoryPath, 'screens');
    final entryScreenJsonPath = p.join(
      screensDirectoryPath,
      '$entryScreenId.json',
    );

    final command = await _resolveBuildCommand(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      stacCliScriptPath: request.stacCliScriptPath,
    );

    if (!request.skipPubGet) {
      await _runOrThrow(
        executable: 'dart',
        arguments: const <String>['pub', 'get'],
        workingDirectory: miniProgramRootPath,
        failureLabel: 'dart pub get failed for ${request.miniProgramId}',
      );
    }

    await _runOrThrow(
      executable: command.executable,
      arguments: command.arguments,
      workingDirectory: command.workingDirectory,
      environment: command.environment,
      failureLabel: 'Stac build failed for ${request.miniProgramId}',
    );

    if (!await File(entryScreenJsonPath).exists()) {
      throw MiniProgramBuildException(
        'Build completed but entry screen JSON was not found: '
        '$entryScreenJsonPath',
      );
    }

    return MiniProgramBuildResult(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: request.miniProgramId,
      outputDirectoryPath: outputDirectoryPath,
      screensDirectoryPath: screensDirectoryPath,
      entryScreenJsonPath: entryScreenJsonPath,
      cliSource: command.source,
      invocation: <String>[command.executable, ...command.arguments],
      pubGetRan: !request.skipPubGet,
    );
  }

  Future<String> _resolveOutputDirectory({
    required String miniProgramRootPath,
    required String defaultOptionsPath,
  }) async {
    var outputDir = 'stac/.build';

    final defaultOptionsFile = File(defaultOptionsPath);
    if (await defaultOptionsFile.exists()) {
      final source = await defaultOptionsFile.readAsString();
      final match = RegExp(r"outputDir:\s*'([^']*)'").firstMatch(source);
      if (match != null) {
        outputDir = match.group(1) ?? outputDir;
      }
    }

    final normalizedOutputDir = outputDir.replaceAll('/', p.separator);
    if (p.isAbsolute(normalizedOutputDir)) {
      return p.normalize(normalizedOutputDir);
    }

    return p.normalize(p.join(miniProgramRootPath, normalizedOutputDir));
  }

  Future<_BuildCommand> _resolveBuildCommand({
    required String repoRootPath,
    required String miniProgramRootPath,
    required String? stacCliScriptPath,
  }) async {
    if (stacCliScriptPath != null && stacCliScriptPath.trim().isNotEmpty) {
      final explicitPath = p.normalize(p.absolute(stacCliScriptPath.trim()));
      if (!await File(explicitPath).exists()) {
        throw MiniProgramBuildException(
          'Explicit Stac CLI script was not found: $explicitPath',
        );
      }

      return _BuildCommand(
        source: 'explicit_script',
        executable: 'dart',
        arguments: <String>[
          'run',
          explicitPath,
          'build',
          '--project',
          miniProgramRootPath,
        ],
        workingDirectory: repoRootPath,
        environment: _stacCliEnvironment(),
      );
    }

    final vendoredScriptPath = p.join(
      repoRootPath,
      'stac-dev',
      'packages',
      'stac_cli',
      'bin',
      'stac_cli.dart',
    );
    if (await File(vendoredScriptPath).exists()) {
      return _BuildCommand(
        source: 'vendored_script',
        executable: 'dart',
        arguments: <String>[
          'run',
          vendoredScriptPath,
          'build',
          '--project',
          miniProgramRootPath,
        ],
        workingDirectory: repoRootPath,
        environment: _stacCliEnvironment(),
      );
    }

    final globalStacResult = await _processRunner(
      'stac',
      const <String>['--version'],
      workingDirectory: repoRootPath,
    );
    if (globalStacResult.exitCode == 0) {
      return _BuildCommand(
        source: 'global_stac',
        executable: 'stac',
        arguments: <String>['build', '--project', miniProgramRootPath],
        workingDirectory: repoRootPath,
        environment: _stacCliEnvironment(),
      );
    }

    throw const MiniProgramBuildException(
      'No Stac CLI was found. Provide --stac-cli-script, restore '
      'stac-dev/packages/stac_cli/bin/stac_cli.dart, or install a global '
      '`stac` command.',
    );
  }

  Future<void> _runOrThrow({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    Map<String, String>? environment,
    required String failureLabel,
  }) async {
    final result = await _processRunner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );

    if (result.exitCode == 0) {
      return;
    }

    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    final details = <String>[
      failureLabel,
      'Command: $executable ${arguments.join(' ')}',
      if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
      if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
    ].join('\n');

    throw MiniProgramBuildException(details);
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

  Map<String, String> _stacCliEnvironment() {
    final environment = <String, String>{};

    if (!Platform.environment.containsKey('STAC_BASE_API_URL')) {
      environment['STAC_BASE_API_URL'] = 'http://127.0.0.1:3000';
    }
    if (!Platform.environment.containsKey('STAC_GOOGLE_CLIENT_ID')) {
      environment['STAC_GOOGLE_CLIENT_ID'] = 'local_stub_google_client';
    }
    if (!Platform.environment.containsKey('STAC_FIREBASE_API_KEY')) {
      environment['STAC_FIREBASE_API_KEY'] = 'local_stub_firebase_key';
    }

    return environment;
  }
}

class _BuildCommand {
  const _BuildCommand({
    required this.source,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  final String source;
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
}
