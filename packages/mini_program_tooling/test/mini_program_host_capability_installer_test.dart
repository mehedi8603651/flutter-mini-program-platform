import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/media_playback/dart_provider_template.dart';
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
    expect(result.createdPaths, hasLength(4));
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
      contains('MiniProgramNativeSetup.register(flutterEngine)'),
    );
    final nativeSetupSource = await _nativeSetupFile(
      hostRootPath,
    ).readAsString();
    expect(
      nativeSetupSource,
      contains('MiniProgramLocationChannel.register(flutterEngine)'),
    );

    final nativeSource = await _nativeGeneratedFile(
      hostRootPath,
      'location',
      'MiniProgramLocationChannel.kt',
    ).readAsString();
    expect(nativeSource, contains('class MiniProgramLocationChannel'));
    expect(nativeSource, contains('LocationManager.NETWORK_PROVIDER'));
    expect(nativeSource, contains('location_permission_denied_permanently'));
    expect(nativeSource, contains('location_timeout'));
    expect(nativeSource, isNot(contains('LocationManager.GPS_PROVIDER')));
    expect(nativeSource, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(nativeSource, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    final ownershipGuide = await File(
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
        'mini_program',
        'README.md',
      ),
    ).readAsString();
    expect(ownershipGuide, contains('generated/'));
    expect(ownershipGuide, contains('Do not place host'));
  });

  test('installs Android streaming file transfer support', () async {
    final result = await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'file',
        platform: 'android',
      ),
    );
    expect(result.createdPaths, hasLength(5));
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
      contains('MiniProgramNativeSetup.register(flutterEngine)'),
    );
    expect(
      await _nativeSetupFile(hostRootPath).readAsString(),
      contains('MiniProgramFileTransferChannel.register(flutterEngine)'),
    );
    final native = await _nativeGeneratedFile(
      hostRootPath,
      'file',
      'MiniProgramFileTransferChannel.kt',
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
    expect(result.createdPaths, hasLength(6));
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
    final native = await _nativeGeneratedFile(
      hostRootPath,
      'camera',
      'MiniProgramCameraChannel.kt',
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
    final registry = await _nativeGeneratedFile(
      hostRootPath,
      'shared',
      'MiniProgramHostMediaRegistry.kt',
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
    expect(result.createdPaths, hasLength(4));
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

    final native = await _nativeGeneratedFile(
      hostRootPath,
      'flashlight',
      'MiniProgramFlashlightChannel.kt',
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
    expect(result.createdPaths, hasLength(6));
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

    final channel = await _nativeGeneratedFile(
      hostRootPath,
      'qr',
      'MiniProgramQrScannerChannel.kt',
    ).readAsString();
    final scanner = await _nativeGeneratedFile(
      hostRootPath,
      'qr',
      'MiniProgramQrScannerActivity.kt',
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
    expect(gradle, contains('mini_program_capabilities.gradle'));
    expect(gradle, isNot(contains('mini_program_capabilities.gradle.kts')));
    final capabilityGradle = await _nativeCapabilityGradleFile(
      hostRootPath,
    ).readAsString();
    expect(capabilityGradle, contains('camera-camera2:1.4.2'));
    expect(capabilityGradle, contains('barcode-scanning:17.3.0'));
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
    expect(provider, contains("'mini_program/media_playback'"));
    expect(provider, contains('AndroidView('));
    expect(provider, contains('MiniProgramFullscreenMediaPlaybackSession'));
    expect(provider, contains('MiniProgramMediaPlaybackSnapshot.fromJson'));
    expect(provider, contains("'value': ?value"));
    expect(provider, isNot(contains("if (value != null) 'value': value")));

    final pubspec = await File(
      p.join(hostRootPath, 'pubspec.yaml'),
    ).readAsString();
    expect(pubspec, isNot(contains('video_player:')));
    final activity = await _mainActivityFile(hostRootPath).readAsString();
    expect(
      activity,
      contains('MiniProgramNativeSetup.register(flutterEngine)'),
    );
    expect(
      await _nativeSetupFile(hostRootPath).readAsString(),
      contains('MiniProgramMediaPlaybackPlugin.register(flutterEngine)'),
    );
    final native = await _nativeGeneratedFile(
      hostRootPath,
      'media_playback',
      'MiniProgramMediaPlaybackPlugin.kt',
    ).readAsString();
    expect(native, contains('class MiniProgramMediaPlaybackPlugin'));
    expect(native, contains('ExoPlayer.Builder'));
    expect(native, contains('SimpleCache'));
    expect(native, contains('setHandleAudioBecomingNoisy(true)'));
    expect(native, contains('enterFullscreen'));
    final gradle = await File(
      p.join(hostRootPath, 'android', 'app', 'build.gradle.kts'),
    ).readAsString();
    expect(gradle, contains('mini_program_capabilities.gradle'));
    expect(gradle, isNot(contains('mini_program_capabilities.gradle.kts')));
    final capabilityGradle = await _nativeCapabilityGradleFile(
      hostRootPath,
    ).readAsString();
    expect(capabilityGradle, contains('media3-exoplayer:1.5.1'));
    expect(capabilityGradle, contains('media3-exoplayer-hls:1.5.1'));
    expect(capabilityGradle, contains('media3-ui:1.5.1'));
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

  test('migrates the generated Kotlin dependency script to Groovy', () async {
    final appGradle = File(
      p.join(hostRootPath, 'android', 'app', 'build.gradle.kts'),
    );
    await appGradle.writeAsString('''
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.host_app"
}

// <mini-program-native-dependencies>
apply(from = "mini_program/mini_program_capabilities.gradle.kts")
// </mini-program-native-dependencies>
''');
    final legacyScript = File(
      p.join(
        hostRootPath,
        'android',
        'app',
        'mini_program',
        'mini_program_capabilities.gradle.kts',
      ),
    );
    await legacyScript.parent.create(recursive: true);
    await legacyScript.writeAsString('''
// Generated by mini_program_tooling. Do not edit.
// capabilities: qr
dependencies {
    add("implementation", "androidx.camera:camera-camera2:1.4.2")
}
''');

    await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'video',
        platform: 'android',
      ),
    );

    final nextAppGradle = await appGradle.readAsString();
    expect(nextAppGradle, contains('mini_program_capabilities.gradle"'));
    expect(nextAppGradle, isNot(contains('.gradle.kts')));
    expect(await legacyScript.exists(), isFalse);
    final generatedScript = await _nativeCapabilityGradleFile(
      hostRootPath,
    ).readAsString();
    expect(generatedScript, contains('// capabilities: media-playback, qr'));
    expect(generatedScript, contains('camera-camera2:1.4.2'));
    expect(generatedScript, contains('media3-exoplayer:1.5.1'));
    expect(generatedScript, isNot(contains('add("implementation"')));
  });

  test('migrates the generated phase one playback provider', () async {
    final provider = File(
      p.join(
        hostRootPath,
        'lib',
        'mini_program',
        'app_android_media_playback_provider.dart',
      ),
    );
    await provider.writeAsString(legacyAndroidMediaPlaybackProviderSource);

    await const MiniProgramHostCapabilityInstaller().initialize(
      MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'video',
        platform: 'android',
      ),
    );

    final migrated = await provider.readAsString();
    expect(migrated, contains("'mini_program/media_playback'"));
    expect(migrated, contains('AndroidView('));
    expect(migrated, isNot(contains('package:video_player/video_player.dart')));
  });

  test(
    'preserves a custom playback provider across repeated installs',
    () async {
      final provider = File(
        p.join(
          hostRootPath,
          'lib',
          'mini_program',
          'app_android_media_playback_provider.dart',
        ),
      );
      const custom = '''
class AppAndroidMediaPlaybackProvider {
  const AppAndroidMediaPlaybackProvider();
  void keepHostBehavior() {}
}
''';
      await provider.writeAsString(custom);
      const installer = MiniProgramHostCapabilityInstaller();
      final request = MiniProgramHostCapabilityInitRequest(
        projectRootPath: hostRootPath,
        capability: 'audio',
        platform: 'android',
      );

      await installer.initialize(request);
      expect(await provider.readAsString(), custom);
      expect((await installer.initialize(request)).alreadyInstalled, isTrue);
      expect(await provider.readAsString(), custom);
    },
  );

  test(
    'reconciles every Android native capability after camera upgrades activity',
    () async {
      const installer = MiniProgramHostCapabilityInstaller();
      for (final capability in <String>[
        'camera',
        'flashlight',
        'location',
        'file',
        'qr',
        'video',
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
        contains('MiniProgramNativeSetup.register(flutterEngine)'),
      );
      expect(
        _occurrences(activity, '// <mini-program-native-capabilities>'),
        1,
      );
      expect(
        _occurrences(activity, '// </mini-program-native-capabilities>'),
        1,
      );
      final nativeSetup = await _nativeSetupFile(hostRootPath).readAsString();
      for (final registration in <String>[
        'MiniProgramCameraChannel.register(flutterEngine)',
        'MiniProgramFlashlightChannel.register(flutterEngine)',
        'MiniProgramLocationChannel.register(flutterEngine)',
        'MiniProgramFileTransferChannel.register(flutterEngine)',
        'MiniProgramQrScannerChannel.register(flutterEngine)',
        'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
      ]) {
        expect(
          _occurrences(nativeSetup, registration),
          1,
          reason: registration,
        );
      }

      final gradle = await File(
        p.join(hostRootPath, 'android', 'app', 'build.gradle.kts'),
      ).readAsString();
      expect(_occurrences(gradle, '// <mini-program-native-dependencies>'), 1);
      final capabilityGradle = await _nativeCapabilityGradleFile(
        hostRootPath,
      ).readAsString();
      expect(_occurrences(capabilityGradle, 'camera-camera2:1.4.2'), 1);
      expect(_occurrences(capabilityGradle, 'media3-exoplayer:1.5.1'), 1);
    },
  );

  test('reconciles every Android native capability with camera last', () async {
    const installer = MiniProgramHostCapabilityInstaller();
    const capabilities = <String>[
      'video',
      'qr',
      'file',
      'location',
      'flashlight',
      'camera',
    ];
    for (final capability in capabilities) {
      final result = await installer.initialize(
        MiniProgramHostCapabilityInitRequest(
          projectRootPath: hostRootPath,
          capability: capability,
          platform: 'android',
        ),
      );
      expect(result.alreadyInstalled, isFalse, reason: capability);
    }
    for (final capability in capabilities.reversed) {
      final result = await installer.initialize(
        MiniProgramHostCapabilityInitRequest(
          projectRootPath: hostRootPath,
          capability: capability,
          platform: 'android',
        ),
      );
      expect(result.alreadyInstalled, isTrue, reason: capability);
    }

    final activity = await _mainActivityFile(hostRootPath).readAsString();
    expect(activity, contains('FlutterFragmentActivity'));
    expect(_occurrences(activity, '// <mini-program-native-capabilities>'), 1);
    expect(_occurrences(activity, 'MiniProgramNativeSetup.register'), 1);
    final nativeSetup = await _nativeSetupFile(hostRootPath).readAsString();
    for (final registration in <String>[
      'MiniProgramLocationChannel.register(flutterEngine)',
      'MiniProgramFileTransferChannel.register(flutterEngine)',
      'MiniProgramCameraChannel.register(flutterEngine)',
      'MiniProgramFlashlightChannel.register(flutterEngine)',
      'MiniProgramQrScannerChannel.register(flutterEngine)',
      'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
    ]) {
      expect(_occurrences(nativeSetup, registration), 1, reason: registration);
    }

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
    expect(_occurrences(manifest, 'android.permission.CAMERA'), 1);
    expect(
      _occurrences(manifest, 'android.permission.ACCESS_COARSE_LOCATION'),
      1,
    );
    expect(_occurrences(manifest, 'MiniProgramQrScannerActivity'), 1);

    final gradle = await File(
      p.join(hostRootPath, 'android', 'app', 'build.gradle.kts'),
    ).readAsString();
    expect(_occurrences(gradle, '// <mini-program-native-dependencies>'), 1);
    final capabilityGradle = await _nativeCapabilityGradleFile(
      hostRootPath,
    ).readAsString();
    expect(_occurrences(capabilityGradle, 'barcode-scanning:17.3.0'), 1);
    expect(_occurrences(capabilityGradle, 'media3-exoplayer-hls:1.5.1'), 1);
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
      contains('MiniProgramNativeSetup.register(flutterEngine)'),
    );
    expect(
      await _nativeSetupFile(hostRootPath).readAsString(),
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
    final nativeFile = _nativeGeneratedFile(
      hostRootPath,
      'location',
      'MiniProgramLocationChannel.kt',
    );
    await nativeFile.delete();
    final mainActivity = _mainActivityFile(hostRootPath);
    await mainActivity.writeAsString('''
package com.example.host_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val channelName = "mini_program/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // <mini-program-native-capabilities>
        MiniProgramNativeSetup.register(flutterEngine)
        // </mini-program-native-capabilities>
    }
}
''');

    final result = await installer.initialize(request);

    expect(result.alreadyInstalled, isFalse);
    expect(await nativeFile.exists(), isFalse);
    expect(await _nativeSetupFile(hostRootPath).exists(), isFalse);
    expect(
      await mainActivity.readAsString(),
      isNot(contains('MiniProgramNativeSetup.register')),
    );
    expect((await installer.initialize(request)).alreadyInstalled, isTrue);
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

File _nativeSetupFile(String rootPath) =>
    _nativeGeneratedFile(rootPath, null, 'MiniProgramNativeSetup.kt');

File _nativeGeneratedFile(String rootPath, String? feature, String fileName) {
  final segments = <String>[
    rootPath,
    'android',
    'app',
    'src',
    'main',
    'kotlin',
    'com',
    'example',
    'host_app',
    'mini_program',
    'generated',
    if (feature != null) feature,
    fileName,
  ];
  return File(p.joinAll(segments));
}

File _nativeCapabilityGradleFile(String rootPath) => File(
  p.join(
    rootPath,
    'android',
    'app',
    'mini_program',
    'mini_program_capabilities.gradle',
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
      'mini_program',
      'generated',
      'location',
      'MiniProgramLocationChannel.kt',
    ),
    _nativeSetupFile(rootPath).path,
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
      'mini_program',
      'README.md',
    ),
  ];
  return <String, String>{
    for (final path in paths) path: await File(path).readAsString(),
  };
}

int _occurrences(String source, String value) {
  var count = 0;
  var offset = 0;
  while (true) {
    final index = source.indexOf(value, offset);
    if (index == -1) return count;
    count += 1;
    offset = index + value.length;
  }
}
