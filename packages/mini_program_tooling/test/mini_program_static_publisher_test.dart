import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramStaticPublisher', () {
    late Directory tempDir;
    late Directory miniProgramRoot;
    late String screensDirectoryPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_static_publish_',
      );
      await Directory(
        p.join(tempDir.path, 'mini_programs'),
      ).create(recursive: true);
      miniProgramRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await Directory(
        p.join(miniProgramRoot.path, 'assets'),
      ).create(recursive: true);
      await Directory(
        p.join(miniProgramRoot.path, 'mp', '.build', 'screens'),
      ).create(recursive: true);
      screensDirectoryPath = p.join(
        miniProgramRoot.path,
        'mp',
        '.build',
        'screens',
      );

      await File(p.join(miniProgramRoot.path, 'manifest.json')).writeAsString(
        '''
{
  "id": "coupon_center",
  "version": "1.2.3",
  "entry": "coupon_center_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics"]
}
''',
      );
      await File(
        p.join(screensDirectoryPath, 'coupon_center_home.json'),
      ).writeAsString('''
{"schemaVersion":1,"screenId":"coupon_center_home","root":{"type":"text","props":{"data":"Coupon Center"},"children":[]}}
''');
      await File(
        p.join(miniProgramRoot.path, 'assets', 'icon.png'),
      ).writeAsBytes(<int>[0, 1, 2, 3]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes public static delivery layout', () async {
      final outputPath = p.join(tempDir.path, 'public_mini_program');
      final publisher = MiniProgramStaticPublisher(
        builder: _FakeMiniProgramBuilder(
          MiniProgramBuildResult(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
            miniProgramRootPath: miniProgramRoot.path,
            cliSource: 'fake',
            invocation: const <String>['dart', 'fake'],
            outputDirectoryPath: p.join(miniProgramRoot.path, 'mp', '.build'),
            screensDirectoryPath: screensDirectoryPath,
            entryScreenJsonPath: p.join(
              screensDirectoryPath,
              'coupon_center_home.json',
            ),
            pubGetRan: false,
          ),
        ),
      );

      final result = await publisher.publish(
        MiniProgramStaticPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: miniProgramRoot.path,
          miniProgramId: 'coupon_center',
          outputPath: outputPath,
        ),
      );

      expect(result.outputPath, outputPath);
      expect(result.miniProgramId, 'coupon_center');
      expect(result.version, '1.2.3');
      expect(
        File(
          p.join(outputPath, 'artifacts', 'coupon_center', 'latest.json'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputPath,
            'artifacts',
            'coupon_center',
            '1.2.3',
            'manifest.json',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputPath,
            'artifacts',
            'coupon_center',
            '1.2.3',
            'screens',
            'coupon_center_home.json',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputPath,
            'artifacts',
            'coupon_center',
            '1.2.3',
            'assets',
            'icon.png',
          ),
        ).existsSync(),
        isTrue,
      );

      final catalog =
          jsonDecode(
                await File(
                  p.join(
                    outputPath,
                    'artifacts',
                    'coupon_center',
                    'catalog.json',
                  ),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(catalog['artifactLayoutVersion'], 1);
      expect(catalog['latestVersion'], '1.2.3');
      expect(
        await File(
          p.join(outputPath, 'PUBLISH_INSTRUCTIONS.md'),
        ).readAsString(),
        contains('portable artifact bundle'),
      );
      expect(await File(p.join(outputPath, '.nojekyll')).exists(), isTrue);
    });

    test('publishes Mp build output with engine-neutral layout', () async {
      final scaffold = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'mp_coupon_center',
        ),
      );
      final outputPath = p.join(tempDir.path, 'mp_public_mini_program');

      final result = await const MiniProgramStaticPublisher().publish(
        MiniProgramStaticPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: scaffold.miniProgramRootPath,
          miniProgramId: 'mp_coupon_center',
          outputPath: outputPath,
          clean: true,
        ),
      );

      expect(result.buildResult.screenFormat, 'mp');
      expect(result.buildResult.screenSchemaVersion, 1);
      expect(result.buildResult.screensDirectoryPath, contains('mp\\.build'));
      expect(result.screensDirectoryPath, isNot(contains('mp\\.build')));
      expect(
        File(
          p.join(
            outputPath,
            'artifacts',
            'mp_coupon_center',
            '1.0.0',
            'screens',
            'mp_coupon_center_home.json',
          ),
        ).existsSync(),
        isTrue,
      );

      final release =
          jsonDecode(await File(result.metadataReleasePath).readAsString())
              as Map<String, dynamic>;
      final catalog =
          jsonDecode(await File(result.metadataCatalogPath).readAsString())
              as Map<String, dynamic>;
      expect(release['artifactLayoutVersion'], 1);
      expect(release['screensPath'], 'screens/');
      expect(catalog['artifactLayoutVersion'], 1);
      expect(catalog['latestVersion'], '1.0.0');
    });

    test('clean is app-scoped and preserves unrelated artifacts', () async {
      final outputPath = p.join(tempDir.path, 'public_mini_program');
      await Directory(
        p.join(outputPath, 'artifacts', 'old_app'),
      ).create(recursive: true);
      await File(
        p.join(outputPath, 'artifacts', 'old_app', 'old.json'),
      ).writeAsString('{}');
      await File(p.join(outputPath, 'README.md')).writeAsString('keep me');

      final publisher = MiniProgramStaticPublisher(
        builder: _FakeMiniProgramBuilder(
          MiniProgramBuildResult(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
            miniProgramRootPath: miniProgramRoot.path,
            cliSource: 'fake',
            invocation: const <String>['dart', 'fake'],
            outputDirectoryPath: p.join(miniProgramRoot.path, 'mp', '.build'),
            screensDirectoryPath: screensDirectoryPath,
            entryScreenJsonPath: p.join(
              screensDirectoryPath,
              'coupon_center_home.json',
            ),
            pubGetRan: false,
          ),
        ),
      );

      final result = await publisher.publish(
        MiniProgramStaticPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: miniProgramRoot.path,
          miniProgramId: 'coupon_center',
          outputPath: outputPath,
          clean: true,
        ),
      );

      expect(result.cleaned, isTrue);
      expect(
        await File(
          p.join(outputPath, 'artifacts', 'old_app', 'old.json'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(p.join(outputPath, 'README.md')).readAsString(),
        'keep me',
      );
      expect(
        await File(
          p.join(
            outputPath,
            'artifacts',
            'coupon_center',
            '1.2.3',
            'screens',
            'coupon_center_home.json',
          ),
        ).exists(),
        isTrue,
      );
    });
  });
}

class _FakeMiniProgramBuilder extends MiniProgramBuilder {
  const _FakeMiniProgramBuilder(this.result);

  final MiniProgramBuildResult result;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async {
    return result;
  }
}
