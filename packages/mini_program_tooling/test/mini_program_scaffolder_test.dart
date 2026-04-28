import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramScaffolder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_scaffold_',
      );
      await Directory(
        p.join(tempDir.path, 'mini_programs'),
      ).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'creates a buildable starter scaffold with default capabilities',
      () async {
        final result = await const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
          ),
        );

        final miniProgramRoot = p.join(
          tempDir.path,
          'mini_programs',
          'coupon_center',
        );
        final manifest =
            jsonDecode(
                  await File(
                    p.join(miniProgramRoot, 'manifest.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final screenFile = File(
          p.join(miniProgramRoot, 'stac', 'screens', 'coupon_center_home.dart'),
        );
        final detailsScreenFile = File(
          p.join(
            miniProgramRoot,
            'stac',
            'screens',
            'coupon_center_details.dart',
          ),
        );
        final routeDemoScreenFile = File(
          p.join(
            miniProgramRoot,
            'stac',
            'screens',
            'coupon_center_route_demo.dart',
          ),
        );
        final helperFile = File(
          p.join(miniProgramRoot, 'lib', 'host_action_helpers.dart'),
        );
        final readmeFile = File(p.join(miniProgramRoot, 'README.md'));

        expect(result.miniProgramId, 'coupon_center');
        expect(manifest['entry'], 'coupon_center_home');
        expect(manifest['requiredCapabilities'], <String>['analytics']);
        expect(
          (manifest['cachePolicy'] as Map<String, dynamic>)['manifest']
              as Map<String, dynamic>,
          containsPair('mode', 'staleWhileError'),
        );

        final screenSource = await screenFile.readAsString();
        final detailsScreenSource = await detailsScreenFile.readAsString();
        final helperSource = await helperFile.readAsString();
        final readmeSource = await readmeFile.readAsString();
        expect(
          screenSource,
          contains("@StacScreen(screenName: 'coupon_center_home')"),
        );
        expect(
          screenSource,
          contains(
            "import 'package:coupon_center_mini_program/host_action_helpers.dart';",
          ),
        );
        expect(screenSource, contains('openMiniProgramScreenAction('));
        expect(screenSource, contains('Coupon Center profile starter'));
        expect(screenSource, contains('Preview User'));
        expect(screenSource, contains('What to customize next'));
        expect(screenSource, contains('Open profile details'));
        expect(
          screenSource,
          contains(
            '// Advanced portable route examples stay commented by default:',
          ),
        );
        expect(
          screenSource,
          contains('//   onPressed: replaceMiniProgramScreenAction('),
        );
        expect(
          screenSource,
          contains('//   onPressed: resetMiniProgramStackAction('),
        );
        expect(screenSource, contains('hostTrackEventAction('));
        expect(
          screenSource,
          contains('Track profile opened event (logs only)'),
        );
        expect(screenSource, contains('body: StacSingleChildScrollView('));
        expect(screenSource, isNot(contains('body: StacSafeArea(')));
        expect(
          screenSource,
          contains('padding: StacEdgeInsets.symmetric(horizontal: 24)'),
        );
        expect(
          screenSource,
          isNot(contains('padding: StacEdgeInsets.all(24)')),
        );
        expect(screenSource, isNot(contains('hostOpenNativeScreenAction(')));
        expect(screenSource, isNot(contains('jsonData:')));
        expect(screenSource, isNot(contains('hostCallSecureApiAction(')));
        expect(
          detailsScreenSource,
          contains("@StacScreen(screenName: 'coupon_center_details')"),
        );
        expect(await routeDemoScreenFile.exists(), isFalse);
        expect(
          detailsScreenSource,
          contains('body: StacSingleChildScrollView('),
        );
        expect(detailsScreenSource, isNot(contains('body: StacSafeArea(')));
        expect(
          detailsScreenSource,
          contains('padding: StacEdgeInsets.symmetric(horizontal: 24)'),
        );
        expect(
          detailsScreenSource,
          isNot(contains('padding: StacEdgeInsets.all(24)')),
        );
        expect(detailsScreenSource, contains('popMiniProgramScreenAction('));
        expect(detailsScreenSource, contains('Coupon Center details'));
        expect(detailsScreenSource, contains('Account snapshot'));
        expect(detailsScreenSource, contains('Preferences starter block'));
        expect(detailsScreenSource, contains('Back to profile home'));
        expect(
          detailsScreenSource,
          isNot(contains('Capability enabled: native_navigation')),
        );
        expect(
          detailsScreenSource,
          contains(
            '// More stack-aware helpers live in host_action_helpers.dart:',
          ),
        );
        expect(detailsScreenSource, contains('// popToMiniProgramRootAction('));
        expect(
          detailsScreenSource,
          contains('// popToMiniProgramScreenAction('),
        );
        expect(
          detailsScreenSource,
          isNot(contains('onPressed: hostOpenNativeScreenAction(')),
        );
        expect(detailsScreenSource, isNot(contains('Open route demo screen')));
        expect(helperSource, contains('StacAction hostTrackEventAction('));
        expect(helperSource, contains("'action': 'trackEvent'"));
        expect(
          helperSource,
          contains('StacAction openMiniProgramScreenAction('),
        );
        expect(helperSource, contains("'action': 'openMiniProgramScreen'"));
        expect(
          helperSource,
          contains('StacAction resetMiniProgramStackAction('),
        );
        expect(helperSource, contains("'action': 'resetMiniProgramStack'"));
        expect(
          helperSource,
          contains('StacAction replaceMiniProgramScreenAction('),
        );
        expect(helperSource, contains("'action': 'replaceMiniProgramScreen'"));
        expect(
          helperSource,
          contains('StacAction popMiniProgramScreenAction('),
        );
        expect(helperSource, contains("'action': 'popMiniProgramScreen'"));
        expect(
          helperSource,
          contains('StacAction popToMiniProgramRootAction('),
        );
        expect(helperSource, contains("'action': 'popToMiniProgramRoot'"));
        expect(
          helperSource,
          contains('StacAction popToMiniProgramScreenAction('),
        );
        expect(helperSource, contains("'action': 'popToMiniProgramScreen'"));
        expect(
          helperSource,
          contains('StacAction hostOpenNativeScreenAction('),
        );
        expect(helperSource, contains("'action': 'openNativeScreen'"));
        expect(helperSource, contains("'route': route"));
        expect(helperSource, contains('StacAction hostCallSecureApiAction('));
        expect(helperSource, contains("'action': 'callSecureApi'"));
        expect(
          readmeSource,
          contains('stac/screens/coupon_center_details.dart'),
        );
        expect(
          readmeSource,
          isNot(contains('stac/screens/coupon_center_route_demo.dart')),
        );
        expect(readmeSource, contains('## Portable route helpers'));
        expect(readmeSource, contains('replaceMiniProgramScreenAction(...)'));
        expect(
          readmeSource,
          isNot(contains('does not call any host-owned route by default')),
        );

        expect(
          await File(p.join(miniProgramRoot, 'pubspec.yaml')).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(miniProgramRoot, 'lib', 'default_stac_options.dart'),
          ).exists(),
          isTrue,
        );
        expect(await helperFile.exists(), isTrue);
        expect(result.createdPaths, isNotEmpty);
      },
    );

    test('adds native navigation only when requested', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'native_flow',
          capabilities: const <String>{'analytics', 'native_navigation'},
        ),
      );

      final manifest =
          jsonDecode(
                await File(
                  p.join(result.miniProgramRootPath, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final detailsScreenSource = await File(
        p.join(
          result.miniProgramRootPath,
          'stac',
          'screens',
          'native_flow_details.dart',
        ),
      ).readAsString();
      final readmeSource = await File(
        p.join(result.miniProgramRootPath, 'README.md'),
      ).readAsString();

      expect(manifest['requiredCapabilities'], <String>[
        'analytics',
        'native_navigation',
      ]);
      expect(
        detailsScreenSource,
        contains('Capability enabled: native_navigation'),
      );
      expect(
        readmeSource,
        contains('does not call any host-owned route by default'),
      );
    });

    test(
      'uses noCache and secure API starter action when secure_api is requested',
      () async {
        final result = await const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'claim_center',
            capabilities: const <String>{'analytics', 'secure_api'},
          ),
        );

        final manifest =
            jsonDecode(
                  await File(
                    p.join(result.miniProgramRootPath, 'manifest.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final screenSource = await File(
          p.join(
            result.miniProgramRootPath,
            'stac',
            'screens',
            'claim_center_home.dart',
          ),
        ).readAsString();
        final detailsScreenSource = await File(
          p.join(
            result.miniProgramRootPath,
            'stac',
            'screens',
            'claim_center_details.dart',
          ),
        ).readAsString();
        final routeDemoScreenFile = File(
          p.join(
            result.miniProgramRootPath,
            'stac',
            'screens',
            'claim_center_route_demo.dart',
          ),
        );
        final helperSource = await File(
          p.join(result.miniProgramRootPath, 'lib', 'host_action_helpers.dart'),
        ).readAsString();
        final readmeSource = await File(
          p.join(result.miniProgramRootPath, 'README.md'),
        ).readAsString();

        expect(manifest['requiredCapabilities'], <String>[
          'analytics',
          'secure_api',
        ]);
        expect(
          (manifest['cachePolicy'] as Map<String, dynamic>)['manifest']
              as Map<String, dynamic>,
          containsPair('mode', 'noCache'),
        );
        expect(screenSource, contains('openMiniProgramScreenAction('));
        expect(screenSource, contains('Open profile details'));
        expect(screenSource, isNot(contains('hostOpenNativeScreenAction(')));
        expect(screenSource, isNot(contains('hostCallSecureApiAction(')));
        expect(detailsScreenSource, contains('Capability enabled: secure_api'));
        expect(
          detailsScreenSource,
          isNot(contains('onPressed: hostCallSecureApiAction(')),
        );
        expect(detailsScreenSource, contains('// popToMiniProgramRootAction('));
        expect(await routeDemoScreenFile.exists(), isFalse);
        expect(helperSource, contains("'action': 'callSecureApi'"));
        expect(
          readmeSource,
          contains('does not call a backend endpoint by default'),
        );
      },
    );

    test(
      'supports standalone output root outside repo mini_programs',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'standalone_coupon_center');

        final result = await const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            miniProgramId: 'coupon_center',
            outputRootPath: standaloneRoot,
          ),
        );

        expect(result.repoRootPath, isNull);
        expect(result.miniProgramRootPath, standaloneRoot);
        expect(
          await File(p.join(standaloneRoot, 'manifest.json')).exists(),
          isTrue,
        );

        final readme = await File(
          p.join(standaloneRoot, 'README.md'),
        ).readAsString();
        expect(readme, contains('miniprogram doctor'));
        expect(readme, contains('miniprogram build coupon_center'));
      },
    );

    test('fails on unknown capability values', () async {
      expect(
        () => const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'broken_program',
            capabilities: <String>{'analytics', 'camera'},
          ),
        ),
        throwsA(isA<MiniProgramScaffoldException>()),
      );
    });

    test('fails when target exists and force is false', () async {
      final targetDir = Directory(
        p.join(tempDir.path, 'mini_programs', 'coupon_center'),
      );
      await targetDir.create(recursive: true);
      await File(p.join(targetDir.path, 'manifest.json')).writeAsString('{}');

      expect(
        () => const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
          ),
        ),
        throwsA(isA<MiniProgramScaffoldException>()),
      );
    });

    test('overwrites scaffold-managed files when force is true', () async {
      final targetDir = Directory(
        p.join(tempDir.path, 'mini_programs', 'coupon_center'),
      );
      await targetDir.create(recursive: true);
      await File(p.join(targetDir.path, 'manifest.json')).writeAsString('{}');

      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'coupon_center',
          force: true,
        ),
      );

      final manifestSource = await File(
        p.join(targetDir.path, 'manifest.json'),
      ).readAsString();

      expect(result.miniProgramId, 'coupon_center');
      expect(manifestSource, contains('"id": "coupon_center"'));
    });
  });
}
