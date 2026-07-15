import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramHostController policy import', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_host_controller_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates host policies JSON, resolver, and endpoint policy wiring', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeHostProject(hostRoot);
      final handoffPath = p.join(tempDir.path, 'calculator.partner.json');

      final result = await MiniProgramHostController().addEndpoint(
        MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'calculator',
          title: 'Calculator',
          apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
          policySourcePath: handoffPath,
          requestedCache: const <String, Object?>{
            'state': <String, Object?>{
              'enabled': true,
              'reason': 'calculator history',
              'recommendedMaxBytes': 1048576,
              'recommendedTtlDays': 30,
            },
          },
          requestedPublisherApi: const <String, Object?>{
            'enabled': true,
            'reason': 'Load calculator exchange rates.',
            'contract': 'publisher_backend.json',
          },
        ),
      );

      final policies =
          jsonDecode(await File(result.policyFilePath).readAsString())
              as Map<String, dynamic>;
      expect(policies, <String, dynamic>{
        'schemaVersion': 1,
        'apps': <String, dynamic>{
          'calculator': <String, dynamic>{
            'requested': <String, dynamic>{
              'source': 'calculator.partner.json',
              'cache': <String, dynamic>{
                'state': <String, dynamic>{
                  'enabled': true,
                  'reason': 'calculator history',
                  'recommendedMaxBytes': 1048576,
                  'recommendedTtlDays': 30,
                },
              },
              'publisherApi': <String, dynamic>{
                'enabled': true,
                'reason': 'Load calculator exchange rates.',
                'contract': 'publisher_backend.json',
              },
              'permissions': <String, dynamic>{},
            },
            'accepted': <String, dynamic>{
              'cache': <String, dynamic>{
                'state': <String, dynamic>{
                  'enabled': true,
                  'maxBytes': 1048576,
                  'ttlDays': 30,
                },
              },
              'liveState': <String, dynamic>{
                'maxBytes': 2097152,
                'maxEntries': 1000,
                'maxValueBytes': 262144,
                'maxDepth': 32,
              },
              'publisherApi': <String, dynamic>{'enabled': false},
              'permissions': <String, dynamic>{},
            },
          },
        },
      });

      final endpoints = await File(result.filePath).readAsString();
      expect(
        endpoints,
        contains("import 'mini_program_policy_resolver.dart';"),
      );
      expect(
        endpoints,
        contains(
          'cachePolicy: cachePolicyForMiniProgram(MiniPrograms.calculator.appId)',
        ),
      );
      expect(
        endpoints,
        contains(
          'liveStatePolicy: liveStatePolicyForMiniProgram(MiniPrograms.calculator.appId)',
        ),
      );
      expect(
        endpoints,
        contains(
          'publisherApiPolicy: publisherApiPolicyForMiniProgram(MiniPrograms.calculator.appId)',
        ),
      );

      final resolver = await File(result.policyResolverFilePath).readAsString();
      expect(resolver, contains('case "calculator":'));
      expect(resolver, contains('maxStateBytes: 1048576'));
      expect(resolver, contains('stateInactiveTtl: Duration(days: 30)'));
      expect(
        resolver,
        contains('MiniProgramLiveStatePolicy liveStatePolicyForMiniProgram'),
      );
      expect(resolver, contains('maxBytes: 2097152'));
      expect(resolver, contains('maxEntries: 1000'));
      expect(
        resolver,
        contains(
          'MiniProgramPublisherApiPolicy publisherApiPolicyForMiniProgram',
        ),
      );
      expect(resolver, contains('enabled: false'));
      expect(
        resolver,
        contains(
          'allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{MiniProgramCacheBucket.state}',
        ),
      );
    });

    test('preserves accepted policy on re-import and accepts explicitly', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeHostProject(hostRoot);
      final controller = MiniProgramHostController();
      final handoffPath = p.join(tempDir.path, 'calculator.partner.json');

      final initial = await controller.addEndpoint(
        MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'calculator',
          apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
          policySourcePath: handoffPath,
          requestedCache: const <String, Object?>{
            'state': <String, Object?>{
              'enabled': true,
              'reason': 'calculator history',
              'recommendedMaxBytes': 1048576,
              'recommendedTtlDays': 30,
            },
          },
          requestedPublisherApi: const <String, Object?>{
            'enabled': true,
            'reason': 'Load rates.',
            'contract': 'publisher_backend.json',
          },
        ),
      );
      await File(initial.policyFilePath).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'schemaVersion': 1,
          'apps': <String, Object?>{
            'calculator': <String, Object?>{
              'requested': <String, Object?>{'source': 'calculator.partner.json', 'cache': <String, Object?>{}, 'permissions': <String, Object?>{}},
              'accepted': <String, Object?>{
                'cache': <String, Object?>{
                  'state': <String, Object?>{'enabled': true, 'maxBytes': 524288, 'ttlDays': 7},
                },
                'liveState': <String, Object?>{'maxBytes': 3145728, 'maxEntries': 1500, 'maxValueBytes': 524288, 'maxDepth': 24},
                'publisherApi': <String, Object?>{'enabled': false, 'reviewedBy': 'host-security'},
                'futurePolicy': <String, Object?>{'enabled': true},
                'permissions': <String, Object?>{},
              },
            },
          },
        })}\n',
      );

      await controller.addEndpoint(
        MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'calculator',
          apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
          policySourcePath: handoffPath,
          requestedCache: const <String, Object?>{
            'state': <String, Object?>{
              'enabled': true,
              'reason': 'larger calculator history',
              'recommendedMaxBytes': 2097152,
              'recommendedTtlDays': 60,
            },
          },
          requestedPublisherApi: const <String, Object?>{
            'enabled': true,
            'reason': 'Load rates.',
            'contract': 'publisher_backend.json',
          },
        ),
      );

      var policies =
          jsonDecode(await File(initial.policyFilePath).readAsString())
              as Map<String, dynamic>;
      var app =
          (policies['apps'] as Map<String, dynamic>)['calculator']
              as Map<String, dynamic>;
      expect(
        ((app['requested'] as Map<String, dynamic>)['cache']
            as Map<String, dynamic>)['state'],
        containsPair('recommendedMaxBytes', 2097152),
      );
      expect(
        ((app['accepted'] as Map<String, dynamic>)['cache']
            as Map<String, dynamic>)['state'],
        <String, dynamic>{'enabled': true, 'maxBytes': 524288, 'ttlDays': 7},
      );
      expect(
        (app['accepted'] as Map<String, dynamic>)['liveState'],
        <String, dynamic>{
          'maxBytes': 3145728,
          'maxEntries': 1500,
          'maxValueBytes': 524288,
          'maxDepth': 24,
        },
      );
      expect(
        (app['accepted'] as Map<String, dynamic>)['futurePolicy'],
        <String, dynamic>{'enabled': true},
      );
      expect(
        (app['accepted'] as Map<String, dynamic>)['publisherApi'],
        <String, dynamic>{'enabled': false, 'reviewedBy': 'host-security'},
      );

      await controller.addEndpoint(
        MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'calculator',
          apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
          policySourcePath: handoffPath,
          acceptRequestedPolicy: true,
          requestedCache: const <String, Object?>{
            'state': <String, Object?>{
              'enabled': true,
              'reason': 'larger calculator history',
              'recommendedMaxBytes': 2097152,
              'recommendedTtlDays': 60,
            },
          },
          requestedPublisherApi: const <String, Object?>{
            'enabled': true,
            'reason': 'Load rates.',
            'contract': 'publisher_backend.json',
          },
        ),
      );

      policies =
          jsonDecode(await File(initial.policyFilePath).readAsString())
              as Map<String, dynamic>;
      app =
          (policies['apps'] as Map<String, dynamic>)['calculator']
              as Map<String, dynamic>;
      expect(
        ((app['accepted'] as Map<String, dynamic>)['cache']
            as Map<String, dynamic>)['state'],
        <String, dynamic>{'enabled': true, 'maxBytes': 2097152, 'ttlDays': 60},
      );
      expect(
        (app['accepted'] as Map<String, dynamic>)['liveState'],
        containsPair('maxBytes', 3145728),
      );
      expect(
        (app['accepted'] as Map<String, dynamic>)['publisherApi'],
        <String, dynamic>{'enabled': true, 'reviewedBy': 'host-security'},
      );
    });

    test(
      'location permission defaults denied, preserves host edits, and accepts explicitly',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeHostProject(hostRoot);
        final controller = MiniProgramHostController();
        final request = MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'weather',
          title: 'Weather',
          apiBaseUri: Uri.parse('https://cdn.example.com/weather/'),
          policySourcePath: p.join(tempDir.path, 'weather.partner.json'),
          requestedPermissions: const <String, Object?>{
            'location': <String, Object?>{
              'enabled': true,
              'reason': 'Use approximate location for local weather.',
              'accuracy': 'approximate',
              'mode': 'whenInUse',
            },
          },
        );

        final initial = await controller.addEndpoint(request);
        var policies =
            jsonDecode(await File(initial.policyFilePath).readAsString())
                as Map<String, dynamic>;
        var weather =
            (policies['apps'] as Map<String, dynamic>)['weather']
                as Map<String, dynamic>;
        expect(
          ((weather['requested'] as Map<String, dynamic>)['permissions']
              as Map<String, dynamic>)['location'],
          containsPair('reason', 'Use approximate location for local weather.'),
        );
        expect(
          ((weather['accepted'] as Map<String, dynamic>)['permissions']
              as Map<String, dynamic>)['location'],
          <String, dynamic>{
            'accuracy': 'approximate',
            'enabled': false,
            'mode': 'whenInUse',
          },
        );

        final accepted = weather['accepted'] as Map<String, dynamic>;
        accepted['permissions'] = <String, dynamic>{
          'cameraFuture': <String, dynamic>{'enabled': false},
          'location': <String, dynamic>{
            'accuracy': 'approximate',
            'enabled': false,
            'mode': 'whenInUse',
            'reviewedBy': 'host-security',
          },
        };
        await File(initial.policyFilePath).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(policies)}\n',
        );

        await controller.addEndpoint(request);
        policies =
            jsonDecode(await File(initial.policyFilePath).readAsString())
                as Map<String, dynamic>;
        weather =
            (policies['apps'] as Map<String, dynamic>)['weather']
                as Map<String, dynamic>;
        var acceptedPermissions =
            (weather['accepted'] as Map<String, dynamic>)['permissions']
                as Map<String, dynamic>;
        expect(
          acceptedPermissions['location'],
          containsPair('reviewedBy', 'host-security'),
        );
        expect(acceptedPermissions, contains('cameraFuture'));

        await controller.addEndpoint(
          MiniProgramHostEndpointAddRequest(
            projectRootPath: request.projectRootPath,
            appId: request.appId,
            title: request.title,
            apiBaseUri: request.apiBaseUri,
            policySourcePath: request.policySourcePath,
            requestedPermissions: request.requestedPermissions,
            acceptRequestedPolicy: true,
          ),
        );
        policies =
            jsonDecode(await File(initial.policyFilePath).readAsString())
                as Map<String, dynamic>;
        weather =
            (policies['apps'] as Map<String, dynamic>)['weather']
                as Map<String, dynamic>;
        acceptedPermissions =
            (weather['accepted'] as Map<String, dynamic>)['permissions']
                as Map<String, dynamic>;
        expect(acceptedPermissions['location'], containsPair('enabled', true));
        expect(acceptedPermissions, contains('cameraFuture'));

        final endpoints = await File(initial.filePath).readAsString();
        expect(
          endpoints,
          contains('locationPolicy: locationPolicyForMiniProgram('),
        );
        final resolver = await File(
          initial.policyResolverFilePath,
        ).readAsString();
        expect(
          resolver,
          contains('MiniProgramLocationPolicy locationPolicyForMiniProgram'),
        );
        expect(resolver, contains('enabled: true'));
      },
    );

    test('force resets requested location permission to denied', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeHostProject(hostRoot);
      final result = await MiniProgramHostController().addEndpoint(
        MiniProgramHostEndpointAddRequest(
          projectRootPath: hostRoot,
          appId: 'weather',
          apiBaseUri: Uri.parse('https://cdn.example.com/weather/'),
          force: true,
          acceptRequestedPolicy: true,
          requestedPermissions: const <String, Object?>{
            'location': <String, Object?>{
              'enabled': true,
              'reason': 'Local weather',
              'accuracy': 'approximate',
              'mode': 'whenInUse',
            },
          },
        ),
      );
      final policies =
          jsonDecode(await File(result.policyFilePath).readAsString())
              as Map<String, dynamic>;
      final weather =
          (policies['apps'] as Map<String, dynamic>)['weather']
              as Map<String, dynamic>;
      final location =
          (((weather['accepted'] as Map<String, dynamic>)['permissions']
                  as Map<String, dynamic>)['location'])
              as Map<String, dynamic>;
      expect(location['enabled'], isFalse);
    });

    test(
      'force regenerates accepted policy from current requested policy',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeHostProject(hostRoot);
        final controller = MiniProgramHostController();
        final handoffPath = p.join(tempDir.path, 'calculator.partner.json');

        final initial = await controller.addEndpoint(
          MiniProgramHostEndpointAddRequest(
            projectRootPath: hostRoot,
            appId: 'calculator',
            apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
            policySourcePath: handoffPath,
            requestedCache: const <String, Object?>{
              'state': <String, Object?>{
                'recommendedMaxBytes': 1048576,
                'recommendedTtlDays': 30,
              },
            },
          ),
        );
        await File(initial.policyFilePath).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
            'schemaVersion': 1,
            'apps': <String, Object?>{
              'calculator': <String, Object?>{
                'requested': <String, Object?>{'source': 'calculator.partner.json', 'cache': <String, Object?>{}, 'permissions': <String, Object?>{}},
                'accepted': <String, Object?>{
                  'cache': <String, Object?>{
                    'state': <String, Object?>{'enabled': true, 'maxBytes': 524288, 'ttlDays': 7},
                  },
                  'permissions': <String, Object?>{},
                },
              },
            },
          })}\n',
        );

        await controller.addEndpoint(
          MiniProgramHostEndpointAddRequest(
            projectRootPath: hostRoot,
            appId: 'calculator',
            apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
            policySourcePath: handoffPath,
            force: true,
            requestedCache: const <String, Object?>{
              'state': <String, Object?>{
                'recommendedMaxBytes': 1048576,
                'recommendedTtlDays': 30,
              },
            },
          ),
        );

        final policies =
            jsonDecode(await File(initial.policyFilePath).readAsString())
                as Map<String, dynamic>;
        final app =
            (policies['apps'] as Map<String, dynamic>)['calculator']
                as Map<String, dynamic>;
        expect(
          ((app['accepted'] as Map<String, dynamic>)['cache']
              as Map<String, dynamic>)['state'],
          <String, dynamic>{
            'enabled': true,
            'maxBytes': 1048576,
            'ttlDays': 30,
          },
        );
        expect(
          (app['accepted'] as Map<String, dynamic>)['liveState'],
          <String, dynamic>{
            'maxBytes': 2097152,
            'maxEntries': 1000,
            'maxValueBytes': 262144,
            'maxDepth': 32,
          },
        );
      },
    );
  });
}

Future<void> _writeHostProject(String hostRoot) async {
  await Directory(p.join(hostRoot, 'lib')).create(recursive: true);
  await File(p.join(hostRoot, 'pubspec.yaml')).writeAsString('''
name: host_app
version: 1.0.0+1
''');
}
