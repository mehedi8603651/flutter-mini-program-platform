import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('preview runtime implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'preview_runtime'),
    );
    final implementationFiles =
        implementationRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => path.extension(file.path) == '.dart')
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(
      implementationFiles
          .map(
            (file) => path
                .relative(file.path, from: implementationRoot.path)
                .replaceAll('\\', '/'),
          )
          .toList(),
      <String>[
        'controller/coordinator.dart',
        'controller/device_transport.dart',
        'controller/models.dart',
        'controller/process_lifecycle.dart',
        'controller/watcher.dart',
        'host/initializer.dart',
        'host/main_template.dart',
        'host/models.dart',
        'host/platform_files.dart',
        'host/pubspec.dart',
        'server/assets.dart',
        'server/bundle_loader.dart',
        'server/models.dart',
        'server/responses.dart',
        'server/runtime.dart',
      ],
    );

    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(
        RegExp(r'^\s*part(?:\s+of)?\s', multiLine: true).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        source,
        isNot(
          contains('package:mini_program_tooling/mini_program_tooling.dart'),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_preview_controller.dart')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_preview_host_initializer.dart')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_preview_server.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/preview_runtime/')));

    final controllerFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_preview_controller.dart',
      ),
    );
    final hostFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_preview_host_initializer.dart',
      ),
    );
    final serverFacade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_preview_server.dart'),
    );

    expect(controllerFacade.readAsLinesSync().length, lessThan(100));
    expect(hostFacade.readAsLinesSync().length, lessThan(50));
    expect(serverFacade.readAsLinesSync().length, lessThan(75));
    expect(
      controllerFacade.readAsStringSync(),
      contains('runMiniProgramPreview('),
    );
    expect(
      hostFacade.readAsStringSync(),
      contains('initializeMiniProgramPreviewHost('),
    );
    expect(serverFacade.readAsStringSync(), contains('PreviewServerRuntime'));
  });
}
