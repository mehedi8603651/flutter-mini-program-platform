import 'dart:io';

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

class MiniProgramBuildCommand {
  const MiniProgramBuildCommand({
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

class MiniProgramBuildManifest {
  const MiniProgramBuildManifest({
    required this.miniProgramId,
    required this.entryScreenId,
    required this.screenFormat,
    required this.screenSchemaVersion,
  });

  final String miniProgramId;
  final String entryScreenId;
  final String screenFormat;
  final int? screenSchemaVersion;
}
