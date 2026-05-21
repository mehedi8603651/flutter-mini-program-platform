import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('LocalBackendInitializer', () {
    late Directory tempDir;
    late Directory templateRoot;
    late LocalCliStateStore stateStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_backend_init_',
      );
      templateRoot = Directory(p.join(tempDir.path, 'template'));
      await Directory(
        p.join(templateRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await Directory(
        p.join(templateRoot.path, 'backend', 'api', 'manifests'),
      ).create(recursive: true);
      await File(
        p.join(
          templateRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsString('void main() {}');
      await File(
        p.join(
          templateRoot.path,
          'backend',
          'local_backend_service',
          'pubspec.yaml',
        ),
      ).writeAsString('name: local_backend_service');
      await File(
        p.join(templateRoot.path, 'backend', 'api', 'manifests', '.gitkeep'),
      ).writeAsString('');

      stateStore = LocalCliStateStore(
        homeDirectoryPath: p.join(tempDir.path, 'fake_home'),
        localAppDataDirectoryPath: p.join(tempDir.path, 'fake_local_app_data'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'copies the template and writes local/global workspace state',
      () async {
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        final initializer = LocalBackendInitializer(
          stateStore: stateStore,
          templateRootPath: templateRoot.path,
        );

        final result = await initializer.initialize(
          LocalBackendInitRequest(backendRootPath: backendRoot),
        );

        expect(result.backendRootPath, backendRoot);
        expect(
          await File(
            p.join(
              backendRoot,
              'backend',
              'local_backend_service',
              'bin',
              'server.dart',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            stateStore.backendWorkspaceStatePath(backendRoot),
          ).exists(),
          isTrue,
        );
        expect(
          await File(stateStore.globalBackendWorkspaceStatePath()).exists(),
          isTrue,
        );

        final localState = await stateStore.readBackendWorkspaceState(
          backendRoot,
        );
        expect(localState, isNotNull);
        expect(localState!.backendRootPath, backendRoot);
        expect(
          localState.serviceDirectoryPath,
          p.join(backendRoot, 'backend', 'local_backend_service'),
        );
      },
    );

    test(
      'defaults to the per-user global backend workspace when root is omitted',
      () async {
        final initializer = LocalBackendInitializer(
          stateStore: stateStore,
          templateRootPath: templateRoot.path,
        );

        final result = await initializer.initialize(
          const LocalBackendInitRequest(),
        );

        final expectedRoot = p.join(
          tempDir.path,
          'fake_local_app_data',
          'mini_program',
          'backend',
        );
        expect(result.backendRootPath, expectedRoot);
        expect(
          await File(
            p.join(
              expectedRoot,
              'backend',
              'local_backend_service',
              'bin',
              'server.dart',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(stateStore.globalBackendWorkspaceStatePath()).exists(),
          isTrue,
        );
      },
    );
  });
}
