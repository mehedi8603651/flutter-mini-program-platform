import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ManagedStacBuilder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_managed_stac_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'copies the bundled template into a user cache and bootstraps it',
      () async {
        final packageRoot = p.join(tempDir.path, 'tooling_package');
        final templateRoot = p.join(
          packageRoot,
          'templates',
          'pinned_stac_cli',
        );
        await Directory(p.join(templateRoot, 'bin')).create(recursive: true);
        await Directory(p.join(templateRoot, 'lib')).create(recursive: true);
        await File(
          p.join(templateRoot, 'pubspec.yaml'),
        ).writeAsString('name: stac_cli');
        await File(
          p.join(templateRoot, 'bin', 'stac_cli.dart'),
        ).writeAsString('void main(List<String> args) {}');
        await File(
          p.join(templateRoot, 'lib', 'stac_cli.dart'),
        ).writeAsString('library stac_cli;');

        final invocations = <String>[];
        final manager = ManagedStacBuilder(
          packageRootPath: packageRoot,
          homeDirectoryPath: p.join(tempDir.path, 'home'),
          processRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                invocations.add('$executable ${arguments.join(' ')}');
                await Directory(
                  p.join(workingDirectory!, '.dart_tool'),
                ).create(recursive: true);
                await File(
                  p.join(workingDirectory, '.dart_tool', 'package_config.json'),
                ).writeAsString('{}');
                return ProcessResult(1, 0, '', '');
              },
        );

        final initialStatus = await manager.inspect();
        expect(initialStatus.bundledTemplateAvailable, isTrue);
        expect(initialStatus.dependenciesResolved, isFalse);

        final resolution = await manager.ensureReady();

        expect(resolution.pinnedVersion, ManagedStacBuilder.pinnedVersion);
        expect(await File(resolution.entrypointPath).exists(), isTrue);
        expect(
          await File(
            p.join(
              resolution.packageRootPath,
              '.dart_tool',
              'package_config.json',
            ),
          ).exists(),
          isTrue,
        );
        expect(invocations, hasLength(1));

        final readyStatus = await manager.inspect();
        expect(readyStatus.ready, isTrue);
      },
    );
  });
}
