import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('host integration implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'host_integration'),
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
        'capabilities/android/generated_source.dart',
        'capabilities/android/gradle_editor.dart',
        'capabilities/android/integration_editor.dart',
        'capabilities/android/integration_paths.dart',
        'capabilities/android/main_activity_editor.dart',
        'capabilities/android/native_setup.dart',
        'capabilities/camera/android_channel_template.dart',
        'capabilities/camera/dart_provider_template.dart',
        'capabilities/camera/installer.dart',
        'capabilities/camera/source_editors.dart',
        'capabilities/camera/source_files.dart',
        'capabilities/dispatch.dart',
        'capabilities/file_transaction.dart',
        'capabilities/file_transfer/android_channel_template.dart',
        'capabilities/file_transfer/dart_provider_template.dart',
        'capabilities/file_transfer/installer.dart',
        'capabilities/file_transfer/source_editors.dart',
        'capabilities/file_transfer/source_files.dart',
        'capabilities/flashlight/android_channel_template.dart',
        'capabilities/flashlight/dart_provider_template.dart',
        'capabilities/flashlight/installer.dart',
        'capabilities/flashlight/source_editors.dart',
        'capabilities/flashlight/source_files.dart',
        'capabilities/location/android_channel_template.dart',
        'capabilities/location/dart_provider_template.dart',
        'capabilities/location/installer.dart',
        'capabilities/location/source_editors.dart',
        'capabilities/location/source_files.dart',
        'capabilities/media_playback/android_plugin_template.dart',
        'capabilities/media_playback/dart_provider_template.dart',
        'capabilities/media_playback/installer.dart',
        'capabilities/media_playback/source_editors.dart',
        'capabilities/media_playback/source_files.dart',
        'capabilities/models.dart',
        'capabilities/qr/android_channel_template.dart',
        'capabilities/qr/dart_provider_template.dart',
        'capabilities/qr/installer.dart',
        'capabilities/qr/source_editors.dart',
        'capabilities/qr/source_files.dart',
        'capabilities/shared_media/android_registry_template.dart',
        'embedding/android_integration.dart',
        'embedding/dart_templates.dart',
        'embedding/initializer.dart',
        'embedding/models.dart',
        'embedding/pubspec_editor.dart',
        'embedding/readme_template.dart',
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
        isNot(
          contains("import '../../mini_program_embedding_initializer.dart'"),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(
          contains(
            "import '../../mini_program_host_capability_installer.dart'",
          ),
        ),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/host_integration/')));

    final embeddingFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_embedding_initializer.dart',
      ),
    );
    final capabilityFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_host_capability_installer.dart',
      ),
    );
    expect(embeddingFacade.readAsLinesSync().length, lessThan(50));
    expect(capabilityFacade.readAsLinesSync().length, lessThan(60));
    expect(
      embeddingFacade.readAsStringSync(),
      contains('initializeMiniProgramEmbedding(request)'),
    );
    expect(
      capabilityFacade.readAsStringSync(),
      contains('capabilities.dispatchHostCapability(request)'),
    );
  });
}
