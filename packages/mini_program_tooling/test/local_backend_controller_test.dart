import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('LocalBackendController', () {
    late Directory tempDir;
    late Directory repoRoot;
    late Set<int> alivePids;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_backend_controller_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'api', 'rollout-rules'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsString('void main() {}');
      alivePids = <int>{};
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('start, status, and stop use backend state tracking', () async {
      final controller = LocalBackendController(
        enableAdbReverse: false,
        processStarter:
            ({
              required String executable,
              required List<String> arguments,
              required String workingDirectory,
            }) async {
              alivePids.add(4321);
              return StartedBackendProcess(
                pid: 4321,
                stdout: Stream<List<int>>.fromIterable(const <List<int>>[]),
                stderr: Stream<List<int>>.fromIterable(const <List<int>>[]),
                exitCode: Completer<int>().future,
              );
            },
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              if (executable == Platform.resolvedExecutable &&
                  arguments.length == 2 &&
                  arguments.first == 'pub' &&
                  arguments.last == 'get') {
                return ProcessResult(0, 0, '', '');
              }
              if (executable == 'tasklist' || executable == 'ps') {
                final pid = executable == 'tasklist'
                    ? int.parse(arguments[1].split(' ').last)
                    : int.parse(arguments.last);
                if (alivePids.contains(pid)) {
                  return executable == 'tasklist'
                      ? ProcessResult(
                          0,
                          0,
                          '"cmd.exe","$pid","Console","1","10,000 K"',
                          '',
                        )
                      : ProcessResult(
                          0,
                          0,
                          '  PID TTY          TIME CMD\n $pid ?        00:00:00 sh',
                          '',
                        );
                }
                return executable == 'tasklist'
                    ? ProcessResult(0, 0, 'INFO: No tasks are running', '')
                    : ProcessResult(1, 1, '', '');
              }
              if (executable == 'taskkill' || executable == 'kill') {
                final pid = executable == 'taskkill'
                    ? int.parse(arguments[1])
                    : int.parse(arguments.last);
                alivePids.remove(pid);
                return ProcessResult(0, 0, '', '');
              }
              throw StateError(
                'Unexpected shell command: $executable $arguments',
              );
            },
        healthGetter: (Uri uri) async {
          if (alivePids.contains(4321)) {
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('offline', 503);
        },
        clock: () => DateTime.utc(2026, 4, 9, 9, 30),
      );

      final startResult = await controller.start(repoRootPath: repoRoot.path);
      expect(startResult.alreadyRunning, isFalse);
      expect(startResult.state.pid, 4321);
      expect(
        await File(
          p.join(repoRoot.path, '.mini_program', 'backend.local.json'),
        ).exists(),
        isTrue,
      );

      final statusResult = await controller.status(repoRootPath: repoRoot.path);
      expect(statusResult.hasState, isTrue);
      expect(statusResult.processAlive, isTrue);
      expect(statusResult.healthy, isTrue);
      expect(statusResult.healthStatusCode, 200);

      final stopResult = await controller.stop(repoRootPath: repoRoot.path);
      expect(stopResult.stopped, isTrue);
      expect(
        await File(
          p.join(repoRoot.path, '.mini_program', 'backend.local.json'),
        ).exists(),
        isFalse,
      );
    });

    test('real launcher writes backend state and can stop cleanly', () async {
      await File(
        p.join(
          repoRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsString(_fakeHttpBackendServerSource);

      final controller = LocalBackendController(enableAdbReverse: false);
      final port = await _findFreePort();

      try {
        final startResult = await controller.start(
          repoRootPath: repoRoot.path,
          port: port,
        );
        expect(startResult.alreadyRunning, isFalse);
        expect(
          await File(
            p.join(repoRoot.path, '.mini_program', 'backend.local.json'),
          ).exists(),
          isTrue,
        );

        final statusResult = await controller.status(
          repoRootPath: repoRoot.path,
        );
        expect(statusResult.hasState, isTrue);
        expect(statusResult.processAlive, isTrue);
        expect(statusResult.healthy, isTrue);
        expect(statusResult.healthStatusCode, 200);

        final stopResult = await controller.stop(repoRootPath: repoRoot.path);
        expect(stopResult.stopped, isTrue);
        expect(
          await File(
            p.join(repoRoot.path, '.mini_program', 'backend.local.json'),
          ).exists(),
          isFalse,
        );
      } finally {
        try {
          await controller.stop(repoRootPath: repoRoot.path);
        } on LocalBackendControlException {
          // Best-effort cleanup for the integration-style launcher test.
        }
      }
    });

    test('resetLocal only removes tracked publish outputs', () async {
      final stateStore = const LocalCliStateStore();
      final controller = LocalBackendController(
        enableAdbReverse: false,
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async => ProcessResult(0, 0, '', ''),
      );

      final latestManifestPath = p.join(
        repoRoot.path,
        'backend',
        'api',
        'manifests',
        'coupon_center',
        'latest.json',
      );
      final versionedManifestPath = p.join(
        repoRoot.path,
        'backend',
        'api',
        'manifests',
        'coupon_center',
        'versions',
        '1.0.0.json',
      );
      final screensDirectoryPath = p.join(
        repoRoot.path,
        'backend',
        'api',
        'screens',
        'coupon_center',
        '1.0.0',
      );
      final rolloutRulePath = p.join(
        repoRoot.path,
        'backend',
        'api',
        'rollout-rules',
        'coupon_center.json',
      );

      await Directory(p.dirname(versionedManifestPath)).create(recursive: true);
      await Directory(screensDirectoryPath).create(recursive: true);
      await File(latestManifestPath).writeAsString('{}');
      await File(versionedManifestPath).writeAsString('{}');
      await File(
        p.join(screensDirectoryPath, 'coupon_center_home.json'),
      ).writeAsString('{}');
      await File(rolloutRulePath).writeAsString('{}');

      await stateStore.recordPublishedArtifact(
        repoRoot.path,
        PublishedLocalArtifactRecord(
          miniProgramId: 'coupon_center',
          version: '1.0.0',
          latestManifestPath: latestManifestPath,
          versionedManifestPath: versionedManifestPath,
          screensDirectoryPath: screensDirectoryPath,
          publishedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
        ),
      );

      final resetResult = await controller.resetLocal(
        repoRootPath: repoRoot.path,
      );

      expect(resetResult.removedPaths, isNotEmpty);
      expect(await File(latestManifestPath).exists(), isFalse);
      expect(await File(versionedManifestPath).exists(), isFalse);
      expect(await Directory(screensDirectoryPath).exists(), isFalse);
      expect(await File(rolloutRulePath).exists(), isTrue);
      expect(
        await File(
          p.join(
            repoRoot.path,
            '.mini_program',
            'published_local_artifacts.json',
          ),
        ).exists(),
        isFalse,
      );
    });

    test('resetLocal removes tracked canonical artifact outputs', () async {
      const stateStore = LocalCliStateStore();
      const controller = LocalBackendController(enableAdbReverse: false);
      final appRoot = p.join(
        repoRoot.path,
        'backend',
        'api',
        'artifacts',
        'coupon_center',
      );
      final versionRoot = p.join(appRoot, '1.0.0');
      final latestManifestPath = p.join(appRoot, 'latest.json');
      final versionedManifestPath = p.join(versionRoot, 'manifest.json');
      final screensDirectoryPath = p.join(versionRoot, 'screens');
      final catalogPath = p.join(appRoot, 'catalog.json');
      final rolloutRulePath = p.join(
        repoRoot.path,
        'backend',
        'api',
        'rollout-rules',
        'coupon_center.json',
      );

      await Directory(screensDirectoryPath).create(recursive: true);
      await Directory(p.join(versionRoot, 'assets')).create(recursive: true);
      await File(latestManifestPath).writeAsString('{}');
      await File(versionedManifestPath).writeAsString('{}');
      await File(p.join(versionRoot, 'release.json')).writeAsString('{}');
      await File(p.join(versionRoot, 'checksums.json')).writeAsString('{}');
      await File(
        p.join(screensDirectoryPath, 'coupon_center_home.json'),
      ).writeAsString('{}');
      await File(
        p.join(versionRoot, 'assets', 'icon.png'),
      ).writeAsBytes(const <int>[1, 2, 3]);
      await File(catalogPath).writeAsString('{}');
      await File(rolloutRulePath).writeAsString('{}');
      await stateStore.recordPublishedArtifact(
        repoRoot.path,
        PublishedLocalArtifactRecord(
          miniProgramId: 'coupon_center',
          version: '1.0.0',
          latestManifestPath: latestManifestPath,
          versionedManifestPath: versionedManifestPath,
          screensDirectoryPath: screensDirectoryPath,
          publishedAtUtc: DateTime.utc(2026, 7, 18).toIso8601String(),
        ),
      );

      final result = await controller.resetLocal(repoRootPath: repoRoot.path);

      expect(result.removedPaths, contains(latestManifestPath));
      expect(result.removedPaths, contains(versionedManifestPath));
      expect(result.removedPaths, contains(screensDirectoryPath));
      expect(result.removedPaths, contains(versionRoot));
      expect(result.removedPaths, contains(catalogPath));
      expect(await Directory(appRoot).exists(), isFalse);
      expect(await File(rolloutRulePath).exists(), isTrue);
      expect(
        await File(
          p.join(
            repoRoot.path,
            '.mini_program',
            'published_local_artifacts.json',
          ),
        ).exists(),
        isFalse,
      );
    });

    test(
      'start configures adb reverse for connected devices when available',
      () async {
        final invokedCommands = <String>[];
        final controller = LocalBackendController(
          processStarter:
              ({
                required String executable,
                required List<String> arguments,
                required String workingDirectory,
              }) async {
                alivePids.add(4321);
                return StartedBackendProcess(
                  pid: 4321,
                  stdout: Stream<List<int>>.fromIterable(const <List<int>>[]),
                  stderr: Stream<List<int>>.fromIterable(const <List<int>>[]),
                  exitCode: Completer<int>().future,
                );
              },
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invokedCommands.add('$executable ${arguments.join(' ')}');
                if (executable == Platform.resolvedExecutable &&
                    arguments.length == 2 &&
                    arguments.first == 'pub' &&
                    arguments.last == 'get') {
                  return ProcessResult(0, 0, '', '');
                }
                if (executable.endsWith('adb.exe') || executable == 'adb.exe') {
                  if (arguments.length == 1 && arguments.first == 'version') {
                    return ProcessResult(
                      0,
                      0,
                      'Android Debug Bridge version',
                      '',
                    );
                  }
                  if (arguments.length == 1 && arguments.first == 'devices') {
                    return ProcessResult(
                      0,
                      0,
                      'List of devices attached\nemulator-5554\tdevice\n',
                      '',
                    );
                  }
                  if (arguments.length == 5 &&
                      arguments[0] == '-s' &&
                      arguments[2] == 'reverse') {
                    return ProcessResult(0, 0, '', '');
                  }
                }
                if (executable == 'tasklist' || executable == 'ps') {
                  final pid = executable == 'tasklist'
                      ? int.parse(arguments[1].split(' ').last)
                      : int.parse(arguments.last);
                  if (alivePids.contains(pid)) {
                    return executable == 'tasklist'
                        ? ProcessResult(
                            0,
                            0,
                            '"cmd.exe","$pid","Console","1","10,000 K"',
                            '',
                          )
                        : ProcessResult(
                            0,
                            0,
                            '  PID TTY          TIME CMD\n $pid ?        00:00:00 sh',
                            '',
                          );
                  }
                  return executable == 'tasklist'
                      ? ProcessResult(0, 0, 'INFO: No tasks are running', '')
                      : ProcessResult(1, 1, '', '');
                }
                if (executable == 'taskkill' || executable == 'kill') {
                  final pid = executable == 'taskkill'
                      ? int.parse(arguments[1])
                      : int.parse(arguments.last);
                  alivePids.remove(pid);
                  return ProcessResult(0, 0, '', '');
                }
                throw StateError(
                  'Unexpected shell command: $executable $arguments',
                );
              },
          healthGetter: (Uri uri) async {
            if (alivePids.contains(4321)) {
              return http.Response('{"ok":true}', 200);
            }
            return http.Response('offline', 503);
          },
          clock: () => DateTime.utc(2026, 4, 9, 9, 30),
        );

        final startResult = await controller.start(repoRootPath: repoRoot.path);

        expect(startResult.reversedDeviceIds, <String>['emulator-5554']);
        expect(
          invokedCommands.any(
            (command) => command.contains('reverse tcp:8080 tcp:8080'),
          ),
          isTrue,
        );
      },
    );
  });
}

Future<int> _findFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

const String _fakeHttpBackendServerSource = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  var bindAddress = InternetAddress.loopbackIPv4;
  var port = 8080;

  for (final argument in arguments) {
    if (argument.startsWith('--host=')) {
      final host = argument.substring('--host='.length);
      bindAddress = host == '0.0.0.0'
          ? InternetAddress.anyIPv4
          : InternetAddress(host);
    } else if (argument.startsWith('--port=')) {
      port = int.parse(argument.substring('--port='.length));
    }
  }

  final server = await HttpServer.bind(bindAddress, port);
  server.listen((request) async {
    if (request.uri.path == '/health') {
      request.response.statusCode = 200;
      request.response.write('ok');
    } else {
      request.response.statusCode = 404;
      request.response.write('not found');
    }
    await request.response.close();
  });

  await Completer<void>().future;
}
''';
