import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('PublisherBackendStarter parity', () {
    late Directory tempDirectory;
    late Directory miniProgramRoot;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'publisher_backend_starter_parity_',
      );
      miniProgramRoot = Directory(path.join(tempDirectory.path, 'weather'));
      await miniProgramRoot.create(recursive: true);
      await File(
        path.join(miniProgramRoot.path, 'manifest.json'),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'id': 'weather',
          'version': '1.0.0',
          'entry': 'weather_home',
        }),
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('preserves generated scaffold bytes and created path order', () async {
      final result = await const PublisherBackendStarter().scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      );
      final backendRoot = path.join(miniProgramRoot.path, 'backend', 'mock');

      expect(result.createdPaths, <String>[
        path.join(backendRoot, 'README.md'),
        path.join(backendRoot, 'bin', 'server.dart'),
        path.join(backendRoot, 'data', 'coupons_list.json'),
        path.join(backendRoot, 'data', 'home_bootstrap.json'),
        path.join(backendRoot, 'data', 'session.json'),
        path.join(backendRoot, 'pubspec.yaml'),
      ]);
      expect(
        await File(path.join(backendRoot, 'pubspec.yaml')).readAsString(),
        'name: weather_mock_backend\n'
        'description: Local mock Publisher API for weather.\n'
        'publish_to: none\n'
        '\n'
        'environment:\n'
        "  sdk: '>=3.9.0 <4.0.0'\n",
      );
      expect(
        await File(
          path.join(backendRoot, 'data', 'home_bootstrap.json'),
        ).readAsString(),
        '{\n'
        '  "title": "Weather Publisher API mock",\n'
        '  "subtitle": "Loaded from the publisher-owned mock API.",\n'
        '  "user": {\n'
        '    "id": "preview-user",\n'
        '    "name": "Preview User",\n'
        '    "tier": "Gold"\n'
        '  },\n'
        '  "heroImageUrl": "https://picsum.photos/seed/weather_hero/960/480"\n'
        '}',
      );
    });

    test(
      'preserves launcher bytes, process invocation, and state JSON',
      () async {
        await const PublisherBackendStarter().scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
          ),
        );

        var healthCalls = 0;
        String? startedExecutable;
        List<String>? startedArguments;
        String? startedWorkingDirectory;
        final starter = PublisherBackendStarter(
          processStarter:
              ({
                required String executable,
                required List<String> arguments,
                required String workingDirectory,
              }) async {
                startedExecutable = executable;
                startedArguments = List<String>.of(arguments);
                startedWorkingDirectory = workingDirectory;
                return const StartedPublisherBackendProcess(pid: 2468);
              },
          healthGetter: (uri) async {
            healthCalls += 1;
            return healthCalls == 1
                ? http.Response('offline', 503)
                : http.Response('ok', 200);
          },
          clock: () => DateTime.utc(2026, 7, 18, 12),
          delay: (duration) async {},
        );

        final result = await starter.run(
          miniProgramRootPath: miniProgramRoot.path,
          port: 9191,
        );

        final stateDirectory = path.join(miniProgramRoot.path, '.mini_program');
        final backendRoot = path.join(miniProgramRoot.path, 'backend', 'mock');
        final launcherPath = path.join(
          stateDirectory,
          Platform.isWindows
              ? 'publisher_backend.local.runner.cmd'
              : 'publisher_backend.local.runner.sh',
        );
        final stdoutPath = path.join(
          stateDirectory,
          'publisher_backend.local.out.log',
        );
        final stderrPath = path.join(
          stateDirectory,
          'publisher_backend.local.err.log',
        );
        final serverPath = path.join(backendRoot, 'bin', 'server.dart');
        final expectedScript = Platform.isWindows
            ? <String>[
                '@echo off',
                'setlocal',
                'cd /d ${_cmd(backendRoot)}',
                '${_cmd(Platform.resolvedExecutable)} ${_cmd(serverPath)} '
                    '"--host=0.0.0.0" "--port=9191" '
                    '1>>${_cmd(stdoutPath)} 2>>${_cmd(stderrPath)}',
              ].join('\r\n')
            : <String>[
                '#!/usr/bin/env sh',
                'set -eu',
                'cd ${_sh(backendRoot)}',
                'exec ${_sh(Platform.resolvedExecutable)} ${_sh(serverPath)} '
                    '${_sh('--host=0.0.0.0')} ${_sh('--port=9191')} '
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
        expect(
          await File(
            path.join(stateDirectory, 'publisher_backend.local.json'),
          ).readAsString(),
          const JsonEncoder.withIndent('  ').convert(result.state.toJson()),
        );
        expect(result.state.startedAtUtc, '2026-07-18T12:00:00.000Z');
      },
    );

    test('preserves exact invalid-port failures', () async {
      final starter = const PublisherBackendStarter();

      expect(
        () => starter.urls(port: 0),
        throwsA(
          isA<PublisherBackendException>().having(
            (error) => error.message,
            'message',
            'publisher-backend urls --port must be 1-65535.',
          ),
        ),
      );
      await expectLater(
        starter.run(miniProgramRootPath: miniProgramRoot.path, port: 65536),
        throwsA(
          isA<PublisherBackendException>().having(
            (error) => error.message,
            'message',
            'publisher-backend run --port must be 1-65535.',
          ),
        ),
      );
    });
  });
}

String _cmd(String value) => '"${value.replaceAll('"', '""')}"';

String _sh(String value) => "'${value.replaceAll("'", r"'\''")}'";
