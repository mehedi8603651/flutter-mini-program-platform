import 'dart:io';

import 'package:path/path.dart' as p;

import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import '../shared_media/android_registry_template.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String cameraCapability = 'camera';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostCameraCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != cameraCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$cameraCapability --platform android`.',
    );
  }
  final rootPath = p.normalize(p.absolute(request.projectRootPath));
  final pubspec = File(p.join(rootPath, 'pubspec.yaml'));
  if (!await pubspec.exists() ||
      !RegExp(
        r'^\s*flutter\s*:\s*$',
        multiLine: true,
      ).hasMatch(await pubspec.readAsString())) {
    throw MiniProgramHostCapabilityException(
      'Host camera capability installation requires a Flutter application: '
      '$rootPath',
    );
  }
  final integrationRoot = p.join(rootPath, 'lib', 'mini_program');
  final hostSetup = File(
    p.join(integrationRoot, 'mini_program_host_setup.dart'),
  );
  final runtimeSetup = File(
    p.join(integrationRoot, 'mini_program_runtime_setup.dart'),
  );
  if (!await hostSetup.exists() || !await runtimeSetup.exists()) {
    throw MiniProgramHostCapabilityException(
      'Mini-program host integration is missing. Run '
      '`miniprogram embed init --project-root "$rootPath"` first.',
    );
  }
  final manifest = File(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  final kotlinRoot = Directory(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await manifest.exists() || !await kotlinRoot.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Android host files are missing. Add Android before installing camera '
      'support.',
    );
  }
  final activities = await findCameraMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readCameraKotlinPackage(mainActivity);
  final nativeChannel = File(
    p.join(mainActivity.parent.path, 'MiniProgramCameraChannel.kt'),
  );
  final mediaRegistry = File(
    p.join(mainActivity.parent.path, 'MiniProgramHostMediaRegistry.kt'),
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_camera_provider.dart'),
  );
  final pathsFile = File(
    p.join(
      rootPath,
      'android',
      'app',
      'src',
      'main',
      'res',
      'xml',
      'mini_program_camera_paths.xml',
    ),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final manifestSource = await manifest.readAsString();
  final mainSource = await mainActivity.readAsString();
  final dartSource = await readCameraFileIfExists(dartProvider);
  final nativeSource = await readCameraFileIfExists(nativeChannel);
  final mediaRegistrySource = await readCameraFileIfExists(mediaRegistry);
  final pathsSource = await readCameraFileIfExists(pathsFile);
  validateCameraOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidCameraProvider',
  );
  validateCameraOwnedFile(
    file: mediaRegistry,
    source: mediaRegistrySource,
    requiredMarker: 'object MiniProgramHostMediaRegistry',
  );
  validateCameraOwnedFile(
    file: nativeChannel,
    source: nativeSource,
    requiredMarker: 'class MiniProgramCameraChannel',
  );
  validateCameraOwnedFile(
    file: pathsFile,
    source: pathsSource,
    requiredMarker: 'mini_program_camera',
  );
  final installed = isAndroidCameraInstalled(
    hostSetupSource: hostSetupSource,
    manifestSource: manifestSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeSource,
    pathsSource: pathsSource,
  );
  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidCameraProviderSource,
    if (nativeSource == null)
      nativeChannel.path: buildAndroidCameraChannelSource(packageName),
    if (mediaRegistrySource == null)
      mediaRegistry.path: buildAndroidHostMediaRegistrySource(packageName),
    if (pathsSource == null) pathsFile.path: androidCameraPathsSource,
  };
  final patchedSetup = patchCameraHostSetup(hostSetupSource);
  final patchedManifest = patchCameraAndroidManifest(manifestSource);
  final patchedActivity = patchCameraMainActivity(mainSource);
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (patchedActivity != mainSource) {
    writes[mainActivity.path] = patchedActivity;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android camera support is partially configured and could not be '
      'updated safely.',
    );
  }
  return writeCapabilityFiles(
    projectRootPath: rootPath,
    capability: capability,
    platform: platform,
    writes: writes,
  );
}
