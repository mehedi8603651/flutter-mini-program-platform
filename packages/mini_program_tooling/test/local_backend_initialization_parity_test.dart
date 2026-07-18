import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('local backend initialization parity', () {
    late Directory tempDirectory;
    late Directory templateRoot;
    late LocalCliStateStore stateStore;
    late LocalBackendInitializer initializer;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'local_backend_initialization_parity_',
      );
      templateRoot = Directory(p.join(tempDirectory.path, 'template'));
      await Directory(
        p.join(templateRoot.path, 'backend', 'api', 'manifests'),
      ).create(recursive: true);
      await Directory(
        p.join(templateRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await File(
        p.join(templateRoot.path, 'backend', 'api', 'manifests', '.gitkeep'),
      ).writeAsBytes(const <int>[]);
      await File(
        p.join(
          templateRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsBytes(<int>[0, 1, 2, 13, 10, 255]);
      await File(
        p.join(
          templateRoot.path,
          'backend',
          'local_backend_service',
          'pubspec.yaml',
        ),
      ).writeAsString('name: local_backend_service\n');
      stateStore = LocalCliStateStore(
        homeDirectoryPath: p.join(tempDirectory.path, 'home'),
        localAppDataDirectoryPath: p.join(tempDirectory.path, 'local_app_data'),
      );
      initializer = LocalBackendInitializer(
        stateStore: stateStore,
        templateRootPath: templateRoot.path,
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'copy bytes, result paths, and created-path ordering stay stable',
      () async {
        final backendRoot = p.join(tempDirectory.path, 'workspace');

        final result = await initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot),
        );

        expect(
          await File(
            p.join(
              backendRoot,
              'backend',
              'local_backend_service',
              'bin',
              'server.dart',
            ),
          ).readAsBytes(),
          <int>[0, 1, 2, 13, 10, 255],
        );
        final expectedCreatedPaths = <String>[
          p.join(backendRoot, '.mini_program', 'backend_workspace.json'),
          p.join(backendRoot, 'backend'),
          p.join(backendRoot, 'backend', 'api'),
          p.join(backendRoot, 'backend', 'api', 'manifests'),
          p.join(backendRoot, 'backend', 'api', 'manifests', '.gitkeep'),
          p.join(backendRoot, 'backend', 'local_backend_service'),
          p.join(backendRoot, 'backend', 'local_backend_service', 'bin'),
          p.join(
            backendRoot,
            'backend',
            'local_backend_service',
            'bin',
            'server.dart',
          ),
          p.join(
            backendRoot,
            'backend',
            'local_backend_service',
            'pubspec.yaml',
          ),
          stateStore.globalBackendWorkspaceStatePath(),
        ]..sort();
        expect(result.createdPaths, expectedCreatedPaths);
        expect(result.apiRootPath, p.join(backendRoot, 'backend', 'api'));
        expect(
          result.serviceDirectoryPath,
          p.join(backendRoot, 'backend', 'local_backend_service'),
        );
      },
    );

    test(
      'idempotent rerun preserves initialized time and reports state files',
      () async {
        final backendRoot = p.join(tempDirectory.path, 'workspace');
        await initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot),
        );
        final firstState = await stateStore.readBackendWorkspaceState(
          backendRoot,
        );

        final rerun = await initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot),
        );
        final secondState = await stateStore.readBackendWorkspaceState(
          backendRoot,
        );

        expect(secondState!.initializedAtUtc, firstState!.initializedAtUtc);
        expect(
          rerun.createdPaths,
          <String>[
            stateStore.backendWorkspaceStatePath(backendRoot),
            stateStore.globalBackendWorkspaceStatePath(),
          ]..sort(),
        );
      },
    );

    test('conflict without force preserves file and writes no state', () async {
      final backendRoot = p.join(tempDirectory.path, 'workspace');
      final destinationPath = p.join(
        backendRoot,
        'backend',
        'local_backend_service',
        'bin',
        'server.dart',
      );
      await File(destinationPath).create(recursive: true);
      await File(destinationPath).writeAsString('host-owned');

      await expectLater(
        () => initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot),
        ),
        throwsA(
          isA<LocalBackendInitException>().having(
            (error) => error.message,
            'message',
            'Backend init would overwrite an existing file. '
                'Re-run with --force if you want to replace scaffold-managed '
                'files.\n$destinationPath',
          ),
        ),
      );
      expect(await File(destinationPath).readAsString(), 'host-owned');
      expect(
        await File(stateStore.backendWorkspaceStatePath(backendRoot)).exists(),
        isFalse,
      );
      expect(
        await File(stateStore.globalBackendWorkspaceStatePath()).exists(),
        isFalse,
      );
    });

    test(
      'force replaces changed files without reporting them as created',
      () async {
        final backendRoot = p.join(tempDirectory.path, 'workspace');
        final destinationPath = p.join(
          backendRoot,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        );
        await File(destinationPath).create(recursive: true);
        await File(destinationPath).writeAsString('host-owned');

        final result = await initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot, force: true),
        );

        expect(await File(destinationPath).readAsBytes(), <int>[
          0,
          1,
          2,
          13,
          10,
          255,
        ]);
        expect(result.createdPaths, isNot(contains(destinationPath)));
      },
    );

    test('missing explicit template preserves the exact failure', () async {
      final missingTemplatePath = p.join(tempDirectory.path, 'missing');
      final missingInitializer = LocalBackendInitializer(
        stateStore: stateStore,
        templateRootPath: missingTemplatePath,
      );

      await expectLater(
        () => missingInitializer.initialize(
          LocalBackendInitRequest(
            backendRootPath: p.join(tempDirectory.path, 'workspace'),
          ),
        ),
        throwsA(
          isA<LocalBackendInitException>().having(
            (error) => error.message,
            'message',
            'Backend workspace template was not found: $missingTemplatePath',
          ),
        ),
      );
    });

    test('workspace state JSON keeps the stable property order', () async {
      final backendRoot = p.join(tempDirectory.path, 'workspace');
      final result = await initializer.initialize(
        LocalBackendInitRequest(backendRootPath: backendRoot),
      );

      final decoded =
          jsonDecode(await File(result.stateFilePath).readAsString())
              as Map<String, Object?>;
      expect(decoded.keys.toList(), <String>[
        'schemaVersion',
        'backendRootPath',
        'apiRootPath',
        'serviceDirectoryPath',
        'initializedAtUtc',
        'updatedAtUtc',
      ]);
    });
  });
}
