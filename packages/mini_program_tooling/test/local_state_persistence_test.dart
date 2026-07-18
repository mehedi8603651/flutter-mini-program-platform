import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('LocalCliStateStore persistence', () {
    late Directory tempDirectory;
    late Directory homeDirectory;
    late Directory localAppDataDirectory;
    late LocalCliStateStore store;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_local_state_',
      );
      homeDirectory = Directory(path.join(tempDirectory.path, 'home'));
      localAppDataDirectory = Directory(
        path.join(tempDirectory.path, 'local-app-data'),
      );
      store = LocalCliStateStore(
        homeDirectoryPath: homeDirectory.path,
        localAppDataDirectoryPath: localAppDataDirectory.path,
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('keeps stable local and global file conventions', () {
      final root = path.join(tempDirectory.path, 'workspace');

      expect(
        store.stateDirectoryPath(root),
        path.join(path.absolute(root), '.mini_program'),
      );
      expect(
        store.backendStatePath(root),
        path.join(path.absolute(root), '.mini_program', 'backend.local.json'),
      );
      expect(
        store.publishedArtifactsPath(root),
        path.join(
          path.absolute(root),
          '.mini_program',
          'published_local_artifacts.json',
        ),
      );
      expect(
        store.environmentStatePath(root),
        path.join(path.absolute(root), '.mini_program', 'env.json'),
      );
      expect(
        store.backendWorkspaceStatePath(root),
        path.join(
          path.absolute(root),
          '.mini_program',
          'backend_workspace.json',
        ),
      );
      expect(
        store.globalEnvironmentStatePath(),
        path.join(homeDirectory.path, '.mini_program', 'global_env.json'),
      );
      expect(
        store.globalBackendWorkspaceStatePath(),
        path.join(
          homeDirectory.path,
          '.mini_program',
          'global_backend_workspace.json',
        ),
      );
    });

    test('preserves backend state JSON bytes and schema order', () async {
      final root = path.join(tempDirectory.path, 'workspace');
      const state = LocalBackendState(
        pid: 42,
        port: 8787,
        bindHost: '127.0.0.1',
        healthCheckUrl: 'http://127.0.0.1:8787/health',
        stdoutLogPath: 'stdout.log',
        stderrLogPath: 'stderr.log',
        startedAtUtc: '2026-07-18T01:02:03.000Z',
      );

      await store.writeBackendState(root, state);

      expect(
        await File(store.backendStatePath(root)).readAsString(),
        '{\n'
        '  "pid": 42,\n'
        '  "port": 8787,\n'
        '  "bindHost": "127.0.0.1",\n'
        '  "healthCheckUrl": "http://127.0.0.1:8787/health",\n'
        '  "stdoutLogPath": "stdout.log",\n'
        '  "stderrLogPath": "stderr.log",\n'
        '  "startedAtUtc": "2026-07-18T01:02:03.000Z"\n'
        '}',
      );
      final restored = await store.readBackendState(root);
      expect(restored?.pid, 42);
      expect(restored?.startedAtUtc, state.startedAtUtc);
    });

    test('replaces matching artifacts and preserves sorted order', () async {
      final root = path.join(tempDirectory.path, 'workspace');
      await store.recordPublishedArtifact(
        root,
        _artifact('weather', '2.0.0', 'first'),
      );
      await store.recordPublishedArtifact(
        root,
        _artifact('calculator', '1.1.0', 'calculator'),
      );
      await store.recordPublishedArtifact(
        root,
        _artifact('weather', '1.0.0', 'older'),
      );
      await store.recordPublishedArtifact(
        root,
        _artifact('weather', '2.0.0', 'replacement'),
      );

      final state = await store.readPublishedArtifactsState(root);
      expect(
        state.records
            .map((record) => '${record.miniProgramId}:${record.version}')
            .toList(),
        <String>['calculator:1.1.0', 'weather:1.0.0', 'weather:2.0.0'],
      );
      expect(state.records.last.latestManifestPath, 'replacement-latest');
    });

    test('preserves malformed JSON failure details', () async {
      final root = path.join(tempDirectory.path, 'workspace');
      final file = File(store.environmentStatePath(root));
      await file.parent.create(recursive: true);
      await file.writeAsString('{');

      await expectLater(
        store.readEnvironmentState(root),
        throwsA(
          isA<LocalCliStateException>()
              .having(
                (error) => error.message,
                'message',
                startsWith('State file contains invalid JSON: ${file.path}\n'),
              )
              .having(
                (error) => error.message,
                'format details',
                contains('Unexpected end of input'),
              ),
        ),
      );
    });

    test(
      'discovers nearest local environment before global fallback',
      () async {
        final root = Directory(path.join(tempDirectory.path, 'workspace'));
        final nested = Directory(path.join(root.path, 'app', 'lib'));
        await nested.create(recursive: true);
        await store.writeEnvironmentState(root.path, _environment(root.path));
        await store.writeGlobalEnvironmentState(_environment(null));

        final local = await store.discoverEnvironmentState(
          currentWorkingDirectory: nested.path,
        );
        expect(local?.scope, 'local');
        expect(local?.rootPath, path.normalize(path.absolute(root.path)));
        expect(local?.filePath, store.environmentStatePath(root.path));

        await File(store.environmentStatePath(root.path)).delete();
        final global = await store.discoverEnvironmentState(
          currentWorkingDirectory: nested.path,
        );
        expect(global?.scope, 'global');
        expect(
          global?.rootPath,
          path.normalize(path.absolute(homeDirectory.path)),
        );
        expect(global?.filePath, store.globalEnvironmentStatePath());
      },
    );

    test(
      'discovers backend workspace from additional roots in order',
      () async {
        final currentRoot = Directory(path.join(tempDirectory.path, 'current'));
        final additionalRoot = Directory(
          path.join(tempDirectory.path, 'additional'),
        );
        final nested = Directory(path.join(additionalRoot.path, 'project'));
        await currentRoot.create(recursive: true);
        await nested.create(recursive: true);
        await store.writeBackendWorkspaceState(
          additionalRoot.path,
          _workspace(additionalRoot.path),
        );

        final resolved = await store.discoverBackendWorkspaceState(
          currentWorkingDirectory: currentRoot.path,
          additionalSearchRoots: <String>[nested.path],
          includeGlobalFallback: false,
        );

        expect(resolved?.scope, 'local');
        expect(
          resolved?.rootPath,
          path.normalize(path.absolute(additionalRoot.path)),
        );
        expect(
          resolved?.state.backendRootPath,
          path.normalize(path.absolute(additionalRoot.path)),
        );
      },
    );
  });
}

PublishedLocalArtifactRecord _artifact(
  String appId,
  String version,
  String marker,
) => PublishedLocalArtifactRecord(
  miniProgramId: appId,
  version: version,
  latestManifestPath: '$marker-latest',
  versionedManifestPath: '$marker-versioned',
  screensDirectoryPath: '$marker-screens',
  publishedAtUtc: '2026-07-18T00:00:00.000Z',
);

LocalCliEnvironmentState _environment(String? repoRootPath) =>
    LocalCliEnvironmentState(
      schemaVersion: 1,
      repoRootPath: repoRootPath,
      activeEnvironment: 'local',
      initializedAtUtc: '2026-07-18T00:00:00.000Z',
      updatedAtUtc: '2026-07-18T00:00:00.000Z',
    );

LocalBackendWorkspaceState _workspace(String rootPath) =>
    LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: rootPath,
      apiRootPath: path.join(rootPath, 'api'),
      serviceDirectoryPath: path.join(rootPath, 'service'),
      initializedAtUtc: '2026-07-18T00:00:00.000Z',
      updatedAtUtc: '2026-07-18T00:00:00.000Z',
    );
