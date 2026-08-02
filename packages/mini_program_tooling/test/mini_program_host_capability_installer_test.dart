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

  test('installs Android streaming file transfer support', () async {
    final result = await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'file',
        platform: 'android',
      ),
    );
    expect(result.createdPaths, hasLength(3));
    expect(result.updatedPaths, hasLength(2));

    final provider = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'app_android_file_transfer_provider.dart',
      ),
    ).readAsString();
    expect(provider, contains('class AppAndroidFileTransferProvider'));
    expect(provider, contains("'mini_program/files'"));
    expect(provider, contains('MiniProgramFileUploadRequest'));
    expect(provider, contains("'mediaRefs': request.mediaRefs"));

    final setup = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    ).readAsString();
    expect(setup, contains('resolvedFileTransferProvider'));
    expect(
      setup,
      contains('fileTransferProvider: resolvedFileTransferProvider'),
    );

    final mainActivity = await _mainActivityFile(hostRootPath).readAsString();
    expect(
      mainActivity,
      contains('MiniProgramFileTransferChannel.register(flutterEngine)'),
    );
    final native = await File(
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
        'MiniProgramFileTransferChannel.kt',
      ),
    ).readAsString();
    expect(native, contains('Intent.ACTION_OPEN_DOCUMENT'));
    expect(native, contains('Intent.ACTION_CREATE_DOCUMENT'));
    expect(native, contains('multipart/form-data'));
    expect(native, contains('MediaStore.Downloads'));
    expect(native, contains('acceptedMimeTypes.none'));
    expect(native, contains('formValue(value)'));
    expect(native, contains('context.contentResolver.delete(uri, null, null)'));
    expect(native, contains('MiniProgramHostMediaRegistry.findOwned'));
    expect(native, contains(r'''substringBefore('/')}/'''));
    expect(native, isNot(contains(r'''substringBefore('/')}\/''')));
    expect(native, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(native, isNot(contains('WRITE_EXTERNAL_STORAGE')));

    final second = await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'file',
        platform: 'android',
      ),
    );
    expect(second.alreadyInstalled, isTrue);
  });

  test('installs delegated Android system-camera support', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final request = MiniProgramHostCapabilityInitRequest(
      projectRootPath: hostRootPath,
      capability: 'camera',
      platform: 'android',
    );
    final result = await installer.initialize(request);
    expect(result.createdPaths, hasLength(4));
    expect(result.updatedPaths, hasLength(3));

    final setup = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    ).readAsString();
    expect(setup, contains('AppAndroidCameraProvider'));
    expect(setup, contains('cameraProvider: resolvedCameraProvider'));
    expect(setup, contains('mediaProvider: resolvedMediaProvider'));

    final manifest = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).readAsString();
    expect(manifest, contains('androidx.core.content.FileProvider'));
    expect(manifest, contains(r'${applicationId}.mini_program_camera_files'));
    expect(manifest, isNot(contains('android.permission.CAMERA')));

    final paths = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'res',
        'xml',
        'mini_program_camera_paths.xml',
      ),
    ).readAsString();
    expect(paths, contains('<cache-path'));
    final native = await File(
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
        'MiniProgramCameraChannel.kt',
      ),
    ).readAsString();
    expect(native, contains('ActivityResultContracts.TakePicture'));
    expect(native, contains('ActivityResultContracts.RequestPermission'));
    expect(native, contains('Manifest.permission.CAMERA'));
    expect(native, contains('requestedPermissions'));
    expect(native, contains('camera_permission_denied'));
    expect(native, contains('FileProvider.getUriForFile'));
    expect(native, contains('mediaRef'));
    expect(native, contains('MiniProgramHostMediaRegistry.register'));
    expect(native, contains('"loadPreview"'));
    expect(native, isNot(contains('CameraX')));
    final registry = await File(
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
        'MiniProgramHostMediaRegistry.kt',
      ),
    ).readAsString();
    expect(registry, contains('object MiniProgramHostMediaRegistry'));
    expect(registry, contains('findOwned'));
    final activity = await _mainActivityFile(hostRootPath).readAsString();
    expect(activity, contains('FlutterFragmentActivity'));
    expect(activity, isNot(contains('class MainActivity : FlutterActivity')));
    expect((await installer.initialize(request)).alreadyInstalled, isTrue);
  });

  test('installs Android CameraManager flashlight support', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final request = MiniProgramHostCapabilityInitRequest(
      projectRootPath: hostRootPath,
      capability: 'flashlight',
      platform: 'android',
    );
    final result = await installer.initialize(request);
    expect(result.createdPaths, hasLength(2));
    expect(result.updatedPaths, hasLength(4));

    final manifest = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).readAsString();
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.hardware.camera.flash'));
    expect(manifest, contains('android:required="false"'));

    final native = await File(
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
        'MiniProgramFlashlightChannel.kt',
      ),
    ).readAsString();
    expect(native, contains('CameraManager.TorchCallback'));
    expect(native, contains('setTorchMode'));
    expect(native, contains('turnOffBestEffort'));
    expect(native, isNot(contains('CameraX')));

    final runtimeSetup = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    ).readAsString();
    expect(
      runtimeSetup,
      contains('MiniProgramFlashlightProvider? flashlightProvider'),
    );
    expect(runtimeSetup, contains('CapabilityIds.flashlightControl'));
    expect(runtimeSetup, contains('flashlightProvider: flashlightProvider,'));
    expect((await installer.initialize(request)).alreadyInstalled, isTrue);
  });

  test('installs Android CameraX and ML Kit QR-only support', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final request = MiniProgramHostCapabilityInitRequest(
      projectRootPath: hostRootPath,
      capability: 'qr',
      platform: 'android',
    );
    final result = await installer.initialize(request);
    expect(result.createdPaths, hasLength(3));
    expect(result.updatedPaths, hasLength(5));

    final setup = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    ).readAsString();
    expect(setup, contains('AppAndroidQrScannerProvider'));
    expect(setup, contains('qrScannerProvider: resolvedQrScannerProvider'));

    final runtime = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    ).readAsString();
    expect(runtime, contains('CapabilityIds.qrScanner'));
    expect(runtime, contains('qrScannerProvider: qrScannerProvider'));

    final manifest = await File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).readAsString();
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('MiniProgramQrScannerActivity'));
    expect(manifest, contains('@android:style/Theme.Material.NoActionBar'));

    final nativeRoot = p.join(
      hostRootPath,
      'android',
      'app',
      'src',
      'main',
      'kotlin',
      'com',
      'example',
      'host_app',
    );
    final channel = await File(
      p.join(nativeRoot, 'MiniProgramQrScannerChannel.kt'),
    ).readAsString();
    final scanner = await File(
      p.join(nativeRoot, 'MiniProgramQrScannerActivity.kt'),
    ).readAsString();
    expect(channel, contains('class MiniProgramQrScannerChannel'));
    expect(channel, contains('qr_permission_denied_permanently'));
    expect(channel, contains('MiniProgramQrScannerActivity.cancel'));
    expect(scanner, contains('Barcode.FORMAT_QR_CODE'));
    expect(scanner, contains('ProcessCameraProvider'));
    expect(scanner, contains('enableTorch'));
    expect(scanner, isNot(contains('ACTION_VIEW')));

    final gradle = await File(
      p.join(hostRootPath, 'android', 'app', 'build.gradle.kts'),
    ).readAsString();
    expect(gradle, contains('camera-camera2:1.4.2'));
    expect(gradle, contains('barcode-scanning:17.3.0'));
    expect((await installer.initialize(request)).alreadyInstalled, isTrue);
  });

  test('installs shared Android audio and video playback support', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    final result = await installer.initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'video',
        platform: 'android',
      ),
    );

    expect(result.alreadyInstalled, isFalse);
    final provider = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'app_android_media_playback_provider.dart',
      ),
    ).readAsString();
    expect(provider, contains('class AppAndroidMediaPlaybackProvider'));
    expect(provider, contains('VideoPlayerController.networkUrl'));
    expect(provider, contains('MiniProgramMediaPlaybackStatus.buffering'));

    final pubspec = await File(
      p.join(hostRootPath, 'pubspec.yaml'),
    ).readAsString();
    expect(pubspec, contains('video_player: ^2.10.0'));
    final setup = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_host_setup.dart',
      ),
    ).readAsString();
    expect(setup, contains('resolvedMediaPlaybackProvider'));
    expect(
      setup,
      contains('mediaPlaybackProvider: resolvedMediaPlaybackProvider'),
    );
    final runtime = await File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    ).readAsString();
    expect(runtime, contains('CapabilityIds.mediaAudio'));
    expect(runtime, contains('CapabilityIds.mediaVideo'));
    expect(runtime, contains('mediaPlaybackProvider: mediaPlaybackProvider'));

    final second = await installer.initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'audio',
        platform: 'android',
      ),
    );
    expect(second.alreadyInstalled, isTrue);
  });

  test(
    'installs other Android capabilities after camera upgrades the activity',
    () async {
      const installer = MiniProgramHostCapabilityInstaller();
      for (final capability in <String>[
        'camera',
        'flashlight',
        'location',
        'file',
        'qr',
      ]) {
        final result = await installer.initialize(
          MiniProgramHostCapabilityInitRequest(
            projectRootPath: hostRootPath,
            capability: capability,
            platform: 'android',
          ),
        );
        expect(result.alreadyInstalled, isFalse, reason: capability);
      }

      final activity = await _mainActivityFile(hostRootPath).readAsString();
      expect(
        activity,
        contains('class MainActivity : FlutterFragmentActivity()'),
      );
      expect(
        activity,
        contains('MiniProgramCameraChannel.register(flutterEngine)'),
      );
      expect(
        activity,
        contains('MiniProgramFlashlightChannel.register(flutterEngine)'),
      );
      expect(
        activity,
        contains('MiniProgramLocationChannel.register(flutterEngine)'),
      );
      expect(
        activity,
        contains('MiniProgramFileTransferChannel.register(flutterEngine)'),
      );
      expect(
        activity,
        contains('MiniProgramQrScannerChannel.register(flutterEngine)'),
      );
    },
  );

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
          capability: 'microphone',
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
  mini_program_sdk: ^0.6.6
  mini_program_contracts: ^0.3.11
''');
  await File(
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_runtime_setup.dart'),
  ).writeAsString('''
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

MiniProgramConfig buildMiniProgramConfig({
  Map<String, MiniProgramEndpoint> endpoints =
      const <String, MiniProgramEndpoint>{},
}) {
  final supportedCapabilities = <CapabilityId>{
    CapabilityIds.analytics,
  };
  return MiniProgramConfig(
    sdkVersion: '1.0.0',
    source: EndpointRoutingMiniProgramSource(endpoints: endpoints),
    hostBridge: const _TestHostBridge(),
    capabilityRegistry: CapabilityRegistry(supportedCapabilities),
  );
}
''');
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
  final gradleFile = File(
    p.join(rootPath, 'android', 'app', 'build.gradle.kts'),
  );
  await gradleFile.parent.create(recursive: true);
  await gradleFile.writeAsString('''
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.host_app"
}

dependencies {
}
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
