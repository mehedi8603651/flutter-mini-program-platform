import 'dart:io';

import 'package:path/path.dart' as p;

import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'android_plugin_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String audioCapability = 'audio';
const String videoCapability = 'video';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostMediaPlaybackCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if ((capability != audioCapability && capability != videoCapability) ||
      platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`audio|video --platform android`.',
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
      'Host media playback capability installation requires a Flutter '
      'application: $rootPath',
    );
  }

  final integrationRoot = p.join(rootPath, 'lib', 'mini_program');
  final hostSetup = File(
    p.join(integrationRoot, 'mini_program_host_setup.dart'),
  );
  final runtimeSetup = File(
    p.join(integrationRoot, 'mini_program_runtime_setup.dart'),
  );
  final kotlinRoot = Directory(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await hostSetup.exists() ||
      !await runtimeSetup.exists() ||
      !await kotlinRoot.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Host embedding and Android files must exist before installing media '
      'playback.',
    );
  }

  final gradleCandidates = <File>[
    File(p.join(rootPath, 'android', 'app', 'build.gradle.kts')),
    File(p.join(rootPath, 'android', 'app', 'build.gradle')),
  ];
  final existingGradle = <File>[];
  for (final file in gradleCandidates) {
    if (await file.exists()) existingGradle.add(file);
  }
  if (existingGradle.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected one Android app Gradle file, found ${existingGradle.length}.',
    );
  }
  final gradle = existingGradle.single;
  final activities = await findMediaPlaybackMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readMediaPlaybackKotlinPackage(mainActivity);
  final provider = File(
    p.join(integrationRoot, 'app_android_media_playback_provider.dart'),
  );
  final nativePlugin = File(
    p.join(mainActivity.parent.path, 'MiniProgramMediaPlaybackPlugin.kt'),
  );

  final hostSource = await hostSetup.readAsString();
  final runtimeSource = await runtimeSetup.readAsString();
  final mainSource = await mainActivity.readAsString();
  final gradleSource = await gradle.readAsString();
  final providerSource = await readMediaPlaybackFileIfExists(provider);
  final nativeSource = await readMediaPlaybackFileIfExists(nativePlugin);
  validateMediaPlaybackOwnedFile(
    file: provider,
    source: providerSource,
    requiredMarker: 'class AppAndroidMediaPlaybackProvider',
  );
  validateMediaPlaybackOwnedFile(
    file: nativePlugin,
    source: nativeSource,
    requiredMarker: 'class MiniProgramMediaPlaybackPlugin',
  );
  final installed = isAndroidMediaPlaybackInstalled(
    hostSetupSource: hostSource,
    runtimeSetupSource: runtimeSource,
    mainActivitySource: mainSource,
    gradleSource: gradleSource,
    dartProviderSource: providerSource,
    nativePluginSource: nativeSource,
  );

  final patchedHost = patchMediaPlaybackHostSetup(hostSource);
  final patchedRuntime = patchMediaPlaybackRuntimeSetup(runtimeSource);
  final patchedActivity = patchMediaPlaybackMainActivity(mainSource);
  final patchedGradle = patchMediaPlaybackGradle(
    gradleSource,
    kotlinDsl: p.extension(gradle.path) == '.kts',
  );
  final writes = <String, String>{
    if (providerSource == null ||
        isLegacyGeneratedMediaPlaybackProvider(providerSource))
      provider.path: androidMediaPlaybackProviderSource,
    if (nativeSource == null)
      nativePlugin.path: buildAndroidMediaPlaybackPluginSource(packageName),
    if (patchedHost != hostSource) hostSetup.path: patchedHost,
    if (patchedRuntime != runtimeSource) runtimeSetup.path: patchedRuntime,
    if (patchedActivity != mainSource) mainActivity.path: patchedActivity,
    if (patchedGradle != gradleSource) gradle.path: patchedGradle,
  };
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android media playback is partially configured and could not be '
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
