import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_cli_state.dart';
import 'mini_program_publisher.dart';
import 'mini_program_static_publisher.dart';

typedef FirebaseHostingShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

class MiniProgramFirebaseHostingPublishRequest {
  const MiniProgramFirebaseHostingPublishRequest({
    required this.repoRootPath,
    required this.environment,
    required this.miniProgramRootPath,
    this.miniProgramId,
    this.outputPath,
    this.siteId,
    this.mpBuildScriptPath,
    this.skipBuildPubGet = false,
    this.clean = false,
    this.dryRun = false,
  });

  final String repoRootPath;
  final CloudEnvironmentConfiguration environment;
  final String miniProgramRootPath;
  final String? miniProgramId;
  final String? outputPath;
  final String? siteId;
  final String? mpBuildScriptPath;
  final bool skipBuildPubGet;
  final bool clean;
  final bool dryRun;
}

class MiniProgramFirebaseHostingPublishResult {
  const MiniProgramFirebaseHostingPublishResult({
    required this.provider,
    required this.environmentName,
    required this.projectId,
    required this.siteId,
    required this.hostingRootPath,
    required this.publicDirectoryName,
    required this.outputPath,
    required this.firebaseJsonPath,
    required this.deliveryApiBaseUrl,
    required this.staticResult,
    required this.deployed,
    required this.dryRun,
    required this.deployCommand,
    this.deployExitCode,
    this.deployStdout,
    this.deployStderr,
  });

  final String provider;
  final String environmentName;
  final String projectId;
  final String siteId;
  final String hostingRootPath;
  final String publicDirectoryName;
  final String outputPath;
  final String firebaseJsonPath;
  final String deliveryApiBaseUrl;
  final MiniProgramStaticPublishResult staticResult;
  final bool deployed;
  final bool dryRun;
  final List<String> deployCommand;
  final int? deployExitCode;
  final String? deployStdout;
  final String? deployStderr;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'command': 'publish firebase-hosting',
    'provider': provider,
    'environmentName': environmentName,
    'projectId': projectId,
    'siteId': siteId,
    'miniProgramId': staticResult.miniProgramId,
    'version': staticResult.version,
    'screenFormat': staticResult.buildResult.screenFormat,
    if (staticResult.buildResult.screenSchemaVersion != null)
      'screenSchemaVersion': staticResult.buildResult.screenSchemaVersion,
    'hostingRootPath': hostingRootPath,
    'publicDirectoryName': publicDirectoryName,
    'outputPath': outputPath,
    'firebaseJsonPath': firebaseJsonPath,
    'deliveryApiBaseUrl': deliveryApiBaseUrl,
    'deployed': deployed,
    'dryRun': dryRun,
    'cleaned': staticResult.cleaned,
    'writtenFileCount': staticResult.writtenFiles.length,
    'publishedAtUtc': staticResult.publishedAtUtc,
    'deployCommand': deployCommand,
    if (deployExitCode != null) 'deployExitCode': deployExitCode,
    'publisherApiContractCommandText':
        'miniprogram publisher-api contract init --backend-base-url '
        '<publisher-api-url> --public',
    'handoffCommandText':
        'miniprogram publisher-api contract handoff '
        '--delivery-url $deliveryApiBaseUrl --public',
  };
}

class MiniProgramFirebaseHostingPublisher {
  const MiniProgramFirebaseHostingPublisher({
    MiniProgramStaticPublisher staticPublisher =
        const MiniProgramStaticPublisher(),
    FirebaseHostingShellRunner shellRunner = _defaultFirebaseHostingShellRunner,
  }) : _staticPublisher = staticPublisher,
       _shellRunner = shellRunner;

  final MiniProgramStaticPublisher _staticPublisher;
  final FirebaseHostingShellRunner _shellRunner;

  Future<MiniProgramFirebaseHostingPublishResult> publish(
    MiniProgramFirebaseHostingPublishRequest request,
  ) async {
    if (request.environment.provider != 'firebase') {
      throw MiniProgramPublishException(
        'publish --target firebase-hosting requires a Firebase environment. '
        'Environment "${request.environment.name}" uses provider '
        '"${request.environment.provider}".',
      );
    }
    final projectId = _requiredFirebaseValue(request.environment, 'projectId');
    final rootPath = p.normalize(p.absolute(request.miniProgramRootPath));
    final outputPath = p.normalize(
      p.absolute(
        request.outputPath?.trim().isNotEmpty == true
            ? request.outputPath!.trim()
            : p.join(rootPath, 'backend', 'firebase_hosting', 'public'),
      ),
    );
    final hostingRootPath = p.dirname(outputPath);
    final publicDirectoryName = p.basename(outputPath);
    if (publicDirectoryName.trim().isEmpty ||
        publicDirectoryName == '.' ||
        publicDirectoryName == '..') {
      throw const MiniProgramPublishException(
        'Firebase Hosting output path must name a public directory.',
      );
    }
    final siteId = request.siteId?.trim().isNotEmpty == true
        ? request.siteId!.trim()
        : projectId;
    final firebaseJsonPath = p.join(hostingRootPath, 'firebase.json');

    final staticResult = await _staticPublisher.publish(
      MiniProgramStaticPublishRequest(
        repoRootPath: p.normalize(p.absolute(request.repoRootPath)),
        outputPath: outputPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: rootPath,
        mpBuildScriptPath: request.mpBuildScriptPath,
        skipBuildPubGet: request.skipBuildPubGet,
        clean: request.clean,
      ),
    );
    await _writeFirebaseJson(
      firebaseJsonPath: firebaseJsonPath,
      publicDirectoryName: publicDirectoryName,
      siteId: siteId == projectId ? null : siteId,
    );

    final deployCommand = <String>[
      'firebase',
      'deploy',
      '--only',
      'hosting',
      '--project',
      projectId,
      '--config',
      firebaseJsonPath,
    ];
    ProcessResult? deployResult;
    if (!request.dryRun) {
      deployResult = await _shellRunner(
        'firebase',
        deployCommand.sublist(1),
        workingDirectory: hostingRootPath,
      );
      if (deployResult.exitCode != 0) {
        throw MiniProgramPublishException(
          'Firebase Hosting deploy failed with exit code '
                  '${deployResult.exitCode}.\n'
                  '${_stringOutput(deployResult.stderr).trim()}\n'
                  '${_stringOutput(deployResult.stdout).trim()}'
              .trim(),
        );
      }
    }

    return MiniProgramFirebaseHostingPublishResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: projectId,
      siteId: siteId,
      hostingRootPath: hostingRootPath,
      publicDirectoryName: publicDirectoryName,
      outputPath: staticResult.outputPath,
      firebaseJsonPath: firebaseJsonPath,
      deliveryApiBaseUrl: 'https://$siteId.web.app/',
      staticResult: staticResult,
      deployed: deployResult != null && deployResult.exitCode == 0,
      dryRun: request.dryRun,
      deployCommand: deployCommand,
      deployExitCode: deployResult?.exitCode,
      deployStdout: deployResult == null
          ? null
          : _stringOutput(deployResult.stdout),
      deployStderr: deployResult == null
          ? null
          : _stringOutput(deployResult.stderr),
    );
  }

  String _requiredFirebaseValue(
    CloudEnvironmentConfiguration environment,
    String key,
  ) {
    final value = environment.values[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw MiniProgramPublishException(
        'Firebase environment "${environment.name}" is missing "$key". '
        'Run `miniprogram env configure ${environment.name} '
        '--provider firebase ...` again.',
      );
    }
    return value;
  }

  Future<void> _writeFirebaseJson({
    required String firebaseJsonPath,
    required String publicDirectoryName,
    required String? siteId,
  }) async {
    await Directory(p.dirname(firebaseJsonPath)).create(recursive: true);
    final hosting = <String, Object?>{
      if (siteId != null) 'site': siteId,
      'public': publicDirectoryName,
      'ignore': <String>['firebase.json', '**/.*', '**/node_modules/**'],
      'headers': <Object>[
        <String, Object>{
          'source': '**',
          'headers': <Object>[
            <String, String>{
              'key': 'Access-Control-Allow-Origin',
              'value': '*',
            },
            <String, String>{
              'key': 'Access-Control-Allow-Methods',
              'value': 'GET, HEAD, OPTIONS',
            },
            <String, String>{
              'key': 'Access-Control-Allow-Headers',
              'value': 'Content-Type, X-Mini-Program-Access-Key',
            },
          ],
        },
      ],
    };
    final json = <String, Object?>{'hosting': hosting};
    await File(
      firebaseJsonPath,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }
}

Future<ProcessResult> _defaultFirebaseHostingShellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
}

String _stringOutput(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is List<int>) {
    return utf8.decode(value, allowMalformed: true);
  }
  return value.toString();
}
