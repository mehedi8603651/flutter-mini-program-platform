import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late String hostRootPath;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mini_program_host_capability_',
    );
    hostRootPath = p.join(tempDirectory.path, 'host_app');
    await _writeHostFixture(hostRootPath);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('installs generic Android one-time location support', () async {
    final result = await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'location',
        platform: 'android',
      ),
    );

    expect(result.alreadyInstalled, isFalse);
    expect(result.createdPaths, hasLength(2));
    expect(result.updatedPaths, hasLength(3));

    final providerSource = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'app_android_location_provider.dart',
      ),
    ).readAsString();
    expect(providerSource, contains('class AppAndroidLocationProvider'));
    expect(providerSource, contains("'mini_program/location'"));

    final hostSetupSource = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    ).readAsString();
    expect(hostSetupSource, contains("package:flutter/foundation.dart"));
    expect(hostSetupSource, contains('AppAndroidLocationProvider'));
    expect(hostSetupSource, contains('resolvedLocationProvider'));
    expect(hostSetupSource, contains('TargetPlatform.android'));
    expect(
      hostSetupSource,
      contains('locationProvider: resolvedLocationProvider'),
    );

    final manifestSource = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).readAsString();
    expect(
      manifestSource,
      contains('android.permission.ACCESS_COARSE_LOCATION'),
    );
    expect(manifestSource, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(manifestSource, isNot(contains('ACCESS_BACKGROUND_LOCATION')));

    final mainActivitySource = await _mainActivityFile(
      hostRootPath,
    ).readAsString();
    expect(mainActivitySource, contains('configureFlutterEngine'));
    expect(
      mainActivitySource,
      contains('MiniProgramLocationChannel.register(flutterEngine)'),
    );

    final nativeSource = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        'com',
        'example',
        'host_app',
        'MiniProgramLocationChannel.kt',
      ),
    ).readAsString();
    expect(nativeSource, contains('class MiniProgramLocationChannel'));
    expect(nativeSource, contains('LocationManager.NETWORK_PROVIDER'));
    expect(nativeSource, contains('location_permission_denied_permanently'));
    expect(nativeSource, contains('location_timeout'));
    expect(nativeSource, isNot(contains('LocationManager.GPS_PROVIDER')));
    expect(nativeSource, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(nativeSource, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });

  test('is idempotent after a successful installation', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final request = MiniProgramHostCapabilityInitRequest(
      projectRootPath: hostRootPath,
      capability: 'location',
      platform: 'android',
    );
    await installer.initialize(request);
    final firstContents = await _readInstalledFiles(hostRootPath);

    final secondResult = await installer.initialize(request);
    final secondContents = await _readInstalledFiles(hostRootPath);

    expect(secondResult.alreadyInstalled, isTrue);
    expect(secondResult.createdPaths, isEmpty);
    expect(secondResult.updatedPaths, isEmpty);
    expect(secondContents, firstContents);
  });

  test('preserves existing MainActivity and host setup behavior', () async {
    final mainActivity = _mainActivityFile(hostRootPath);
    await mainActivity.writeAsString('''
package com.example.host_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerExistingHostChannel(flutterEngine)
    }

    private fun registerExistingHostChannel(flutterEngine: FlutterEngine) = Unit
}
''');
    final setupFile = File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    );
    await setupFile.writeAsString(
      '${await setupFile.readAsString()}\nvoid keepHostHook() {}\n',
    );

    await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'location',
        platform: 'android',
      ),
    );

    final mainSource = await mainActivity.readAsString();
    expect(mainSource, contains('registerExistingHostChannel(flutterEngine)'));
    expect(
      mainSource,
      contains('MiniProgramLocationChannel.register(flutterEngine)'),
    );
    expect(await setupFile.readAsString(), contains('void keepHostHook() {}'));
  });

  test('recognizes an existing direct MethodChannel integration', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final request = MiniProgramHostCapabilityInitRequest(
      projectRootPath: hostRootPath,
      capability: 'location',
      platform: 'android',
    );
    await installer.initialize(request);
    final nativeFile = File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
        'com',
        'example',
        'host_app',
        'MiniProgramLocationChannel.kt',
      ),
    );
    await nativeFile.delete();
    final mainActivity = _mainActivityFile(hostRootPath);
    await mainActivity.writeAsString('''
package com.example.host_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val channelName = "mini_program/location"
}
''');

    final result = await installer.initialize(request);

    expect(result.alreadyInstalled, isTrue);
    expect(await nativeFile.exists(), isFalse);
  });

  test('rejects unsupported capability or platform', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    await expectLater(
      installer.initialize(
        MiniProgramHostCapabilityInitRequest(
          projectRootPath: hostRootPath,
          capability: 'camera',
          platform: 'android',
        ),
      ),
      throwsA(
        isA<MiniProgramHostCapabilityException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported host capability'),
        ),
      ),
    );
    await expectLater(
      installer.initialize(
        MiniProgramHostCapabilityInitRequest(
          projectRootPath: hostRootPath,
          capability: 'location',
          platform: 'ios',
        ),
      ),
      throwsA(
        isA<MiniProgramHostCapabilityException>().having(
          (error) => error.message,
          'message',
          contains('only --platform android'),
        ),
      ),
    );
  });

  test('does not overwrite a conflicting host-owned provider file', () async {
    final providerFile = File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'app_android_location_provider.dart',
      ),
    );
    await providerFile.writeAsString('void customProvider() {}\n');

    await expectLater(
      const MiniProgramHostCapabilityInstaller().initialize(
        MiniProgramHostCapabilityInitRequest(
          projectRootPath: hostRootPath,
          capability: 'location',
          platform: 'android',
        ),
      ),
      throwsA(
        isA<MiniProgramHostCapabilityException>().having(
          (error) => error.message,
          'message',
          contains('Refusing to overwrite'),
        ),
      ),
    );
    expect(await providerFile.readAsString(), 'void customProvider() {}\n');
  });
}

Future<void> _writeHostFixture(String rootPath) async {
  await Directory(
    p.join(rootPath, 'lib', 'mini_program'),
  ).create(recursive: true);
  final kotlinPath = p.join(
    rootPath,
    'android',
    'app',
    'src',
    'main',
    'kotlin',
    'com',
    'example',
    'host_app',
  );
  await Directory(kotlinPath).create(recursive: true);

  await File(p.join(rootPath, 'pubspec.yaml')).writeAsString('''
name: host_app
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.10.0

dependencies:
  flutter:
    sdk: flutter
  mini_program_sdk: ^0.5.13
  mini_program_contracts: ^0.3.7
''');
  await File(
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_runtime_setup.dart'),
  ).writeAsString('// Generated runtime setup.\n');
  await File(
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_host_setup.dart'),
  ).writeAsString('''
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'app_host_bridge.dart';
import 'mini_program_endpoints.dart';
import 'mini_program_runtime_setup.dart';

Future<MiniProgramConfig> buildHostMiniProgramConfig({
  AppNativeRouteOpener? openNativeRoute,
  MiniProgramLocationProvider? locationProvider,
  Map<String, MiniProgramEndpoint>? endpoints,
  MiniProgramCacheBundle? cacheBundle,
}) async {
  return buildMiniProgramConfig(
    openNativeRoute: openNativeRoute,
    locationProvider: locationProvider,
    endpoints: endpoints ?? buildMiniProgramEndpoints(),
    cacheBundle: cacheBundle,
  );
}
''');
  await File(p.join(kotlinPath, 'MainActivity.kt')).writeAsString('''
package com.example.host_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''');
  final manifestFile = File(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:label="host_app">
        <activity android:name=".MainActivity"/>
    </application>
</manifest>
''');
}

File _mainActivityFile(String rootPath) => File(
  p.join(
    rootPath,
    'android',
    'app',
    'src',
    'main',
    'kotlin',
    'com',
    'example',
    'host_app',
    'MainActivity.kt',
  ),
);

Future<Map<String, String>> _readInstalledFiles(String rootPath) async {
  final paths = <String>[
    p.join(
      rootPath,
      'lib',
      'mini_program',
      'app_android_location_provider.dart',
    ),
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_host_setup.dart'),
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    _mainActivityFile(rootPath).path,
    p.join(
      rootPath,
      'android',
      'app',
      'src',
      'main',
      'kotlin',
      'com',
      'example',
      'host_app',
      'MiniProgramLocationChannel.kt',
    ),
  ];
  return <String, String>{
    for (final path in paths) path: await File(path).readAsString(),
  };
}
