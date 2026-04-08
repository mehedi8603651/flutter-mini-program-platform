import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramEmbeddingInitializer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_embedding_',
      );
      await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
      await File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsString(_pubspecSource);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates embedding adapter files using pubspec defaults', () async {
      final repoRootPath = p.join(tempDir.path, 'platform_repo');
      await Directory(repoRootPath).create(recursive: true);

      final result = await const MiniProgramEmbeddingInitializer().initialize(
        MiniProgramEmbeddingInitRequest(
          projectRootPath: tempDir.path,
          repoRootPath: repoRootPath,
        ),
      );

      final integrationRootPath = p.join(tempDir.path, 'lib', 'mini_program');
      final runtimeSetup = await File(
        p.join(integrationRootPath, 'mini_program_runtime_setup.dart'),
      ).readAsString();
      final routes = await File(
        p.join(integrationRootPath, 'mini_program_routes.dart'),
      ).readAsString();
      final launcher = await File(
        p.join(integrationRootPath, 'mini_program_launcher.dart'),
      ).readAsString();
      final hostBridge = await File(
        p.join(integrationRootPath, 'app_host_bridge.dart'),
      ).readAsString();
      final readme = await File(
        p.join(integrationRootPath, 'README.md'),
      ).readAsString();

      expect(result.packageName, 'my_existing_app');
      expect(result.hostAppId, 'my_existing_app');
      expect(result.hostVersion, '3.2.0');
      expect(result.nativeRoutePath, '/native/profile-editor');
      expect(result.createdPaths, hasLength(6));
      expect(runtimeSetup, contains("const String _hostAppId = 'my_existing_app';"));
      expect(runtimeSetup, contains("const String _hostVersion = '3.2.0';"));
      expect(routes, contains("static const String nativeProfileEditor = '/native/profile-editor';"));
      expect(hostBridge, contains('MiniProgramRoutes.profileEditorAlias'));
      expect(launcher, contains('Future<T?> openAppMiniProgram<T>('));
      expect(launcher, contains('class AppMiniProgramLauncherButton extends StatelessWidget'));
      expect(
        readme,
        contains(
          'path: ${repoRootPath.replaceAll('\\', '/')}/packages/mini_program_sdk',
        ),
      );
    });

    test('supports custom host metadata and route path', () async {
      final result = await const MiniProgramEmbeddingInitializer().initialize(
        MiniProgramEmbeddingInitRequest(
          projectRootPath: tempDir.path,
          hostAppId: 'campus_super_app',
          hostVersion: '9.4.1',
          nativeRoutePath: '/routes/native/profile-review',
        ),
      );

      final hostBridge = await File(
        p.join(tempDir.path, 'lib', 'mini_program', 'app_host_bridge.dart'),
      ).readAsString();
      final routes = await File(
        p.join(tempDir.path, 'lib', 'mini_program', 'mini_program_routes.dart'),
      ).readAsString();
      final runtimeSetup = await File(
        p.join(tempDir.path, 'lib', 'mini_program', 'mini_program_runtime_setup.dart'),
      ).readAsString();

      expect(result.hostAppId, 'campus_super_app');
      expect(result.hostVersion, '9.4.1');
      expect(result.nativeRoutePath, '/routes/native/profile-review');
      expect(routes, contains("static const String nativeProfileEditor = '/routes/native/profile-review';"));
      expect(hostBridge, contains('MiniProgramRoutes.nativeProfileEditor'));
      expect(runtimeSetup, contains("const String _hostAppId = 'campus_super_app';"));
      expect(runtimeSetup, contains("const String _hostVersion = '9.4.1';"));
    });

    test('fails when the adapter folder already exists and force is false', () async {
      final integrationRoot = Directory(p.join(tempDir.path, 'lib', 'mini_program'));
      await integrationRoot.create(recursive: true);
      await File(p.join(integrationRoot.path, 'README.md')).writeAsString('existing');

      expect(
        () => const MiniProgramEmbeddingInitializer().initialize(
          MiniProgramEmbeddingInitRequest(projectRootPath: tempDir.path),
        ),
        throwsA(isA<MiniProgramEmbeddingInitException>()),
      );
    });

    test('overwrites scaffold-managed files when force is true', () async {
      final integrationRoot = Directory(p.join(tempDir.path, 'lib', 'mini_program'));
      await integrationRoot.create(recursive: true);
      await File(
        p.join(integrationRoot.path, 'app_host_bridge.dart'),
      ).writeAsString('stale');

      final result = await const MiniProgramEmbeddingInitializer().initialize(
        MiniProgramEmbeddingInitRequest(
          projectRootPath: tempDir.path,
          force: true,
        ),
      );

      final hostBridge = await File(
        p.join(integrationRoot.path, 'app_host_bridge.dart'),
      ).readAsString();

      expect(result.createdPaths, isNotEmpty);
      expect(hostBridge, contains('class AppHostBridge implements HostBridge'));
    });
  });
}

const String _pubspecSource = '''
name: my_existing_app
description: Existing app
version: 3.2.0+4

dependencies:
  flutter:
    sdk: flutter
''';
