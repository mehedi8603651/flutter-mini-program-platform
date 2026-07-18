import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('LocalBackendController parity', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_local_backend_parity_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('preserves launcher bytes and process invocation', () async {
      final repoRoot = Directory(path.join(tempDirectory.path, 'repo'));
      final serviceDirectory = Directory(
        path.join(repoRoot.path, 'backend', 'local_backend_service'),
      );
      final serverScript = File(
        path.join(serviceDirectory.path, 'bin', 'server.dart'),
      );
      final apiRoot = Directory(path.join(repoRoot.path, 'backend', 'api'));
      await serverScript.parent.create(recursive: true);
      await serverScript.writeAsString('void main() {}');
      await apiRoot.create(recursive: true);

      var healthCalls = 0;
      String? startedExecutable;
      List<String>? startedArguments;
      String? startedWorkingDirectory;
      final controller = LocalBackendController(
        enableAdbReverse: false,
        processStarter:
            ({
              required String executable,
              required List<String> arguments,
              required String workingDirectory,
            }) async {
              startedExecutable = executable;
              startedArguments = List<String>.of(arguments);
              startedWorkingDirectory = workingDirectory;
              return StartedBackendProcess(
                pid: 2468,
                stdout: const Stream<List<int>>.empty(),
                stderr: const Stream<List<int>>.empty(),
                exitCode: Completer<int>().future,
              );
            },
        healthGetter: (uri) async {
          healthCalls += 1;
          return healthCalls == 1
              ? http.Response('offline', 503)
              : http.Response('ok', 200);
        },
        clock: () => DateTime.utc(2026, 7, 18, 12),
      );

      final result = await controller.start(
        repoRootPath: repoRoot.path,
        port: 9191,
      );

      final stateDirectory = path.join(repoRoot.path, '.mini_program');
      final launcherPath = path.join(
        stateDirectory,
        Platform.isWindows
            ? 'backend.local.runner.cmd'
            : 'backend.local.runner.sh',
      );
      final stdoutPath = path.join(stateDirectory, 'backend.local.out.log');
      final stderrPath = path.join(stateDirectory, 'backend.local.err.log');
      final expectedScript = Platform.isWindows
          ? <String>[
              '@echo off',
              'setlocal',
              'cd /d ${_cmd(serviceDirectory.path)}',
              '${_cmd(Platform.resolvedExecutable)} '
                  '${_cmd(serverScript.path)} "--host=0.0.0.0" '
                  '"--port=9191" ${_cmd('--api-root=${apiRoot.path}')} '
                  '1>>${_cmd(stdoutPath)} 2>>${_cmd(stderrPath)}',
            ].join('\r\n')
          : <String>[
              '#!/usr/bin/env sh',
              'set -eu',
              'cd ${_sh(serviceDirectory.path)}',
              'exec ${_sh(Platform.resolvedExecutable)} '
                  '${_sh(serverScript.path)} ${_sh('--host=0.0.0.0')} '
                  '${_sh('--port=9191')} ${_sh('--api-root=${apiRoot.path}')} '
                  '>>${_sh(stdoutPath)} 2>>${_sh(stderrPath)}',
              '',
            ].join('\n');

      expect(result.state.pid, 2468);
      expect(await File(launcherPath).readAsString(), expectedScript);
      expect(startedExecutable, Platform.isWindows ? 'cmd.exe' : 'sh');
      expect(
        startedArguments,
        Platform.isWindows
            ? <String>['/c', launcherPath]
            : <String>[launcherPath],
      );
      expect(startedWorkingDirectory, stateDirectory);
    });

    test('preserves missing service failure text', () async {
      final repoRoot = path.join(tempDirectory.path, 'repo');
      final expectedService = path.join(
        path.normalize(path.absolute(repoRoot)),
        'backend',
        'local_backend_service',
      );

      await expectLater(
        const LocalBackendController(
          enableAdbReverse: false,
        ).start(repoRootPath: repoRoot),
        throwsA(
          isA<LocalBackendControlException>().having(
            (error) => error.message,
            'message',
            'Local artifact service was not found: $expectedService',
          ),
        ),
      );
    });

    test('preserves tracked reset containment failure', () async {
      final repoRoot = Directory(path.join(tempDirectory.path, 'repo'));
      final manifestRoot = Directory(
        path.join(repoRoot.path, 'backend', 'api', 'manifests'),
      );
      await manifestRoot.create(recursive: true);
      final outsidePath = path.join(tempDirectory.path, 'outside.json');
      const stateStore = LocalCliStateStore();
      await stateStore.recordPublishedArtifact(
        repoRoot.path,
        PublishedLocalArtifactRecord(
          miniProgramId: 'calculator',
          version: '1.0.0',
          latestManifestPath: outsidePath,
          versionedManifestPath: path.join(manifestRoot.path, '1.0.0.json'),
          screensDirectoryPath: path.join(
            repoRoot.path,
            'backend',
            'api',
            'screens',
            'calculator',
          ),
          publishedAtUtc: '2026-07-18T00:00:00.000Z',
        ),
      );

      await expectLater(
        const LocalBackendController(
          enableAdbReverse: false,
        ).resetLocal(repoRootPath: repoRoot.path),
        throwsA(
          isA<LocalBackendControlException>().having(
            (error) => error.message,
            'message',
            'Local reset path escaped backend root: '
                '${path.normalize(path.absolute(outsidePath))}',
          ),
        ),
      );
    });
  });
}

String _cmd(String value) => '"${value.replaceAll('"', '""')}"';

String _sh(String value) => "'${value.replaceAll("'", r"'\''")}'";
