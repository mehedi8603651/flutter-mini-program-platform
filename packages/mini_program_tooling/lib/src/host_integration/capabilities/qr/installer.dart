import 'dart:io';

import 'package:path/path.dart' as p;

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
  final nativeChannel = File(
    p.join(mainActivity.parent.path, 'MiniProgramQrScannerChannel.kt'),
  );
  final scannerActivity = File(
    p.join(mainActivity.parent.path, 'MiniProgramQrScannerActivity.kt'),
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_qr_scanner_provider.dart'),
  );

  final hostSetupSource = await hostSetup.readAsString();
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final manifestSource = await manifest.readAsString();
  final mainSource = await mainActivity.readAsString();
  final gradleSource = await gradle.readAsString();
  final dartSource = await readQrFileIfExists(dartProvider);
  final nativeSource = await readQrFileIfExists(nativeChannel);
  final scannerSource = await readQrFileIfExists(scannerActivity);
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
  if (isAndroidQrInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    manifestSource: manifestSource,
    mainActivitySource: mainSource,
    gradleSource: gradleSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeSource,
    scannerActivitySource: scannerSource,
  )) {
    return MiniProgramHostCapabilityInitResult(
      projectRootPath: rootPath,
      capability: capability,
      platform: platform,
      createdPaths: const <String>[],
      updatedPaths: const <String>[],
    );
  }

  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidQrScannerProviderSource,
    if (nativeSource == null)
      nativeChannel.path: buildAndroidQrScannerChannelSource(packageName),
    if (scannerSource == null)
      scannerActivity.path: buildAndroidQrScannerActivitySource(packageName),
  };
  final patchedSetup = patchQrHostSetup(hostSetupSource);
  final patchedRuntime = patchQrRuntimeSetup(runtimeSetupSource);
  final patchedManifest = patchQrAndroidManifest(manifestSource, packageName);
  final patchedActivity = patchQrMainActivity(mainSource);
  final patchedGradle = patchQrGradle(
    gradleSource,
    kotlinDsl: p.extension(gradle.path) == '.kts',
  );
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntime != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntime;
  }
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (patchedActivity != mainSource) {
    writes[mainActivity.path] = patchedActivity;
  }
  if (patchedGradle != gradleSource) writes[gradle.path] = patchedGradle;
  if (writes.isEmpty) {
    throw const MiniProgramHostCapabilityException(
      'Android QR scanner support is partially configured and could not be '
      'updated safely.',
    );
  }
  final created = <String>[];
  final updated = <String>[];
  for (final entry in writes.entries) {
    final file = File(entry.key);
    final existed = await file.exists();
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    (existed ? updated : created).add(file.path);
  }
  created.sort();
  updated.sort();
  return MiniProgramHostCapabilityInitResult(
    projectRootPath: rootPath,
    capability: capability,
    platform: platform,
    createdPaths: List<String>.unmodifiable(created),
    updatedPaths: List<String>.unmodifiable(updated),
  );
}
