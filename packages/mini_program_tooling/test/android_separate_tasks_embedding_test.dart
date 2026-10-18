import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  const initializer = MiniProgramEmbeddingInitializer();
  const installer = MiniProgramHostCapabilityInstaller();
  const nativeRoot = 'android/app/src/main/kotlin/com/example/shop';
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const setupPath =
      '$nativeRoot/mini_program/generated/MiniProgramNativeSetup.kt';

  Future<File> write(String relativePath, String source) async {
    final file = File(p.join(root.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
    return file;
  }

  Future<String> read(String relativePath) =>
      File(p.join(root.path, relativePath)).readAsString();

  Future<MiniProgramEmbeddingInitResult> initialize({
    bool tasks = true,
    bool force = false,
  }) => initializer.initialize(
    MiniProgramEmbeddingInitRequest(
      projectRootPath: root.path,
      androidSeparateTasks: tasks,
      force: force,
    ),
  );

  Future<Map<String, String>> snapshot() async => <String, String>{
    await for (final entity in root.list(recursive: true, followLinks: false))
      if (entity is File)
        p.relative(entity.path, from: root.path): await entity.readAsString(),
  };

  Future<void> install(String capability) => installer.initialize(
    MiniProgramHostCapabilityInitRequest(
      projectRootPath: root.path,
      capability: capability,
      platform: 'android',
    ),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('android_task_embedding_');
    await write('pubspec.yaml', '''
name: shop_host
version: 1.2.3+4
dependencies:
  flutter:
    sdk: flutter
''');
    await write('lib/main.dart', _mainDart);
    await write('$nativeRoot/MainActivity.kt', _mainActivity);
    await write(manifestPath, _manifest);
    await write(
      'android/app/build.gradle.kts',
      '// Host toolchain and dependencies stay intact.\n',
    );
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'standard initialization preserves the original host and has no task setup',
    () async {
      await initialize(tasks: false);
      expect(await read('lib/main.dart'), _mainDart);
      expect(await read('$nativeRoot/MainActivity.kt'), _mainActivity);
      expect(
        await read(manifestPath),
        contains('android:launchMode="singleTop"'),
      );
      expect(await File(p.join(root.path, setupPath)).exists(), isFalse);
      expect(
        await read('lib/mini_program/mini_program.dart'),
        isNot(contains('android_tasks')),
      );
      expect(await read('pubspec.yaml'), contains('mini_program_sdk: ^0.6.12'));
    },
  );

  test(
    'opt-in creates five slots and a retained entrypoint without replacing host code',
    () async {
      final beforeGradle = await read('android/app/build.gradle.kts');
      final result = await initialize();
      final manifest = await read(manifestPath);
      for (var slot = 0; slot < 5; slot++) {
        expect(
          manifest,
          contains(
            'android:name="com.example.shop.MiniProgramTaskActivity$slot"',
          ),
        );
        expect(
          manifest,
          contains(
            'android:taskAffinity="\${applicationId}.mini_program_task_$slot"',
          ),
        );
      }
      expect(manifest, contains('android:launchMode="singleTask"'));
      expect(
        manifest,
        contains(r'android:taskAffinity="${applicationId}.host"'),
      );
      expect(manifest, contains('android:permission="host.custom.permission"'));
      final mainDart = await read('lib/main.dart');
      expect(mainDart, contains(_mainDart));
      expect(mainDart, contains("@pragma('vm:entry-point')"));
      expect(mainDart, contains('Future<void> miniProgramTaskMain()'));
      final nativeMain = await read('$nativeRoot/MainActivity.kt');
      expect(nativeMain, contains('fun customHostBehavior() = "kept"'));
      expect(
        'MiniProgramNativeSetup.register(flutterEngine)'.allMatches(nativeMain),
        hasLength(1),
      );
      expect(
        await read(setupPath),
        contains('MiniProgramTaskChannel.register(flutterEngine)'),
      );
      final taskActivity = await read(
        '$nativeRoot/mini_program/generated/tasks/MiniProgramTaskActivity.kt',
      );
      expect(taskActivity, contains('FlutterFragmentActivity()'));
      expect(
        taskActivity,
        contains('MiniProgramNativeSetup.register(flutterEngine)'),
      );
      expect(taskActivity, contains('"miniProgramTaskMain"'));
      expect(taskActivity, isNot(contains('finish()')));
      expect(await read('android/app/build.gradle.kts'), beforeGradle);
      expect(await read('pubspec.yaml'), contains('mini_program_sdk: ^0.6.12'));
      expect(
        await read('lib/mini_program/README.md'),
        contains('navigationDelegate: openMiniProgramInAndroidTask'),
      );
      expect(
        result.createdPaths,
        contains(p.join(root.path, 'lib', 'main.dart')),
      );
    },
  );

  test(
    'force rerun is idempotent and a plain refresh retains optional task setup',
    () async {
      await initialize();
      final original = await snapshot();
      await initialize(force: true);
      expect(await snapshot(), original);
      await initialize(tasks: false, force: true);
      expect(await snapshot(), original);
    },
  );

  test(
    'upgrades standard integration while preserving host and imported configuration',
    () async {
      await initialize(tasks: false);
      final hostFiles = <String, String>{
        'mini_program_host_setup.dart':
            '// Custom config\nFuture<void> customSetup() async {}',
        'app_host_bridge.dart': '// Custom bridge',
        'mini_program_endpoints.dart': '// Imported endpoints',
        'mini_program_registry.dart': '// Imported registry',
        'mini_program_policy_resolver.dart': '// Accepted policy resolver',
        'mini_program_policies.json': '{"accepted":true}',
        'app_android_task_setup.dart': '// Custom per-engine bootstrap',
      };
      for (final entry in hostFiles.entries) {
        await write('lib/mini_program/${entry.key}', entry.value);
      }
      await initialize(force: true);
      for (final entry in hostFiles.entries) {
        expect(await read('lib/mini_program/${entry.key}'), entry.value);
      }
    },
  );

  for (final tasksFirst in [true, false]) {
    test(
      'camera/share registration survives tasks ${tasksFirst ? 'before' : 'after'} capabilities',
      () async {
        await initialize(tasks: tasksFirst);
        await install('camera');
        await install('gallery');
        await install('share');
        if (!tasksFirst) await initialize(force: true);
        final nativeSetup = await read(setupPath);
        for (final channel in ['Camera', 'Gallery', 'Share', 'Task']) {
          expect(
            'MiniProgram${channel}Channel.register(flutterEngine)'.allMatches(
              nativeSetup,
            ),
            hasLength(1),
          );
        }
        final mainActivity = await read('$nativeRoot/MainActivity.kt');
        expect(mainActivity, contains('FlutterFragmentActivity()'));
        expect(
          'MiniProgramNativeSetup.register(flutterEngine)'.allMatches(
            mainActivity,
          ),
          hasLength(1),
        );
        expect(
          await read('lib/mini_program/mini_program_host_setup.dart'),
          contains('resolvedCameraProvider'),
        );
        final original = await snapshot();
        await install('camera');
        await install('gallery');
        await install('share');
        await initialize(force: true);
        expect(await snapshot(), original);
      },
    );
  }

  test(
    'full Kotlin package names and existing host affinity are preserved',
    () async {
      await write(
        manifestPath,
        _manifest
            .replaceAll(
              'android:name=".MainActivity"',
              "android:name='com.example.shop.MainActivity'",
            )
            .replaceAll(
              'android:taskAffinity=""',
              'android:taskAffinity="custom.host.task"',
            ),
      );
      await initialize();
      expect(
        await read(manifestPath),
        contains('android:taskAffinity="custom.host.task"'),
      );
    },
  );

  test('main library directives stay ahead of the entrypoint import', () async {
    await write('lib/main.dart', 'library host_entry;\n\n$_mainDart');
    await initialize();
    final main = await read('lib/main.dart');
    expect(
      main.indexOf('library host_entry;'),
      lessThan(main.indexOf('import ')),
    );
    final original = await snapshot();
    await initialize(force: true);
    expect(await snapshot(), original);
  });

  test(
    'normal Dart formatting does not invalidate the retained entrypoint',
    () async {
      await initialize();
      final formatted = await Process.run(Platform.resolvedExecutable, [
        'format',
        p.join(root.path, 'lib', 'main.dart'),
      ]);
      expect(formatted.exitCode, 0, reason: '${formatted.stderr}');
      final main = await read('lib/main.dart');
      await initialize(force: true);
      expect(await read('lib/main.dart'), main);
    },
  );

  for (final conflict in <String, String>{
    '$nativeRoot/mini_program/generated/tasks/MiniProgramTaskChannel.kt':
        '// Host-owned channel',
    setupPath: '// Host-owned native setup',
    'lib/mini_program/mini_program_android_tasks.dart':
        '// Host-owned task delegate',
    'lib/main.dart': 'void main() {}\n// <mini-program-task-entrypoint>',
    manifestPath: _manifest.replaceFirst(
      '</application>',
      '<!-- </mini-program-android-tasks> --></application>',
    ),
    '$nativeRoot/MainActivity.kt': _mainActivity.replaceFirst(
      'super.configureFlutterEngine(flutterEngine)',
      'customEngineSetup(flutterEngine)',
    ),
  }.entries) {
    test(
      'conflict at ${conflict.key} fails before changing any host file',
      () async {
        await write(conflict.key, conflict.value);
        final before = await snapshot();
        await expectLater(
          initialize(force: true),
          throwsA(isA<MiniProgramEmbeddingInitException>()),
        );
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'missing Android support fails without changing pubspec or generating adapters',
    () async {
      await File(p.join(root.path, '$nativeRoot/MainActivity.kt')).delete();
      final before = await snapshot();
      await expectLater(
        initialize(),
        throwsA(isA<MiniProgramEmbeddingInitException>()),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'CLI flag initializes native tasks and is present in command help',
    () async {
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdout,
        stderrSink: stderr,
        workingDirectory: root.path,
      );
      expect(await cli.run(['embed', 'init', '--help']), 0);
      expect(stdout.toString(), contains('--android-separate-tasks'));
      expect(
        await cli.run([
          'embed',
          'init',
          '--project-root',
          root.path,
          '--android-separate-tasks',
        ]),
        0,
      );
      expect(stderr.toString(), isEmpty);
      expect(await File(p.join(root.path, setupPath)).exists(), isTrue);
    },
  );
}

const _mainDart = '''import 'package:flutter/widgets.dart';

void main() { runApp(const Placeholder()); }
''';

const _mainActivity = '''package com.example.shop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        customHostBehavior()
    }

    fun customHostBehavior() = "kept"
}
''';

const _manifest =
    r'''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Host">
        <activity android:name=".MainActivity"
            android:exported="true" android:launchMode="singleTop"
            android:taskAffinity="" android:permission="host.custom.permission">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''';
