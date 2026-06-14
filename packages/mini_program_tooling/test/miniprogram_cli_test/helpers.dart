part of '../miniprogram_cli_test.dart';

class _FakeLocalBackendController extends LocalBackendController {
  final List<String> calls = <String>[];
  final List<String> repoRootPaths = <String>[];
  int? startedPort;

  @override
  Future<LocalBackendStartResult> start({
    required String repoRootPath,
    int port = 8080,
  }) async {
    calls.add('start');
    repoRootPaths.add(repoRootPath);
    startedPort = port;
    return LocalBackendStartResult(
      state: LocalBackendState(
        pid: 1234,
        port: port,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:$port/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      alreadyRunning: false,
    );
  }

  @override
  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    calls.add('status');
    repoRootPaths.add(repoRootPath);
    return LocalBackendStatusResult(
      state: LocalBackendState(
        pid: 1234,
        port: 9090,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:9090/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      hasState: true,
      processAlive: true,
      healthy: true,
      healthStatusCode: 200,
    );
  }

  @override
  Future<LocalBackendStopResult> stop({required String repoRootPath}) async {
    calls.add('stop');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  @override
  Future<LocalBackendResetResult> resetLocal({
    required String repoRootPath,
  }) async {
    calls.add('reset-local');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendResetResult(removedPaths: <String>[]);
  }
}

class _FakeMiniProgramPreviewController extends MiniProgramPreviewController {
  _FakeMiniProgramPreviewController();

  MiniProgramPreviewRequest? lastRequest;

  @override
  Future<int> preview(
    MiniProgramPreviewRequest request, {
    required StringSink stdoutSink,
    required StringSink stderrSink,
  }) async {
    lastRequest = request;
    return 0;
  }
}

class _FakeMiniProgramHostController extends MiniProgramHostController {
  _FakeMiniProgramHostController();

  MiniProgramHostRunRequest? lastRequest;

  @override
  Future<MiniProgramHostRunResult> run(
    MiniProgramHostRunRequest request,
  ) async {
    lastRequest = request;
    return MiniProgramHostRunResult(
      projectRootPath: request.projectRootPath,
      deviceId: request.deviceId,
      backendApiBaseUrl: request.backendApiBaseUrl,
      invocation: <String>[
        'run',
        '-d',
        request.deviceId,
        '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=${request.backendApiBaseUrl}',
      ],
      exitCode: 0,
    );
  }
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  required String version,
}) async {
  await Directory(p.join(miniProgramRootPath, 'tool')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "$version",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "screenFormat": "mp",
  "screenSchemaVersion": 1,
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''');

  await File(p.join(miniProgramRootPath, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0
''');

  await File(
    p.join(miniProgramRootPath, 'tool', 'build_mp.dart'),
  ).writeAsString(_fakeMpBuildScriptSource(screenId: '${miniProgramId}_home'));
}

String _fakeMpBuildScriptSource({required String screenId}) =>
    '''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  final output = outputIndex == -1 ? 'mp/.build' : arguments[outputIndex + 1];
  final screenDirectory = Directory('\$output/screens');
  await screenDirectory.create(recursive: true);
  await File('\$output/screens/$screenId.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': '$screenId',
      'root': <String, Object?>{
        'type': 'text',
        'props': <String, Object?>{'data': 'Hello'},
      },
    }),
  );
}
''';

Future<void> _writeEmbeddedHostFixture(String hostRootPath) async {
  await Directory(
    p.join(hostRootPath, 'lib', 'mini_program'),
  ).create(recursive: true);
  await File(p.join(hostRootPath, 'pubspec.yaml')).writeAsString('''
name: host_app
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.10.0
''');
  await File(
    p.join(
      hostRootPath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    ),
  ).writeAsString('// generated runtime setup');
}

Future<void> _writeLocalEnvironmentState(
  LocalCliStateStore stateStore,
  String rootPath,
) async {
  await stateStore.writeEnvironmentState(
    rootPath,
    LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: null,
      activeEnvironment: 'local',
      initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    ),
  );
}

