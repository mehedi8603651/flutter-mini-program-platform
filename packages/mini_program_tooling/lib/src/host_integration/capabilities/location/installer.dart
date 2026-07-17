import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String locationCapability = 'location';
const String androidPlatform = 'android';

Future<MiniProgramHostCapabilityInitResult> initializeMiniProgramHostCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != locationCapability) {
    throw MiniProgramHostCapabilityException(
      'Unsupported host capability "$capability". Supported capabilities: '
      '$locationCapability.',
    );
  }
  if (platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '--platform android.',
    );
  }

  final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
  final projectRoot = Directory(projectRootPath);
  if (!await projectRoot.exists()) {
    throw MiniProgramHostCapabilityException(
      'Flutter host project does not exist: $projectRootPath',
    );
  }

  final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
  if (!await pubspecFile.exists()) {
    throw MiniProgramHostCapabilityException(
      'Flutter host is missing pubspec.yaml: $projectRootPath',
    );
  }
  final pubspecSource = await pubspecFile.readAsString();
  if (!RegExp(
    r'^\s*flutter\s*:\s*$',
    multiLine: true,
  ).hasMatch(pubspecSource)) {
    throw MiniProgramHostCapabilityException(
      'Host capability installation requires a Flutter application: '
      '$projectRootPath',
    );
  }

  final integrationRootPath = p.join(projectRootPath, 'lib', 'mini_program');
  final hostSetupFile = File(
    p.join(integrationRootPath, 'mini_program_host_setup.dart'),
  );
  final runtimeSetupFile = File(
    p.join(integrationRootPath, 'mini_program_runtime_setup.dart'),
  );
  if (!await hostSetupFile.exists() || !await runtimeSetupFile.exists()) {
    throw MiniProgramHostCapabilityException(
      'Mini-program host integration is missing. Run '
      '`miniprogram embed init --project-root "$projectRootPath"` first.',
    );
  }

  final manifestFile = File(
    p.join(
      projectRootPath,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  final kotlinRoot = Directory(
    p.join(projectRootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await manifestFile.exists() || !await kotlinRoot.exists()) {
    throw MiniProgramHostCapabilityException(
      'Android host files are missing. Add the Android platform to the '
      'Flutter host before installing location support.',
    );
  }

  final mainActivityFiles = await kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
  if (mainActivityFiles.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under '
      '${kotlinRoot.path}, found ${mainActivityFiles.length}.',
    );
  }

  final mainActivityFile = mainActivityFiles.single;
  final packageName = await readLocationKotlinPackage(mainActivityFile);
  final nativeChannelFile = File(
    p.join(mainActivityFile.parent.path, 'MiniProgramLocationChannel.kt'),
  );
  final dartProviderFile = File(
    p.join(integrationRootPath, 'app_android_location_provider.dart'),
  );

  final hostSetupSource = await hostSetupFile.readAsString();
  final manifestSource = await manifestFile.readAsString();
  final mainActivitySource = await mainActivityFile.readAsString();
  final dartProviderSource = await readLocationFileIfExists(dartProviderFile);
  final nativeChannelSource = await readLocationFileIfExists(nativeChannelFile);

  validateLocationOwnedFile(
    file: dartProviderFile,
    source: dartProviderSource,
    requiredMarker: 'class AppAndroidLocationProvider',
  );
  validateLocationOwnedFile(
    file: nativeChannelFile,
    source: nativeChannelSource,
    requiredMarker: 'class MiniProgramLocationChannel',
  );

  if (isAndroidLocationInstalled(
    hostSetupSource: hostSetupSource,
    manifestSource: manifestSource,
    mainActivitySource: mainActivitySource,
    dartProviderSource: dartProviderSource,
    nativeChannelSource: nativeChannelSource,
  )) {
    return MiniProgramHostCapabilityInitResult(
      projectRootPath: projectRootPath,
      capability: capability,
      platform: platform,
      createdPaths: const <String>[],
      updatedPaths: const <String>[],
    );
  }

  final writes = <String, String>{};
  if (dartProviderSource == null) {
    writes[dartProviderFile.path] = androidLocationProviderSource;
  }

  final patchedHostSetup = patchLocationHostSetup(hostSetupSource);
  if (patchedHostSetup != hostSetupSource) {
    writes[hostSetupFile.path] = patchedHostSetup;
  }

  final patchedManifest = patchLocationAndroidManifest(manifestSource);
  if (patchedManifest != manifestSource) {
    writes[manifestFile.path] = patchedManifest;
  }

  final hasDirectNativeChannel = mainActivitySource.contains(
    'mini_program/location',
  );
  if (!hasDirectNativeChannel) {
    if (nativeChannelSource == null) {
      writes[nativeChannelFile.path] = buildAndroidLocationChannelSource(
        packageName,
      );
    }
    final patchedMainActivity = patchLocationMainActivity(mainActivitySource);
    if (patchedMainActivity != mainActivitySource) {
      writes[mainActivityFile.path] = patchedMainActivity;
    }
  }

  if (writes.isEmpty) {
    throw const MiniProgramHostCapabilityException(
      'Android location capability is only partially configured, and the '
      'installer could not determine a safe update. Review the host setup, '
      'manifest, provider adapter, and MainActivity integration.',
    );
  }

  final createdPaths = <String>[];
  final updatedPaths = <String>[];
  for (final entry in writes.entries) {
    final file = File(entry.key);
    final existed = await file.exists();
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    (existed ? updatedPaths : createdPaths).add(file.path);
  }
  createdPaths.sort();
  updatedPaths.sort();

  return MiniProgramHostCapabilityInitResult(
    projectRootPath: projectRootPath,
    capability: capability,
    platform: platform,
    createdPaths: List<String>.unmodifiable(createdPaths),
    updatedPaths: List<String>.unmodifiable(updatedPaths),
  );
}
