import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramPreviewServer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_server_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'serves status, manifest, screens, and assets with no-store headers',
      () async {
        final assetRoot = Directory(p.join(tempDir.path, 'assets'));
        await assetRoot.create(recursive: true);
        final assetFile = File(p.join(assetRoot.path, 'hero.png'));
        await assetFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

        final server = MiniProgramPreviewServer();
        await server.start(
          initialBundle: MiniProgramPreviewBundle(
            miniProgramId: 'coupon_center',
            title: 'Coupon Center',
            manifestJson: <String, dynamic>{
              'id': 'coupon_center',
              'version': '1.0.0',
              'entry': 'coupon_center_home',
              'requiredCapabilities': <String>['analytics'],
            },
            screenJsonById: <String, Map<String, dynamic>>{
              'coupon_center_home': <String, dynamic>{
                'type': 'column',
                'children': <Object?>[
                  <String, dynamic>{'type': 'image', 'src': 'assets/hero.png'},
                ],
              },
            },
            assetRootPath: assetRoot.path,
          ),
        );
        addTearDown(server.close);

        final statusResponse = await http.get(
          server.baseUri.resolve('status.json'),
        );
        expect(statusResponse.statusCode, 200);
        expect(statusResponse.headers['cache-control'], 'no-store');
        final statusJson =
            jsonDecode(statusResponse.body) as Map<String, dynamic>;
        expect(statusJson['buildVersion'], 1);
        expect(statusJson['state'], MiniProgramPreviewStates.ready);

        final manifestResponse = await http.get(
          server.baseUri.resolve('manifest.json'),
        );
        expect(manifestResponse.statusCode, 200);

        final screenResponse = await http.get(
          server.baseUri.resolve('screens/coupon_center_home.json'),
        );
        expect(screenResponse.statusCode, 200);
        final screenJson =
            jsonDecode(screenResponse.body) as Map<String, dynamic>;
        final children = screenJson['children'] as List<dynamic>;
        final imageJson = children.single as Map<String, dynamic>;
        expect(
          imageJson['src'],
          server.baseUri.resolve('assets/hero.png').toString(),
        );

        final assetResponse = await http.get(
          server.baseUri.resolve('assets/hero.png'),
        );
        expect(assetResponse.statusCode, 200);
        expect(assetResponse.bodyBytes, const <int>[1, 2, 3]);
      },
    );

    test('keeps the last successful bundle when a rebuild fails', () async {
      final server = MiniProgramPreviewServer();
      await server.start(
        initialBundle: MiniProgramPreviewBundle(
          miniProgramId: 'coupon_center',
          title: 'Coupon Center',
          manifestJson: <String, dynamic>{
            'id': 'coupon_center',
            'version': '1.0.0',
            'entry': 'coupon_center_home',
          },
          screenJsonById: <String, Map<String, dynamic>>{
            'coupon_center_home': <String, dynamic>{'type': 'text'},
          },
        ),
      );
      addTearDown(server.close);

      server.markBuilding();
      server.markBuildFailed('broken build');

      final statusResponse = await http.get(
        server.baseUri.resolve('status.json'),
      );
      final statusJson =
          jsonDecode(statusResponse.body) as Map<String, dynamic>;
      expect(statusJson['state'], MiniProgramPreviewStates.buildFailed);
      expect(statusJson['lastBuildError'], 'broken build');
      expect(statusJson['buildVersion'], 1);

      final manifestResponse = await http.get(
        server.baseUri.resolve('manifest.json'),
      );
      final manifestJson =
          jsonDecode(manifestResponse.body) as Map<String, dynamic>;
      expect(manifestJson['version'], '1.0.0');
    });
  });

  group('MiniProgramPreviewWatcher', () {
    late Directory tempDir;
    late String projectRoot;
    late String watchedFilePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_watcher_');
      projectRoot = p.join(tempDir.path, 'coupon_center');
      watchedFilePath = p.join(projectRoot, 'stac', 'screens', 'home.dart');
      await Directory(p.dirname(watchedFilePath)).create(recursive: true);
      await File(p.join(projectRoot, 'manifest.json')).writeAsString('{}');
      await Directory(p.join(projectRoot, 'assets')).create(recursive: true);
      await Directory(p.join(projectRoot, 'lib')).create(recursive: true);
      await File(
        p.join(projectRoot, 'lib', 'default_stac_options.dart'),
      ).writeAsString('// options');
      await File(watchedFilePath).writeAsString('// screen');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('debounces repeated file changes into one rebuild', () async {
      final watcher = MiniProgramPreviewWatcher(
        debounceDuration: const Duration(milliseconds: 150),
      );
      addTearDown(watcher.stop);

      var rebuildCount = 0;
      await watcher.start(
        rootPath: projectRoot,
        onRebuild: () async {
          rebuildCount += 1;
        },
      );

      await File(watchedFilePath).writeAsString('// change 1', flush: true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await File(watchedFilePath).writeAsString('// change 2', flush: true);

      await _waitFor(
        () => rebuildCount == 1,
        reason: 'expected a single debounced rebuild',
      );
      expect(rebuildCount, 1);
    });

    test('coalesces changes that arrive during an active rebuild', () async {
      final watcher = MiniProgramPreviewWatcher(
        debounceDuration: const Duration(milliseconds: 100),
      );
      addTearDown(watcher.stop);

      var rebuildCount = 0;
      final firstRebuildStarted = Completer<void>();
      final allowFirstRebuildToFinish = Completer<void>();

      await watcher.start(
        rootPath: projectRoot,
        onRebuild: () async {
          rebuildCount += 1;
          if (rebuildCount == 1) {
            firstRebuildStarted.complete();
            await allowFirstRebuildToFinish.future;
          }
        },
      );

      await File(watchedFilePath).writeAsString('// change 1', flush: true);
      await firstRebuildStarted.future.timeout(const Duration(seconds: 5));
      await File(watchedFilePath).writeAsString('// change 2', flush: true);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      allowFirstRebuildToFinish.complete();

      await _waitFor(
        () => rebuildCount == 2,
        reason: 'expected a queued rebuild after the first one finished',
      );
      expect(rebuildCount, 2);
    });

    test('ignores exact stac/.build directory paths', () {
      final ignoredPath = p.join(projectRoot, 'stac', '.build');

      expect(
        MiniProgramPreviewWatcher.isRelevantPath(
          rootPath: projectRoot,
          path: ignoredPath,
        ),
        isFalse,
      );
    });
  });

  group('MiniProgramPreviewController', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_controller_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'aborts before host initialization when the initial build fails',
      () async {
        final hostInitializer = _FakePreviewHostInitializer();
        final controller = MiniProgramPreviewController(
          builder: _FakePreviewBuilder((_) async {
            throw const MiniProgramBuildException('initial build failed');
          }),
          hostInitializer: hostInitializer,
        );

        await expectLater(
          controller.preview(
            MiniProgramPreviewRequest(
              miniProgramId: 'coupon_center',
              miniProgramRootPath: tempDir.path,
              deviceId: 'chrome',
            ),
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
          ),
          throwsA(isA<MiniProgramBuildException>()),
        );
        expect(hostInitializer.invocationCount, 0);
      },
    );

    test(
      'launches flutter run with preview defines after a successful build',
      () async {
        final fixture = await _writePreviewBuildFixture(
          tempDir.path,
          miniProgramId: 'coupon_center',
        );
        final hostInitializer = _FakePreviewHostInitializer();
        PreviewProcessCall? processCall;
        final controller = MiniProgramPreviewController(
          builder: _FakePreviewBuilder((_) async => fixture.buildResult),
          hostInitializer: hostInitializer,
          processStarter:
              ({
                required String executable,
                required List<String> arguments,
                required String workingDirectory,
                Map<String, String>? environment,
              }) async {
                processCall = PreviewProcessCall(
                  executable: executable,
                  arguments: arguments,
                  workingDirectory: workingDirectory,
                );
                return StartedPreviewProcess(
                  pid: 1,
                  stdout: const Stream<List<int>>.empty(),
                  stderr: const Stream<List<int>>.empty(),
                  exitCode: Future<int>.value(0),
                  kill: ([ProcessSignal _ = ProcessSignal.sigterm]) => true,
                );
              },
        );

        final exitCode = await controller.preview(
          MiniProgramPreviewRequest(
            miniProgramId: 'coupon_center',
            miniProgramRootPath: fixture.miniProgramRootPath,
            repoRootPath: fixture.repoRootPath,
            deviceId: 'chrome',
          ),
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
        );

        expect(exitCode, 0);
        expect(hostInitializer.invocationCount, 1);
        expect(processCall, isNotNull);
        expect(processCall!.executable, 'flutter');
        expect(
          processCall!.workingDirectory,
          endsWith('.mini_program${p.separator}preview_host'),
        );
        expect(
          processCall!.arguments,
          containsAll(<String>[
            'run',
            '-d',
            'chrome',
            '--dart-define=MINI_PROGRAM_PREVIEW_MINI_PROGRAM_ID=coupon_center',
            '--dart-define=MINI_PROGRAM_PREVIEW_TITLE=Coupon Center',
          ]),
        );
        expect(
          processCall!.arguments.any(
            (argument) => argument.startsWith(
              '--dart-define=MINI_PROGRAM_PREVIEW_BASE_URL=http://127.0.0.1:',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}

class _FakePreviewBuilder extends MiniProgramBuilder {
  _FakePreviewBuilder(this._build);

  final Future<MiniProgramBuildResult> Function(MiniProgramBuildRequest request)
  _build;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) {
    return _build(request);
  }
}

class _FakePreviewHostInitializer extends MiniProgramPreviewHostInitializer {
  _FakePreviewHostInitializer();

  var invocationCount = 0;

  @override
  Future<MiniProgramPreviewHostInitResult> initialize(
    MiniProgramPreviewHostInitRequest request,
  ) async {
    invocationCount += 1;
    await Directory(request.hostRootPath).create(recursive: true);
    return MiniProgramPreviewHostInitResult(
      hostRootPath: request.hostRootPath,
      managedPaths: <String>[request.hostRootPath],
      usedPathDependencies: request.repoRootPath != null,
    );
  }
}

class PreviewProcessCall {
  const PreviewProcessCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

class _PreviewBuildFixture {
  const _PreviewBuildFixture({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.buildResult,
  });

  final String repoRootPath;
  final String miniProgramRootPath;
  final MiniProgramBuildResult buildResult;
}

Future<_PreviewBuildFixture> _writePreviewBuildFixture(
  String tempRoot, {
  required String miniProgramId,
}) async {
  final repoRootPath = p.join(tempRoot, 'repo');
  final miniProgramRootPath = p.join(
    repoRootPath,
    'mini_programs',
    miniProgramId,
  );
  final screensRootPath = p.join(
    miniProgramRootPath,
    'stac',
    '.build',
    'screens',
  );
  await Directory(screensRootPath).create(recursive: true);
  await Directory(
    p.join(miniProgramRootPath, 'assets'),
  ).create(recursive: true);
  await File(
    p.join(miniProgramRootPath, 'assets', 'hero.png'),
  ).writeAsBytes(const <int>[1, 2, 3], flush: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "title": "Coupon Center",
  "version": "1.0.0",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"]
}
''');
  await File(
    p.join(screensRootPath, '${miniProgramId}_home.json'),
  ).writeAsString('''
{
  "type": "column",
  "children": [
    {
      "type": "image",
      "src": "assets/hero.png"
    }
  ]
}
''');

  return _PreviewBuildFixture(
    repoRootPath: repoRootPath,
    miniProgramRootPath: miniProgramRootPath,
    buildResult: MiniProgramBuildResult(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: miniProgramId,
      outputDirectoryPath: p.join(miniProgramRootPath, 'stac', '.build'),
      screensDirectoryPath: screensRootPath,
      entryScreenJsonPath: p.join(
        screensRootPath,
        '${miniProgramId}_home.json',
      ),
      cliSource: 'test',
      invocation: const <String>['dart', 'run'],
      pubGetRan: false,
    ),
  );
}

Future<void> _waitFor(
  bool Function() condition, {
  required String reason,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  fail('Timed out while waiting: $reason');
}
