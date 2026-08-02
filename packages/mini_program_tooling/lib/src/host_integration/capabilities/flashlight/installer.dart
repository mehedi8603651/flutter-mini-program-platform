import 'dart:io';

import 'package:path/path.dart' as p;

import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String flashlightCapability = 'flashlight';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostFlashlightCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != flashlightCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$flashlightCapability --platform android`.',
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
      'Host flashlight installation requires a Flutter application: '
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
  final manifest = File(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  final kotlinRoot = Directory(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await hostSetup.exists() ||
      !await runtimeSetup.exists() ||
      !await manifest.exists() ||
      !await kotlinRoot.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Host embedding and Android files must exist before installing '
      'flashlight support.',
    );
  }
  final activities = await findFlashlightMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readFlashlightKotlinPackage(mainActivity);
  final nativeChannel = File(
    p.join(mainActivity.parent.path, 'MiniProgramFlashlightChannel.kt'),
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_flashlight_provider.dart'),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final manifestSource = await manifest.readAsString();
  final mainSource = await mainActivity.readAsString();
  final dartSource = await readFlashlightFileIfExists(dartProvider);
  final nativeSource = await readFlashlightFileIfExists(nativeChannel);
  validateFlashlightOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidFlashlightProvider',
  );
  validateFlashlightOwnedFile(
    file: nativeChannel,
    source: nativeSource,
    requiredMarker: 'class MiniProgramFlashlightChannel',
  );
  final installed = isAndroidFlashlightInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    manifestSource: manifestSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeSource,
  );
  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidFlashlightProviderSource,
    if (nativeSource == null)
      nativeChannel.path: buildAndroidFlashlightChannelSource(packageName),
  };
  final patchedSetup = patchFlashlightHostSetup(hostSetupSource);
  final patchedRuntimeSetup = patchFlashlightRuntimeSetup(runtimeSetupSource);
  final patchedManifest = patchFlashlightAndroidManifest(manifestSource);
  final patchedActivity = patchFlashlightMainActivity(mainSource);
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntimeSetup != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntimeSetup;
  }
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (patchedActivity != mainSource) {
    writes[mainActivity.path] = patchedActivity;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android flashlight support is partially configured and could not be '
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
