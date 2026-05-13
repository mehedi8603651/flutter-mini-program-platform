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
      final launcher = await File(
        p.join(integrationRootPath, 'mini_program_launcher.dart'),
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
      expect(result.createdPaths, hasLength(6));
      expect(
        runtimeSetup,
        contains("const String _hostAppId = 'my_existing_app';"),
      );
      expect(runtimeSetup, contains("const String _hostVersion = '3.2.0';"));
      expect(
        runtimeSetup,
        contains(
          "const String _configuredBackendBaseUrl = String.fromEnvironment(",
        ),
      );
      expect(runtimeSetup, contains("'MINI_PROGRAM_BACKEND_HOST'"));
      expect(runtimeSetup, contains("'MINI_PROGRAM_BACKEND_PORT'"));
      expect(
        runtimeSetup,
        contains('LocalMiniProgramBackendDefaults.resolveBaseUri('),
      );
      expect(runtimeSetup, contains("if (kIsWeb) {"));
      expect(
        runtimeSetup,
        contains(
          "debugPrint(\n    '[mini_program][runtime] Backend base URL: \$backendApiBaseUri '",
        ),
      );
      expect(
        result.createdPaths,
        isNot(
          contains(p.join(integrationRootPath, 'mini_program_routes.dart')),
        ),
      );
      expect(
        result.createdPaths,
        isNot(
          contains(
            p.join(integrationRootPath, 'native_profile_editor_page.dart'),
          ),
        ),
      );
      expect(hostBridge, isNot(contains('MiniProgramRoutes')));
      expect(hostBridge, isNot(contains('navigatorKey')));
      expect(launcher, contains('Future<T?> openAppMiniProgram<T>('));
      expect(
        launcher,
        contains('class AppMiniProgramLauncher extends StatelessWidget'),
      );
      expect(launcher, contains('MiniProgramScope.of(context)'));
      expect(launcher, isNot(contains('MiniProgramLauncherButton')));
      expect(runtimeSetup, isNot(contains('MaterialApp(')));
      expect(barrel, isNot(contains("export 'mini_program_app_shell.dart';")));
      expect(
        barrel,
        contains("export 'package:mini_program_sdk/mini_program_sdk.dart';"),
      );
      expect(barrel, contains("export 'app_host_bridge.dart';"));
      expect(barrel, contains("export 'mini_program_runtime_setup.dart';"));
      expect(barrel, isNot(contains("export 'mini_program_routes.dart';")));
      expect(updatedPubspec, contains('mini_program_sdk: ^0.3.0'));
      expect(updatedPubspec, contains('mini_program_contracts: ^0.1.1'));
      expect(readme, contains('mini_program_sdk: ^0.3.0'));
      expect(readme, contains('mini_program_contracts: ^0.1.1'));
      expect(readme, contains('MiniProgramScope('));
      expect(
        readme,
        contains("import 'package:mini_program_sdk/mini_program_sdk.dart';"),
      );
      expect(
        readme,
        contains("import 'mini_program/mini_program_launcher.dart';"),
      );
      expect(
        readme,
        contains("import 'mini_program/mini_program_runtime_setup.dart';"),
      );
      expect(
        readme,
        isNot(contains("import 'mini_program/mini_program.dart';")),
      );
      expect(readme, contains('flutter run -d emulator-5554'));
      expect(readme, contains('MINI_PROGRAM_BACKEND_HOST'));
      expect(readme, contains('adb reverse'));
      expect(readme, contains('resolved backend base URL'));
      expect(
        readme,
        contains(
          'This package does not own your Flutter app. It only provides mini-program',
        ),
      );
      expect(readme, contains('MiniProgramConfig` is immutable'));
      expect(readme, contains('MiniProgram access key'));
      expect(readme, contains('miniprogram partner package'));
      expect(readme, contains('miniprogram host endpoint import'));
      expect(readme, contains('miniprogram host endpoint add'));
      expect(readme, contains('buildMiniProgramEndpoints()'));
      expect(readme, contains('flutter build apk --release'));
      expect(readme, contains('openAppMiniProgram('));
      expect(readme, isNot(contains('MiniProgramAppShell')));
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
        await File(
          p.join(
            tempDir.path,
            'lib',
            'mini_program',
            'mini_program_routes.dart',
          ),
        ).exists(),
        isFalse,
      );
      expect(hostBridge, contains('final routeName = payload.route;'));
      expect(hostBridge, isNot(contains('MiniProgramRoutes')));
      expect(
        runtimeSetup,
        contains("const String _hostAppId = 'campus_super_app';"),
      );
      expect(runtimeSetup, contains("const String _hostVersion = '9.4.1';"));
      expect(
        runtimeSetup,
        contains('MiniProgramConfig buildMiniProgramConfig'),
      );
    });

    test(
      'generates Android network config for release and local debug access',
      () async {
        await Directory(
          p.join(tempDir.path, 'android', 'app', 'src', 'main'),
        ).create(recursive: true);
        await File(
          p.join(
            tempDir.path,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
        ).writeAsString(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <application android:label="fixture" />\n'
          '</manifest>\n',
        );
        await Directory(
          p.join(tempDir.path, 'android', 'app', 'src', 'debug'),
        ).create(recursive: true);

        final result = await const MiniProgramEmbeddingInitializer().initialize(
          MiniProgramEmbeddingInitRequest(projectRootPath: tempDir.path),
        );

        final mainManifest = await File(
          p.join(
            tempDir.path,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
        ).readAsString();
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
              'main',
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
        expect(
          mainManifest,
          contains(
            '<uses-permission android:name="android.permission.INTERNET"/>',
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
