import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/generated_source.dart';
import '../android/gradle_editor.dart';
import '../android/integration_editor.dart';
import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import '../shared_media/android_registry_template.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String galleryCapability = 'gallery';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostGalleryCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != galleryCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$galleryCapability --platform android`.',
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
      'Host gallery installation requires a Flutter application: $rootPath',
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
      'Host embedding and Android files must exist before installing system '
      'photo selection support.',
    );
  }
  final activities = await findGalleryMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readGalleryKotlinPackage(mainActivity);
  final mainSource = await mainActivity.readAsString();
  final nativeIntegration = await buildAndroidNativeIntegrationEdit(
    mainActivityFile: mainActivity,
    packageName: packageName,
    mainActivitySource: mainSource,
    registration: 'MiniProgramGalleryChannel.register(flutterEngine)',
    requiresFragmentActivity: true,
  );
  final nativeChannel = nativeIntegration.paths.generatedFile(
    'gallery',
    'MiniProgramGalleryChannel.kt',
  );
  final mediaRegistry = nativeIntegration.paths.generatedFile(
    'shared',
    'MiniProgramHostMediaRegistry.kt',
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_gallery_provider.dart'),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final manifest = File(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  if (!await manifest.exists()) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml is required for photo selection.',
    );
  }
  final manifestSource = await manifest.readAsString();
  final pathsFile = File(
    p.join(
      manifest.parent.path,
      'res',
      'xml',
      'mini_program_gallery_paths.xml',
    ),
  );
  final pathsSource = await readGalleryFileIfExists(pathsFile);
  validateGalleryOwnedFile(
    file: pathsFile,
    source: pathsSource,
    requiredMarker: 'mini_program_gallery',
  );
  final appRoot = Directory(p.join(rootPath, 'android', 'app'));
  final gradleFiles = [
    File(p.join(appRoot.path, 'build.gradle.kts')),
    File(p.join(appRoot.path, 'build.gradle')),
  ];
  final existingGradle = <File>[];
  for (final file in gradleFiles) {
    if (await file.exists()) existingGradle.add(file);
  }
  if (existingGradle.length != 1) {
    throw const MiniProgramHostCapabilityException(
      'Expected exactly one Android app Gradle file.',
    );
  }
  final gradle = existingGradle.single;
  final gradleSource = await gradle.readAsString();
  final generatedGradle = File(
    p.join(appRoot.path, 'mini_program', 'mini_program_capabilities.gradle'),
  );
  final legacyGradle = File(
    p.join(
      appRoot.path,
      'mini_program',
      'mini_program_capabilities.gradle.kts',
    ),
  );
  final generatedGradleSource = await readGalleryFileIfExists(generatedGradle);
  final legacyGradleSource = await readGalleryFileIfExists(legacyGradle);
  for (final source in [generatedGradleSource, legacyGradleSource]) {
    if (source != null &&
        !source.contains(androidCapabilityGradleGeneratedMarker)) {
      throw const MiniProgramHostCapabilityException(
        'Refusing to overwrite a host-owned Android dependency script.',
      );
    }
  }
  final previousGradleSources = [
    if (generatedGradleSource != null) generatedGradleSource,
    if (legacyGradleSource != null) legacyGradleSource,
  ];
  final gradleEdit = buildAndroidCapabilityGradleEdit(
    gradleSource,
    generatedSource: previousGradleSources.isEmpty
        ? null
        : previousGradleSources.join('\n'),
    capability: androidGalleryDependencyCapability,
    kotlinDsl: p.extension(gradle.path) == '.kts',
  );
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final dartSource = await readGalleryFileIfExists(dartProvider);
  final nativeMigration = await resolveAndroidGeneratedSource(
    generatedFile: nativeChannel,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramGalleryChannel.kt',
    ),
    requiredMarker: 'class MiniProgramGalleryChannel',
    buildSource: () => buildAndroidGalleryChannelSource(packageName),
  );
  final registryMigration = await resolveAndroidGeneratedSource(
    generatedFile: mediaRegistry,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramHostMediaRegistry.kt',
    ),
    requiredMarker: 'object MiniProgramHostMediaRegistry',
    buildSource: () => buildAndroidHostMediaRegistrySource(packageName),
  );
  validateGalleryOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidGalleryProvider',
  );
  validateGalleryOwnedFile(
    file: nativeChannel,
    source: nativeMigration.source,
    requiredMarker: 'class MiniProgramGalleryChannel',
  );
  validateGalleryOwnedFile(
    file: mediaRegistry,
    source: registryMigration.source,
    requiredMarker: 'object MiniProgramHostMediaRegistry',
  );
  final installed = isAndroidGalleryInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeMigration.source,
    mediaRegistrySource: registryMigration.source,
  );
  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidGalleryProviderSource,
    ...nativeMigration.writes,
    ...registryMigration.writes,
    ...nativeIntegration.writes,
    if (pathsSource == null) pathsFile.path: androidGalleryPathsSource,
    if (gradleEdit.appGradleSource != gradleSource)
      gradle.path: gradleEdit.appGradleSource,
    if (gradleEdit.generatedGradleSource != generatedGradleSource)
      generatedGradle.path: gradleEdit.generatedGradleSource,
  };
  final deletes = <String>{
    ...nativeMigration.deletes,
    ...registryMigration.deletes,
    if (legacyGradleSource != null) legacyGradle.path,
  };
  final patchedSetup = patchGalleryHostSetup(hostSetupSource);
  final patchedRuntimeSetup = patchGalleryRuntimeSetup(runtimeSetupSource);
  final patchedManifest = patchGalleryAndroidManifest(manifestSource);
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntimeSetup != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntimeSetup;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android photo selection is partially configured and could not be '
      'updated safely.',
    );
  }
  return writeCapabilityFiles(
    projectRootPath: rootPath,
    capability: capability,
    platform: platform,
    writes: writes,
    deletes: deletes,
  );
}
