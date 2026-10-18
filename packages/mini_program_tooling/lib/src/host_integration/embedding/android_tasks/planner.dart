import 'dart:io';

import 'package:path/path.dart' as p;

import '../../capabilities/android/integration_editor.dart';
import '../../capabilities/models.dart';
import '../models.dart';
import 'dart_templates.dart';
import 'native_templates.dart';
import 'source_editors.dart';

/// Builds the complete native write plan without changing the host project.
Future<Map<String, String>> planAndroidSeparateTasks({
  required String projectRootPath,
  required Map<String, String> platformFiles,
}) async {
  final mainDart = File(p.join(projectRootPath, 'lib', 'main.dart'));
  final manifest = File(
    p.join(
      projectRootPath,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  final kotlinRoot = Directory(
    p.join(projectRootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await mainDart.exists() ||
      !await manifest.exists() ||
      !await kotlinRoot.exists()) {
    throw const MiniProgramEmbeddingInitException(
      '--android-separate-tasks requires lib/main.dart and an Android Flutter '
      'host with a Kotlin MainActivity.kt. Add Android/Kotlin support first.',
    );
  }
  final activities = await kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
  if (activities.length != 1) {
    throw MiniProgramEmbeddingInitException(
      'Android separate task setup expected exactly one Kotlin MainActivity.kt, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final source = await mainActivity.readAsString();
  final packageName = RegExp(
    r'^package\s+([A-Za-z_][A-Za-z0-9_.]*)\s*;?\s*$',
    multiLine: true,
  ).firstMatch(source)?.group(1);
  if (packageName == null) {
    throw const MiniProgramEmbeddingInitException(
      'MainActivity.kt is missing its Kotlin package.',
    );
  }
  try {
    final integration = await buildAndroidNativeIntegrationEdit(
      mainActivityFile: mainActivity,
      packageName: packageName,
      mainActivitySource: source,
      registration: 'MiniProgramTaskChannel.register(flutterEngine)',
    );
    final generated = <String, String>{
      integration.paths
          .generatedFile('tasks', 'MiniProgramTaskChannel.kt')
          .path: buildAndroidTaskChannel(
        packageName,
      ),
      integration.paths
          .generatedFile('tasks', 'MiniProgramTaskActivity.kt')
          .path: buildAndroidTaskActivity(
        packageName,
      ),
      integration.paths.generatedFile('tasks', 'MiniProgramTaskSlots.kt').path:
          buildAndroidTaskSlots(packageName),
      p.join(
        projectRootPath,
        'lib',
        'mini_program',
        'mini_program_android_tasks.dart',
      ): buildAndroidTasksDart(),
    };
    for (final entry in generated.entries) {
      final file = File(entry.key);
      if (await file.exists() &&
          !(await file.readAsString()).contains(androidTasksGeneratedMarker)) {
        throw MiniProgramEmbeddingInitException(
          'Refusing to overwrite the unrecognized Android task file ${file.path}. '
          'Move or reconcile it before retrying.',
        );
      }
    }
    final hostSetup = File(
      p.join(
        projectRootPath,
        'lib',
        'mini_program',
        'app_android_task_setup.dart',
      ),
    );
    return <String, String>{
      ...integration.writes,
      ...generated,
      if (!await hostSetup.exists())
        hostSetup.path: buildAndroidTaskHostSetup(),
      mainDart.path: patchAndroidTaskDartEntrypoint(
        await mainDart.readAsString(),
      ),
      manifest.path: patchAndroidTaskManifest(
        platformFiles[manifest.path] ?? await manifest.readAsString(),
        packageName,
      ),
    };
  } on MiniProgramHostCapabilityException catch (error) {
    throw MiniProgramEmbeddingInitException(error.message);
  }
}
