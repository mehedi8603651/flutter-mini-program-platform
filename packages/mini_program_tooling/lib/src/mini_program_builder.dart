import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

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
    this.mpBuildScriptPath,
    this.skipPubGet = false,
  });

  final String? repoRootPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
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
    this.screenFormat = 'mp',
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
  }) : _processRunner = processRunner;

  final ProcessRunner _processRunner;

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
      miniProgramRootPath: miniProgramRootPath,
      outputDirectoryPath: outputDirectoryPath,
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
      failureLabel: 'Mp build failed for $resolvedMiniProgramId',
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
      await _validateBuildJsonDataAssets(
        screensDirectoryPath: screensDirectoryPath,
        assetsDirectoryPath: p.join(miniProgramRootPath, 'assets'),
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
    return p.normalize(p.join(miniProgramRootPath, 'mp', '.build'));
  }

  Future<_BuildCommand> _resolveBuildCommand({
    required String miniProgramRootPath,
    required String outputDirectoryPath,
    required String? mpBuildScriptPath,
  }) async {
    return _resolveMpBuildCommand(
      miniProgramRootPath: miniProgramRootPath,
      outputDirectoryPath: outputDirectoryPath,
      mpBuildScriptPath: mpBuildScriptPath,
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
    final screenFormat = rawValue == null ? 'mp' : '$rawValue'.trim();
    if (screenFormat.isEmpty) {
      throw MiniProgramBuildException(
        'Manifest screenFormat must not be empty: $manifestPath',
      );
    }
    if (screenFormat == 'mp') {
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
    if (rawValue == null) {
      return 1;
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

Future<void> _validateBuildJsonDataAssets({
  required String screensDirectoryPath,
  required String assetsDirectoryPath,
}) async {
  const maxBytes = 2 * 1024 * 1024;
  const maxDepth = 32;
  const maxMembers = 50000;
  final references = <String, String>{};
  await for (final entity in Directory(
    screensDirectoryPath,
  ).list(followLinks: false)) {
    if (entity is! File || p.extension(entity.path).toLowerCase() != '.json') {
      continue;
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(await entity.readAsString());
    } catch (error) {
      throw MiniProgramBuildException(
        'Built screen JSON could not be parsed: ${entity.path}\n$error',
      );
    }
    void visit(Object? value, String jsonPath) {
      if (value is Map) {
        if (value['type'] == 'data.loadJsonAsset') {
          final props = value['props'];
          final asset = props is Map ? props['asset'] : null;
          if (asset is! String || asset.trim().isEmpty) {
            throw MiniProgramBuildException(
              'data.loadJsonAsset requires a static asset path in '
              '${entity.path} at $jsonPath.',
            );
          }
          references.putIfAbsent(asset, () => '${entity.path}:$jsonPath');
        }
        for (final entry in value.entries) {
          visit(entry.value, '$jsonPath.${entry.key}');
        }
      } else if (value is List) {
        for (var index = 0; index < value.length; index += 1) {
          visit(value[index], '$jsonPath[$index]');
        }
      }
    }

    visit(decoded, r'$');
  }

  final assetsRoot = p.normalize(p.absolute(assetsDirectoryPath));
  for (final reference in references.entries) {
    final asset = reference.key;
    final validPath =
        asset.length <= 256 &&
        RegExp(
          r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
        ).hasMatch(asset) &&
        !asset.contains('..');
    if (!validPath) {
      throw MiniProgramBuildException(
        'Unsafe JSON data asset path "$asset" referenced by '
        '${reference.value}.',
      );
    }
    final assetPath = p.normalize(
      p.absolute(p.joinAll(<String>[assetsRoot, ...asset.split('/')])),
    );
    if (!p.isWithin(assetsRoot, assetPath)) {
      throw MiniProgramBuildException(
        'JSON data asset escapes the assets directory: $asset',
      );
    }
    final file = File(assetPath);
    if (!await file.exists()) {
      throw MiniProgramBuildException(
        'Referenced JSON data asset was not found: $asset '
        '(from ${reference.value}).',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw MiniProgramBuildException(
        'JSON data asset "$asset" exceeds the $maxBytes byte limit.',
      );
    }
    late final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (error) {
      throw MiniProgramBuildException(
        'Referenced JSON data asset is malformed: $asset\n$error',
      );
    }
    if (data is! Map && data is! List) {
      throw MiniProgramBuildException(
        'JSON data asset root must be an object or list: $asset',
      );
    }
    var members = 0;
    void validateValue(Object? value, int depth) {
      if (depth > maxDepth) {
        throw MiniProgramBuildException(
          'JSON data asset "$asset" exceeds depth $maxDepth.',
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
      if (members > maxMembers) {
        throw MiniProgramBuildException(
          'JSON data asset "$asset" exceeds $maxMembers members.',
        );
      }
    }

    validateValue(data, 1);
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
