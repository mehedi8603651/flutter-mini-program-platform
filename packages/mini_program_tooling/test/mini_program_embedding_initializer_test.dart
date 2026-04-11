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
      final appShell = await File(
        p.join(integrationRootPath, 'mini_program_app_shell.dart'),
      ).readAsString();
      final barrel = await File(
        p.join(integrationRootPath, 'mini_program.dart'),
      ).readAsString();
      final hostBridge = await File(
        p.join(integrationRootPath, 'app_host_bridge.dart'),
      ).readAsString();
      final readme = await File(
        p.join(integrationRootPath, 'README.md'),
      ).readAsString();
      final updatedPubspec = await File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).readAsString();

      expect(result.packageName, 'my_existing_app');
      expect(result.hostAppId, 'my_existing_app');
      expect(result.hostVersion, '3.2.0');
      expect(result.nativeRoutePath, '/native/profile-editor');
      expect(result.createdPaths, hasLength(9));
      expect(
        runtimeSetup,
        contains("const String _hostAppId = 'my_existing_app';"),
      );
      expect(runtimeSetup, contains("const String _hostVersion = '3.2.0';"));
      expect(
        runtimeSetup,
        contains(
          "String.fromEnvironment(\n    'MINI_PROGRAM_BACKEND_BASE_URL',",
        ),
      );
      expect(runtimeSetup, contains("return 'http://10.0.2.2:8080/api/';"));
      expect(runtimeSetup, contains("return 'http://127.0.0.1:8080/api/';"));
      expect(
        routes,
        contains(
          "static const String nativeProfileEditor = '/native/profile-editor';",
        ),
      );
      expect(hostBridge, contains('MiniProgramRoutes.profileEditorAlias'));
      expect(launcher, contains('Future<T?> openAppMiniProgram<T>('));
      expect(
        launcher,
        contains('class AppMiniProgramLauncherButton extends StatelessWidget'),
      );
      expect(
        appShell,
        contains('class MiniProgramAppShell extends StatefulWidget'),
      );
      expect(appShell, contains('MiniProgramRuntimeScope('));
      expect(barrel, contains("export 'mini_program_app_shell.dart';"));
      expect(updatedPubspec, contains('mini_program_sdk: ^0.1.1'));
      expect(updatedPubspec, contains('mini_program_contracts: ^0.1.0'));
      expect(
        readme,
        allOf(
          contains('mini_program_sdk: ^0.1.1'),
          contains('mini_program_contracts: ^0.1.0'),
          contains('MiniProgramAppShell('),
          contains('flutter run -d emulator-5554'),
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
      final appShell = await File(
        p.join(
          tempDir.path,
          'lib',
          'mini_program',
          'mini_program_app_shell.dart',
        ),
      ).readAsString();
      final runtimeSetup = await File(
        p.join(
          tempDir.path,
          'lib',
          'mini_program',
          'mini_program_runtime_setup.dart',
        ),
      ).readAsString();

      expect(result.hostAppId, 'campus_super_app');
      expect(result.hostVersion, '9.4.1');
      expect(result.nativeRoutePath, '/routes/native/profile-review');
      expect(
        routes,
        contains(
          "static const String nativeProfileEditor = '/routes/native/profile-review';",
        ),
      );
      expect(hostBridge, contains('MiniProgramRoutes.nativeProfileEditor'));
      expect(appShell, contains('MiniProgramRoutes.nativeProfileEditor'));
      expect(
        runtimeSetup,
        contains("const String _hostAppId = 'campus_super_app';"),
      );
      expect(runtimeSetup, contains("const String _hostVersion = '9.4.1';"));
    });

    test(
      'generates Android debug cleartext config for local backend access',
      () async {
        await Directory(
          p.join(tempDir.path, 'android', 'app', 'src', 'debug'),
        ).create(recursive: true);

        final result = await const MiniProgramEmbeddingInitializer().initialize(
          MiniProgramEmbeddingInitRequest(projectRootPath: tempDir.path),
        );

        final debugManifest = await File(
          p.join(
            tempDir.path,
            'android',
            'app',
            'src',
            'debug',
            'AndroidManifest.xml',
          ),
        ).readAsString();
        final networkSecurityConfig = await File(
          p.join(
            tempDir.path,
            'android',
            'app',
            'src',
            'debug',
            'res',
            'xml',
            'mini_program_network_security_config.xml',
          ),
        ).readAsString();

        expect(
          result.createdPaths,
          contains(
            p.join(
              tempDir.path,
              'android',
              'app',
              'src',
              'debug',
              'AndroidManifest.xml',
            ),
          ),
        );
        expect(
          result.createdPaths,
          contains(
            p.join(
              tempDir.path,
              'android',
              'app',
              'src',
              'debug',
              'res',
              'xml',
              'mini_program_network_security_config.xml',
            ),
          ),
        );
        expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
        expect(
          debugManifest,
          contains(
            'android:networkSecurityConfig="@xml/mini_program_network_security_config"',
          ),
        );
        expect(
          networkSecurityConfig,
          contains('<domain includeSubdomains="true">10.0.2.2</domain>'),
        );
        expect(
          networkSecurityConfig,
          contains('<domain includeSubdomains="true">127.0.0.1</domain>'),
        );
      },
    );

    test(
      'fails when the adapter folder already exists and force is false',
      () async {
        final integrationRoot = Directory(
          p.join(tempDir.path, 'lib', 'mini_program'),
        );
        await integrationRoot.create(recursive: true);
        await File(
          p.join(integrationRoot.path, 'README.md'),
        ).writeAsString('existing');

        expect(
          () => const MiniProgramEmbeddingInitializer().initialize(
            MiniProgramEmbeddingInitRequest(projectRootPath: tempDir.path),
          ),
          throwsA(isA<MiniProgramEmbeddingInitException>()),
        );
      },
    );

    test('overwrites scaffold-managed files when force is true', () async {
      final integrationRoot = Directory(
        p.join(tempDir.path, 'lib', 'mini_program'),
      );
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
