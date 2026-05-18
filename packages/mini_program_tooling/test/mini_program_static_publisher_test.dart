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
      miniProgramRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await Directory(
        p.join(miniProgramRoot.path, 'assets'),
      ).create(recursive: true);
      await Directory(
        p.join(miniProgramRoot.path, 'stac', '.build', 'screens'),
      ).create(recursive: true);
      screensDirectoryPath = p.join(
        miniProgramRoot.path,
        'stac',
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
      ).writeAsString('{"type":"text","data":"Coupon Center"}');
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
            outputDirectoryPath: p.join(miniProgramRoot.path, 'stac', '.build'),
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
          p.join(outputPath, 'manifests', 'coupon_center', 'latest.json'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputPath,
            'manifests',
            'coupon_center',
            'versions',
            '1.2.3.json',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputPath,
            'screens',
            'coupon_center',
            '1.2.3',
            'coupon_center_home.json',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(outputPath, 'assets', 'coupon_center', '1.2.3', 'icon.png'),
        ).existsSync(),
        isTrue,
      );

      final catalog =
          jsonDecode(
                await File(
                  p.join(
                    outputPath,
                    'metadata',
                    'catalog',
                    'coupon_center.json',
                  ),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(catalog['provider'], 'static');
      expect(catalog['latestVersion'], '1.2.3');
      expect(
        await File(
          p.join(outputPath, 'PUBLISH_INSTRUCTIONS.md'),
        ).readAsString(),
        contains('MiniProgramEndpoint.public'),
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
