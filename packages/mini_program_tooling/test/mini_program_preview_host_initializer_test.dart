import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramPreviewHostInitializer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_host_init_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'bootstraps the managed host and writes local path dependencies',
      () async {
        final hostRootPath = p.join(
          tempDir.path,
          'coupon_center',
          '.mini_program',
          'preview_host',
        );
        final repoRootPath = p.join(tempDir.path, 'repo');
        await Directory(
          p.join(repoRootPath, 'packages', 'mini_program_sdk'),
        ).create(recursive: true);
        await Directory(
          p.join(repoRootPath, 'packages', 'mini_program_contracts'),
        ).create(recursive: true);

        final invocations = <List<String>>[];
        final initializer = MiniProgramPreviewHostInitializer(
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add(<String>[executable, ...arguments]);
                final resolvedHostRoot = p.join(
                  workingDirectory!,
                  arguments.last,
                );
                await Directory(
                  p.join(resolvedHostRoot, 'web'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'windows'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'lib'),
                ).create(recursive: true);
                return ProcessResult(0, 0, '', '');
              },
        );

        final result = await initializer.initialize(
          MiniProgramPreviewHostInitRequest(
            hostRootPath: hostRootPath,
            repoRootPath: repoRootPath,
          ),
        );

        expect(result.usedPathDependencies, isTrue);
        expect(invocations, hasLength(1));

        final pubspec = await File(
          p.join(hostRootPath, 'pubspec.yaml'),
        ).readAsString();
        final expectedSdkPath = p
            .relative(
              p.join(repoRootPath, 'packages', 'mini_program_sdk'),
              from: hostRootPath,
            )
            .replaceAll('\\', '/');
        final expectedContractsPath = p
            .relative(
              p.join(repoRootPath, 'packages', 'mini_program_contracts'),
              from: hostRootPath,
            )
            .replaceAll('\\', '/');
        expect(pubspec, contains('path: $expectedSdkPath'));
        expect(pubspec, contains('path: $expectedContractsPath'));

        final mainDart = await File(
          p.join(hostRootPath, 'lib', 'main.dart'),
        ).readAsString();
        expect(mainDart, contains('PreviewMiniProgramSource'));
        expect(mainDart, contains('PreviewHostBridge'));
        expect(mainDart, contains("status.json"));
        expect(
          mainDart,
          contains('void _applyStatus(PreviewStatus nextStatus)'),
        );
        expect(mainDart, contains('if (!mounted || nextStatus == _status) {'));
        expect(
          mainDart,
          contains('late final CapabilityRegistry _capabilityRegistry;'),
        );
        expect(mainDart, isNot(contains('appBar: AppBar(title: Text(title))')));
        expect(mainDart, contains("title: 'Arguments'"));
        expect(
          mainDart,
          contains('class _PreviewArgumentRow extends StatelessWidget'),
        );
        expect(
          mainDart,
          contains('Preview mode cannot execute your real host-native screen.'),
        );
        expect(mainDart, isNot(contains('SelectableText(prettyArgs)')));
      },
    );

    test(
      'adds Android platform files when emulator preview is requested',
      () async {
        final hostRootPath = p.join(
          tempDir.path,
          'coupon_center',
          '.mini_program',
          'preview_host',
        );

        final invocations = <List<String>>[];
        final initializer = MiniProgramPreviewHostInitializer(
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add(<String>[executable, ...arguments]);
                final resolvedHostRoot = p.join(
                  workingDirectory!,
                  arguments.last,
                );
                await Directory(
                  p.join(resolvedHostRoot, 'android', 'app', 'src', 'debug'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'lib'),
                ).create(recursive: true);
                return ProcessResult(0, 0, '', '');
              },
        );

        await initializer.initialize(
          MiniProgramPreviewHostInitRequest(
            hostRootPath: hostRootPath,
            requiredPlatforms: const <String>{'android'},
          ),
        );

        expect(invocations, hasLength(1));
        expect(invocations.single, contains('--platforms=android'));

        final androidDebugManifest = await File(
          p.join(
            hostRootPath,
            'android',
            'app',
            'src',
            'debug',
            'AndroidManifest.xml',
          ),
        ).readAsString();
        expect(
          androidDebugManifest,
          contains(
            'android:networkSecurityConfig="@xml/mini_program_preview_network_security_config"',
          ),
        );

        final androidNetworkConfig = await File(
          p.join(
            hostRootPath,
            'android',
            'app',
            'src',
            'debug',
            'res',
            'xml',
            'mini_program_preview_network_security_config.xml',
          ),
        ).readAsString();
        expect(
          androidNetworkConfig,
          contains('<base-config cleartextTrafficPermitted="true" />'),
        );
      },
    );

    test(
      'supports Linux platform generation when desktop preview is requested',
      () async {
        final hostRootPath = p.join(
          tempDir.path,
          'coupon_center',
          '.mini_program',
          'preview_host',
        );

        final invocations = <List<String>>[];
        final initializer = MiniProgramPreviewHostInitializer(
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add(<String>[executable, ...arguments]);
                final resolvedHostRoot = p.join(
                  workingDirectory!,
                  arguments.last,
                );
                await Directory(
                  p.join(resolvedHostRoot, 'linux'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'lib'),
                ).create(recursive: true);
                return ProcessResult(0, 0, '', '');
              },
        );

        await initializer.initialize(
          MiniProgramPreviewHostInitRequest(
            hostRootPath: hostRootPath,
            requiredPlatforms: const <String>{'linux'},
          ),
        );

        expect(invocations, hasLength(1));
        expect(invocations.single, contains('--platforms=linux'));
      },
    );

    test(
      'supports iOS platform generation when simulator preview is requested',
      () async {
        final hostRootPath = p.join(
          tempDir.path,
          'coupon_center',
          '.mini_program',
          'preview_host',
        );

        final invocations = <List<String>>[];
        final initializer = MiniProgramPreviewHostInitializer(
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add(<String>[executable, ...arguments]);
                final resolvedHostRoot = p.join(
                  workingDirectory!,
                  arguments.last,
                );
                await Directory(
                  p.join(resolvedHostRoot, 'ios'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'lib'),
                ).create(recursive: true);
                return ProcessResult(0, 0, '', '');
              },
        );

        await initializer.initialize(
          MiniProgramPreviewHostInitRequest(
            hostRootPath: hostRootPath,
            requiredPlatforms: const <String>{'ios'},
          ),
        );

        expect(invocations, hasLength(1));
        expect(invocations.single, contains('--platforms=ios'));
      },
    );

    test(
      'supports macOS platform generation when desktop preview is requested',
      () async {
        final hostRootPath = p.join(
          tempDir.path,
          'coupon_center',
          '.mini_program',
          'preview_host',
        );

        final invocations = <List<String>>[];
        final initializer = MiniProgramPreviewHostInitializer(
          shellRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add(<String>[executable, ...arguments]);
                final resolvedHostRoot = p.join(
                  workingDirectory!,
                  arguments.last,
                );
                await Directory(
                  p.join(resolvedHostRoot, 'macos'),
                ).create(recursive: true);
                await Directory(
                  p.join(resolvedHostRoot, 'lib'),
                ).create(recursive: true);
                return ProcessResult(0, 0, '', '');
              },
        );

        await initializer.initialize(
          MiniProgramPreviewHostInitRequest(
            hostRootPath: hostRootPath,
            requiredPlatforms: const <String>{'macos'},
          ),
        );

        expect(invocations, hasLength(1));
        expect(invocations.single, contains('--platforms=macos'));
      },
    );

    test('uses hosted dependencies when no repo root is available', () async {
      final hostRootPath = p.join(
        tempDir.path,
        'coupon_center',
        '.mini_program',
        'preview_host',
      );
      await Directory(hostRootPath).create(recursive: true);
      await File(p.join(hostRootPath, 'pubspec.yaml')).writeAsString('name: x');
      await Directory(p.join(hostRootPath, 'lib')).create(recursive: true);

      var createCalls = 0;
      final initializer = MiniProgramPreviewHostInitializer(
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              createCalls += 1;
              await Directory(
                p.join(hostRootPath, 'web'),
              ).create(recursive: true);
              await Directory(
                p.join(hostRootPath, 'windows'),
              ).create(recursive: true);
              return ProcessResult(0, 0, '', '');
            },
      );

      final result = await initializer.initialize(
        MiniProgramPreviewHostInitRequest(hostRootPath: hostRootPath),
      );

      expect(result.usedPathDependencies, isFalse);
      expect(createCalls, 1);

      final pubspec = await File(
        p.join(hostRootPath, 'pubspec.yaml'),
      ).readAsString();
      expect(pubspec, contains('mini_program_sdk: ^0.1.3'));
      expect(pubspec, contains('mini_program_contracts: ^0.1.0'));
      expect(pubspec, contains('http: ^1.5.0'));
    });
  });
}
