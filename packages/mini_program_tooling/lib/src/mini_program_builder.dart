import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'managed_stac_builder.dart';

typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class MiniProgramBuildRequest {
  const MiniProgramBuildRequest({
    this.repoRootPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.stacCliScriptPath,
    this.mpBuildScriptPath,
    this.skipPubGet = false,
  });

  final String? repoRootPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? stacCliScriptPath;
  final String? mpBuildScriptPath;
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
    this.screenFormat = 'stac',
    this.screenSchemaVersion,
    required this.cliSource,
    required this.invocation,
    required this.pubGetRan,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String outputDirectoryPath;
  final String screensDirectoryPath;
  final String entryScreenJsonPath;
  final String screenFormat;
  final int? screenSchemaVersion;
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
    'screenFormat': screenFormat,
    if (screenSchemaVersion != null) 'screenSchemaVersion': screenSchemaVersion,
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
    ManagedStacBuilder managedStacBuilder = const ManagedStacBuilder(),
  }) : _processRunner = processRunner,
       _managedStacBuilder = managedStacBuilder;

  final ProcessRunner _processRunner;
  final ManagedStacBuilder _managedStacBuilder;

  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async {
    final repoRootPath = request.repoRootPath == null
        ? null
        : p.normalize(p.absolute(request.repoRootPath!));
    final miniProgramRootPath = _resolveMiniProgramRootPath(
      repoRootPath: repoRootPath,
      miniProgramId: request.miniProgramId,
      miniProgramRootPath: request.miniProgramRootPath,
    );
    final miniProgramRootDir = Directory(miniProgramRootPath);

    if (!await miniProgramRootDir.exists()) {
      throw MiniProgramBuildException(
        'Mini-program root does not exist: $miniProgramRootPath',
      );
    }

    final manifestPath = p.join(miniProgramRootPath, 'manifest.json');
    final pubspecPath = p.join(miniProgramRootPath, 'pubspec.yaml');
    for (final path in <String>[manifestPath, pubspecPath]) {
      if (!await File(path).exists()) {
        throw MiniProgramBuildException('Required file is missing: $path');
      }
    }

    final manifest =
        jsonDecode(await File(manifestPath).readAsString())
            as Map<String, dynamic>;
    final resolvedMiniProgramId = '${manifest['id'] ?? ''}'.trim();
    if (resolvedMiniProgramId.isEmpty) {
      throw MiniProgramBuildException(
        'Manifest is missing a usable id: $manifestPath',
      );
    }
    if (request.miniProgramId != null &&
        request.miniProgramId!.trim().isNotEmpty &&
        request.miniProgramId != resolvedMiniProgramId) {
      throw MiniProgramBuildException(
        'Manifest id "$resolvedMiniProgramId" does not match requested id '
        '"${request.miniProgramId}".',
      );
    }

    final entryScreenId = manifest['entry'] as String?;
    if (entryScreenId == null || entryScreenId.trim().isEmpty) {
      throw MiniProgramBuildException(
        'Manifest is missing a usable entry screen: $manifestPath',
      );
    }
    final screenFormat = _resolveScreenFormat(manifest, manifestPath);
    final screenSchemaVersion = _resolveScreenSchemaVersion(
      manifest,
      manifestPath,
      screenFormat: screenFormat,
    );

    final outputDirectoryPath = await _resolveOutputDirectory(
      miniProgramRootPath: miniProgramRootPath,
      screenFormat: screenFormat,
    );
    final screensDirectoryPath = p.join(outputDirectoryPath, 'screens');
    final entryScreenJsonPath = p.join(
      screensDirectoryPath,
      '$entryScreenId.json',
    );

    final command = await _resolveBuildCommand(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      outputDirectoryPath: outputDirectoryPath,
      screenFormat: screenFormat,
      stacCliScriptPath: request.stacCliScriptPath,
      mpBuildScriptPath: request.mpBuildScriptPath,
    );

    if (!request.skipPubGet) {
      await _runOrThrow(
        executable: 'dart',
        arguments: const <String>['pub', 'get'],
        workingDirectory: miniProgramRootPath,
        failureLabel:
            'dart pub get failed for ${request.miniProgramId ?? miniProgramRootPath}',
      );
    }

    await _runOrThrow(
      executable: command.executable,
      arguments: command.arguments,
      workingDirectory: command.workingDirectory,
      environment: command.environment,
      failureLabel:
          '${screenFormat == 'mp' ? 'Mp' : 'Stac'} build failed for $resolvedMiniProgramId',
    );

    if (!await File(entryScreenJsonPath).exists()) {
      throw MiniProgramBuildException(
        'Build completed but entry screen JSON was not found: '
        '$entryScreenJsonPath',
      );
    }
    if (screenFormat == 'mp') {
      await _validateMpEntryScreen(
        entryScreenJsonPath: entryScreenJsonPath,
        entryScreenId: entryScreenId,
        screenSchemaVersion: screenSchemaVersion,
      );
    }

    return MiniProgramBuildResult(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: resolvedMiniProgramId,
      outputDirectoryPath: outputDirectoryPath,
      screensDirectoryPath: screensDirectoryPath,
      entryScreenJsonPath: entryScreenJsonPath,
      screenFormat: screenFormat,
      screenSchemaVersion: screenSchemaVersion,
      cliSource: command.source,
      invocation: <String>[command.executable, ...command.arguments],
      pubGetRan: !request.skipPubGet,
    );
  }

  Future<String> _resolveOutputDirectory({
    required String miniProgramRootPath,
    required String screenFormat,
  }) async {
    if (screenFormat == 'mp') {
      return p.normalize(p.join(miniProgramRootPath, 'mp', '.build'));
    }

    final defaultOptionsPath = p.join(
      miniProgramRootPath,
      'lib',
      'default_stac_options.dart',
    );
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
    required String? repoRootPath,
    required String miniProgramRootPath,
    required String outputDirectoryPath,
    required String screenFormat,
    required String? stacCliScriptPath,
    required String? mpBuildScriptPath,
  }) async {
    if (screenFormat == 'mp') {
      return _resolveMpBuildCommand(
        miniProgramRootPath: miniProgramRootPath,
        outputDirectoryPath: outputDirectoryPath,
        mpBuildScriptPath: mpBuildScriptPath,
      );
    }

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
        workingDirectory: repoRootPath ?? miniProgramRootPath,
        environment: _stacCliEnvironment(),
      );
    }

    ManagedStacBuilderException? managedBuilderError;
    final managedStatus = await _managedStacBuilder.inspect();
    if (managedStatus.bundledTemplateAvailable) {
      try {
        final managedResolution = await _managedStacBuilder.ensureReady();
        return _BuildCommand(
          source: 'managed_pinned_stac',
          executable: 'dart',
          arguments: <String>[
            'run',
            managedResolution.entrypointPath,
            'build',
            '--project',
            miniProgramRootPath,
          ],
          workingDirectory: managedResolution.packageRootPath,
          environment: _stacCliEnvironment(),
        );
      } on ManagedStacBuilderException catch (error) {
        managedBuilderError = error;
      }
    }

    if (repoRootPath != null) {
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
    }

    final globalStacResult = await _processRunner('stac', const <String>[
      '--version',
    ], workingDirectory: repoRootPath ?? miniProgramRootPath);
    if (globalStacResult.exitCode == 0) {
      return _BuildCommand(
        source: 'global_stac',
        executable: 'stac',
        arguments: <String>['build', '--project', miniProgramRootPath],
        workingDirectory: repoRootPath ?? miniProgramRootPath,
        environment: _stacCliEnvironment(),
      );
    }

    if (managedBuilderError != null) {
      throw MiniProgramBuildException(
        '${managedBuilderError.message}\n'
        'Fallbacks: provide --stac-cli-script, restore '
        'stac-dev/packages/stac_cli/bin/stac_cli.dart, or install a global '
        '`stac` command.',
      );
    }

    throw const MiniProgramBuildException(
      'No Stac builder was found. The managed pinned builder template is '
      'missing, and no explicit script, vendored stac-dev CLI, or global '
      '`stac` command was available.',
    );
  }

  Future<_BuildCommand> _resolveMpBuildCommand({
    required String miniProgramRootPath,
    required String outputDirectoryPath,
    required String? mpBuildScriptPath,
  }) async {
    final scriptPath =
        mpBuildScriptPath != null && mpBuildScriptPath.trim().isNotEmpty
        ? p.normalize(p.absolute(mpBuildScriptPath.trim()))
        : p.join(miniProgramRootPath, 'tool', 'build_mp.dart');

    if (!await File(scriptPath).exists()) {
      throw MiniProgramBuildException(
        'Mp build script was not found: $scriptPath\n'
        'Create tool/build_mp.dart or pass --mp-build-script <path>.',
      );
    }

    return _BuildCommand(
      source: mpBuildScriptPath != null && mpBuildScriptPath.trim().isNotEmpty
          ? 'explicit_mp_build_script'
          : 'mp_build_script',
      executable: 'dart',
      arguments: <String>['run', scriptPath, '--output', outputDirectoryPath],
      workingDirectory: miniProgramRootPath,
      environment: const <String, String>{},
    );
  }

  String _resolveScreenFormat(
    Map<String, dynamic> manifest,
    String manifestPath,
  ) {
    final rawValue = manifest['screenFormat'];
    final screenFormat = rawValue == null ? 'stac' : '$rawValue'.trim();
    if (screenFormat.isEmpty) {
      throw MiniProgramBuildException(
        'Manifest screenFormat must not be empty: $manifestPath',
      );
    }
    if (screenFormat == 'stac' || screenFormat == 'mp') {
      return screenFormat;
    }
    throw MiniProgramBuildException(
      'Unsupported manifest screenFormat "$screenFormat": $manifestPath',
    );
  }

  int? _resolveScreenSchemaVersion(
    Map<String, dynamic> manifest,
    String manifestPath, {
    required String screenFormat,
  }) {
    final rawValue = manifest['screenSchemaVersion'];
    if (screenFormat == 'stac') {
      if (rawValue == null) {
        return null;
      }
      if (rawValue is int && rawValue > 0) {
        return rawValue;
      }
      throw MiniProgramBuildException(
        'Manifest screenSchemaVersion must be a positive integer when provided: '
        '$manifestPath',
      );
    }

    if (rawValue == null) {
      throw MiniProgramBuildException(
        'Manifest screenSchemaVersion is required when screenFormat is "mp": '
        '$manifestPath',
      );
    }
    if (rawValue is! int || rawValue <= 0) {
      throw MiniProgramBuildException(
        'Manifest screenSchemaVersion must be a positive integer: '
        '$manifestPath',
      );
    }
    if (rawValue != 1) {
      throw MiniProgramBuildException(
        'Unsupported Mp screenSchemaVersion "$rawValue": $manifestPath',
      );
    }
    return rawValue;
  }

  Future<void> _validateMpEntryScreen({
    required String entryScreenJsonPath,
    required String entryScreenId,
    required int? screenSchemaVersion,
  }) async {
    Object? decoded;
    try {
      decoded = jsonDecode(await File(entryScreenJsonPath).readAsString());
    } on FormatException catch (error) {
      throw MiniProgramBuildException(
        'Mp entry screen JSON could not be parsed: $entryScreenJsonPath\n'
        '${error.message}',
      );
    }

    if (decoded is! Map) {
      throw MiniProgramBuildException(
        'Mp entry screen JSON must be an object: $entryScreenJsonPath',
      );
    }
    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (json['schemaVersion'] != screenSchemaVersion) {
      throw MiniProgramBuildException(
        'Mp entry screen schemaVersion "${json['schemaVersion']}" does not '
        'match manifest screenSchemaVersion "$screenSchemaVersion": '
        '$entryScreenJsonPath',
      );
    }
    if (json['screenId'] != entryScreenId) {
      throw MiniProgramBuildException(
        'Mp entry screenId "${json['screenId']}" does not match manifest entry '
        '"$entryScreenId": $entryScreenJsonPath',
      );
    }
    if (json['root'] is! Map) {
      throw MiniProgramBuildException(
        'Mp entry screen root must be an object: $entryScreenJsonPath',
      );
    }
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

  String _resolveMiniProgramRootPath({
    required String? repoRootPath,
    required String? miniProgramId,
    required String? miniProgramRootPath,
  }) {
    if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(miniProgramRootPath.trim()));
    }

    if (repoRootPath == null ||
        miniProgramId == null ||
        miniProgramId.trim().isEmpty) {
      throw const MiniProgramBuildException(
        'Provide either --mini-program-root or both --repo-root and --id.',
      );
    }

    return p.join(repoRootPath, 'mini_programs', miniProgramId);
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
