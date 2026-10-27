import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  const initializer = MiniProgramEmbeddingInitializer();
  const nativeRoot = 'android/app/src/main/kotlin/com/example/shop';

  Future<void> write(String path, String source) async {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
  }

  Future<String> read(String path) =>
      File(p.join(root.path, path)).readAsString();
  Future<Map<String, String>> snapshot() async => {
    await for (final entity in root.list(recursive: true, followLinks: false))
      if (entity is File)
        p.relative(entity.path, from: root.path): await entity.readAsString(),
  };
  Future<void> initialize({
    bool ai = true,
    bool tasks = true,
    bool force = false,
  }) async {
    await initializer.initialize(
      MiniProgramEmbeddingInitRequest(
        projectRootPath: root.path,
        androidSeparateTasks: tasks,
        aiAssistant: ai,
        force: force,
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('host_ai_embedding_');
    await write(
      'pubspec.yaml',
      'name: test_host\nversion: 1.0.0\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    await write('lib/main.dart', _main);
    await write('$nativeRoot/MainActivity.kt', '''package com.example.shop
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity()
''');
    await write(
      'android/app/src/main/AndroidManifest.xml',
      '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<application><activity android:name=".MainActivity" android:exported="true" /></application>
</manifest>''',
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'standard and task-only setups omit assistant files and host UI changes',
    () async {
      await initialize(ai: false, tasks: false);
      expect(await read('lib/main.dart'), _main);
      await initialize(ai: false, force: true);
      expect(
        await File(
          p.join(root.path, 'lib/mini_program/mini_program_ai.dart'),
        ).exists(),
        isFalse,
      );
      expect(
        await read('lib/main.dart'),
        isNot(contains('buildHostAiOverlay')),
      );
      expect(
        await read('lib/mini_program/mini_program_runtime_setup.dart'),
        isNot(contains('hostAiInteractionController')),
      );
    },
  );

  test(
    'opt-in wires main host, task presentation and one native shared relay',
    () async {
      await initialize();
      final main = await read('lib/main.dart');
      expect(main, contains('builder: mini_program_ai.buildHostAiOverlay'));
      expect(
        main,
        contains('mini_program_task_setup.runHostMiniProgramTask()'),
      );
      expect(main, contains("title: 'My host'"));
      expect(
        await read('lib/mini_program/mini_program_android_tasks.dart'),
        contains('HostAiTaskOverlay('),
      );
      expect(
        await read('lib/mini_program/mini_program_runtime_setup.dart'),
        contains('interactionController: hostAiInteractionController'),
      );
      final native = await read(
        '$nativeRoot/mini_program/generated/tasks/HostAiSessionRelay.kt',
      );
      expect(native, contains('package com.example.shop'));
      expect(native, contains('OnWindowFocusChangeListener'));
      expect(native, contains('activity !is MainActivity'));
      expect(
        await read(
          '$nativeRoot/mini_program/generated/tasks/MiniProgramTaskChannel.kt',
        ),
        contains('HostAiSessionRelay.register(flutterEngine)'),
      );
      expect(
        await read('lib/mini_program/app_ai_setup.dart'),
        contains('modelFactory: unconfiguredHostAiModel'),
      );
      final model = await read('lib/mini_program/ai/host_ai_model.dart');
      expect(model, contains('abstract interface class HostAiModel'));
      expect(model, isNot(contains('OPENROUTER')));
      expect(model, isNot(contains('gpt-')));
      expect(await read('pubspec.yaml'), isNot(contains('analyzer:')));
    },
  );

  test('force refresh retains assistant and all host-owned settings', () async {
    await initialize();
    const settings =
        '// Host configuration remains private.\nHostAiSettings buildHostAiSettings() => customSettings;\n';
    await write('lib/mini_program/app_ai_setup.dart', settings);
    await write(
      'lib/mini_program/mini_program_policies.json',
      '{"accepted":true}',
    );
    final before = await snapshot();
    await initialize(force: true);
    expect(await snapshot(), before);
    await initialize(ai: false, tasks: false, force: true);
    expect(await snapshot(), before);
  });

  test(
    'installs into a separate app library and composes its original builder',
    () async {
      await write(
        'lib/main.dart',
        "import 'app.dart';\nvoid main() => runApp(const MyApp());\n",
      );
      await write('lib/app.dart', '''import 'package:flutter/material.dart';
Widget makeApp() => MaterialApp(
  builder: (context, child) => ColoredBox(color: Colors.red, child: child!),
  navigatorKey: myExistingKey,
  home: const Text('unchanged'),
);
''');
      await initialize();
      final app = await read('lib/app.dart');
      expect(
        app,
        contains(
          'mini_program_ai.composeHostAiBuilder((context, child) => ColoredBox',
        ),
      );
      expect(app, contains('navigatorKey: myExistingKey'));
      final before = await snapshot();
      await initialize(force: true);
      expect(await snapshot(), before);
    },
  );

  test(
    'supports MaterialApp.router and ignores constructor text in comments/strings',
    () async {
      await write('lib/main.dart', '''import 'package:flutter/material.dart';
// MaterialApp(home: fake)
const text = 'MaterialApp()';
Widget app() => MaterialApp.router(routerConfig: myRouter);
''');
      await initialize();
      final main = await read('lib/main.dart');
      expect(
        main,
        contains(
          'MaterialApp.router(\n      builder: mini_program_ai.buildHostAiOverlay,routerConfig: myRouter)',
        ),
      );
      expect(main, contains("const text = 'MaterialApp()'"));
    },
  );

  test('requires separate tasks before changing any file', () async {
    final before = await snapshot();
    await expectLater(
      initialize(tasks: false),
      throwsA(isA<MiniProgramEmbeddingInitException>()),
    );
    expect(await snapshot(), before);
  });

  test(
    'a conflicting import prefix fails without overwriting host sources',
    () async {
      await write(
        'lib/main.dart',
        "import 'other.dart' as mini_program_ai;\n$_main",
      );
      final before = await snapshot();
      await expectLater(
        initialize(),
        throwsA(isA<MiniProgramEmbeddingInitException>()),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'composing a const variable fails before creating an invalid root',
    () async {
      await write('lib/main.dart', '''import 'package:flutter/material.dart';
const app = MaterialApp(builder: hostBuilder);
''');
      final before = await snapshot();
      await expectLater(
        initialize(),
        throwsA(isA<MiniProgramEmbeddingInitException>()),
      );
      expect(await snapshot(), before);
    },
  );

  for (final source in [
    'void main() => runApp(const Placeholder());',
    'Widget first() => MaterialApp(); Widget second() => MaterialApp();',
    'Widget app() => MaterialApp(home: );',
  ]) {
    test(
      'ambiguous or malformed host root fails transactionally: $source',
      () async {
        await write('lib/main.dart', source);
        final before = await snapshot();
        await expectLater(
          initialize(),
          throwsA(isA<MiniProgramEmbeddingInitException>()),
        );
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'unrecognized generated-file collision fails before any write',
    () async {
      await write(
        'lib/mini_program/ai/host_ai_model.dart',
        '// Existing host code',
      );
      final before = await snapshot();
      await expectLater(
        initialize(force: true),
        throwsA(isA<MiniProgramEmbeddingInitException>()),
      );
      expect(await snapshot(), before);
    },
  );

  for (final capabilityFirst in [true, false]) {
    test(
      'assistant and capability registration survive either install order: $capabilityFirst',
      () async {
        await initialize(ai: !capabilityFirst);
        await const MiniProgramHostCapabilityInstaller().initialize(
          MiniProgramHostCapabilityInitRequest(
            projectRootPath: root.path,
            capability: 'clipboard',
            platform: 'android',
          ),
        );
        await initialize(force: true);
        final setup = await read(
          '$nativeRoot/mini_program/generated/MiniProgramNativeSetup.kt',
        );
        expect(
          setup,
          contains('MiniProgramClipboardChannel.register(flutterEngine)'),
        );
        expect(
          setup,
          contains('MiniProgramTaskChannel.register(flutterEngine)'),
        );
        expect(
          await read(
            '$nativeRoot/mini_program/generated/tasks/MiniProgramTaskChannel.kt',
          ),
          contains('HostAiSessionRelay.register(flutterEngine)'),
        );
      },
    );
  }

  test('CLI exposes and passes the optional assistant flag', () async {
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    final cli = MiniprogramCli(
      stdoutSink: stdout,
      stderrSink: stderr,
      workingDirectory: root.path,
    );
    expect(await cli.run(['embed', 'init', '--help']), 0);
    expect(stdout.toString(), contains('--ai-assistant'));
    expect(
      await cli.run([
        'embed',
        'init',
        '--project-root',
        root.path,
        '--android-separate-tasks',
        '--ai-assistant',
      ]),
      0,
    );
    expect(stderr.toString(), isEmpty);
    expect(await read('lib/main.dart'), contains('buildHostAiOverlay'));
  });
}

const _main = '''import 'package:flutter/material.dart';
void main() => runApp(const MyApp());
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(title: 'My host', home: Text('Home'));
}
''';
