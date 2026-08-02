import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/generated_source.dart';
import '../android/gradle_editor.dart';
import '../android/integration_editor.dart';
import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String qrCapability = 'qr';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostQrCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != qrCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$qrCapability --platform android`.',
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
      'Host QR capability installation requires a Flutter application: '
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
      'Host embedding and Android files must exist before installing QR '
      'scanner support.',
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
  final activities = await findQrMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readQrKotlinPackage(mainActivity);
  final mainSource = await mainActivity.readAsString();
  final nativeIntegration = await buildAndroidNativeIntegrationEdit(
    mainActivityFile: mainActivity,
    packageName: packageName,
    mainActivitySource: mainSource,
    registration: 'MiniProgramQrScannerChannel.register(flutterEngine)',
  );
  final nativeChannel = nativeIntegration.paths.generatedFile(
    'qr',
    'MiniProgramQrScannerChannel.kt',
  );
  final scannerActivity = nativeIntegration.paths.generatedFile(
    'qr',
    'MiniProgramQrScannerActivity.kt',
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_qr_scanner_provider.dart'),
  );

  final hostSetupSource = await hostSetup.readAsString();
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final manifestSource = await manifest.readAsString();
  final gradleSource = await gradle.readAsString();
  final kotlinDsl = p.extension(gradle.path) == '.kts';
  final generatedGradle = File(
    p.join(
      gradle.parent.path,
      'mini_program',
      'mini_program_capabilities.gradle',
    ),
  );
  final legacyGeneratedGradle = File(
    p.join(
      gradle.parent.path,
      'mini_program',
      'mini_program_capabilities.gradle.kts',
    ),
  );
  final currentGeneratedGradleSource = await readQrFileIfExists(
    generatedGradle,
  );
  final legacyGeneratedGradleSource = await readQrFileIfExists(
    legacyGeneratedGradle,
  );
  for (final source in <String?>[
    currentGeneratedGradleSource,
    legacyGeneratedGradleSource,
  ]) {
    if (source != null &&
        !source.contains(androidCapabilityGradleGeneratedMarker)) {
      throw const MiniProgramHostCapabilityException(
        'Refusing to migrate the Android mini-program dependency script '
        'because it is not a recognized tooling-generated file.',
      );
    }
  }
  final generatedGradleSource = <String>[
    if (currentGeneratedGradleSource != null) currentGeneratedGradleSource,
    if (legacyGeneratedGradleSource != null) legacyGeneratedGradleSource,
  ].join('\n');
  final dartSource = await readQrFileIfExists(dartProvider);
  final nativeMigration = await resolveAndroidGeneratedSource(
    generatedFile: nativeChannel,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramQrScannerChannel.kt',
    ),
    requiredMarker: 'class MiniProgramQrScannerChannel',
    buildSource: () => buildAndroidQrScannerChannelSource(packageName),
  );
  final scannerMigration = await resolveAndroidGeneratedSource(
    generatedFile: scannerActivity,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramQrScannerActivity.kt',
    ),
    requiredMarker: 'class MiniProgramQrScannerActivity',
    buildSource: () => buildAndroidQrScannerActivitySource(packageName),
  );
  final nativeSource = nativeMigration.source;
  final scannerSource = scannerMigration.source;
  validateQrOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidQrScannerProvider',
  );
  validateQrOwnedFile(
    file: nativeChannel,
    source: nativeSource,
    requiredMarker: 'class MiniProgramQrScannerChannel',
  );
  validateQrOwnedFile(
    file: scannerActivity,
    source: scannerSource,
    requiredMarker: 'class MiniProgramQrScannerActivity',
  );
  final installed = isAndroidQrInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    manifestSource: manifestSource,
    mainActivitySource: mainSource,
    gradleSource: generatedGradleSource.isEmpty
        ? gradleSource
        : generatedGradleSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeSource,
    scannerActivitySource: scannerSource,
  );

  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidQrScannerProviderSource,
    ...nativeMigration.writes,
    ...scannerMigration.writes,
    ...nativeIntegration.writes,
  };
  final deletes = <String>{
    ...nativeMigration.deletes,
    ...scannerMigration.deletes,
  };
  final patchedSetup = patchQrHostSetup(hostSetupSource);
  final patchedRuntime = patchQrRuntimeSetup(runtimeSetupSource);
  final patchedManifest = patchQrAndroidManifest(manifestSource, packageName);
  final gradleEdit = buildAndroidCapabilityGradleEdit(
    gradleSource,
    generatedSource: generatedGradleSource.isEmpty
        ? null
        : generatedGradleSource,
    capability: androidQrDependencyCapability,
    kotlinDsl: kotlinDsl,
  );
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntime != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntime;
  }
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (gradleEdit.appGradleSource != gradleSource) {
    writes[gradle.path] = gradleEdit.appGradleSource;
  }
  if (gradleEdit.generatedGradleSource != currentGeneratedGradleSource ||
      legacyGeneratedGradleSource != null) {
    writes[generatedGradle.path] = gradleEdit.generatedGradleSource;
  }
  if (legacyGeneratedGradleSource != null) {
    deletes.add(legacyGeneratedGradle.path);
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android QR scanner support is partially configured and could not be '
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
