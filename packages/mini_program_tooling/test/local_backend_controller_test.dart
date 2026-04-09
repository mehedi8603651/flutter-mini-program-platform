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
        p.join(repoRoot.path, 'backend', 'local_backend_service'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'api', 'rollout-rules'),
      ).create(recursive: true);
      alivePids = <int>{};
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('start, status, and stop use backend state tracking', () async {
      final controller = LocalBackendController(
        processStarter: ({
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
        shellRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
        }) async {
          if (executable == 'tasklist' || executable == 'ps') {
            final pid = executable == 'tasklist'
                ? int.parse(arguments[1].split(' ').last)
                : int.parse(arguments.last);
            if (alivePids.contains(pid)) {
              return executable == 'tasklist'
                  ? ProcessResult(
                      0,
                      0,
                      '"dart.exe","$pid","Console","1","10,000 K"',
                      '',
                    )
                  : ProcessResult(0, 0, '  PID TTY          TIME CMD\n $pid ?        00:00:00 dart', '');
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
          throw StateError('Unexpected shell command: $executable $arguments');
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

    test('resetLocal only removes tracked publish outputs', () async {
      final stateStore = const LocalCliStateStore();
      final controller = LocalBackendController(
        shellRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
        }) async =>
            ProcessResult(0, 0, '', ''),
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
      await File(p.join(screensDirectoryPath, 'coupon_center_home.json'))
          .writeAsString('{}');
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
  });
}
