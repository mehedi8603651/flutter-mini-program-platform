import 'dart:io';

import 'package:path/path.dart' as p;

import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String fileCapability = 'file';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostFileCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != fileCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$fileCapability --platform android`.',
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
  if (!await pubspecFile.exists() ||
      !RegExp(
        r'^\s*flutter\s*:\s*$',
        multiLine: true,
      ).hasMatch(await pubspecFile.readAsString())) {
    throw MiniProgramHostCapabilityException(
      'Host file capability installation requires a Flutter application: '
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
  final kotlinRoot = Directory(
    p.join(projectRootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await kotlinRoot.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Android host files are missing. Add Android before installing file '
      'transfer support.',
    );
  }
  final mainActivityFiles = await findFileCapabilityMainActivities(kotlinRoot);
  if (mainActivityFiles.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${mainActivityFiles.length}.',
    );
  }
  final mainActivityFile = mainActivityFiles.single;
  final packageName = await readFileKotlinPackage(mainActivityFile);
  final nativeChannelFile = File(
    p.join(mainActivityFile.parent.path, 'MiniProgramFileTransferChannel.kt'),
  );
  final dartProviderFile = File(
    p.join(integrationRootPath, 'app_android_file_transfer_provider.dart'),
  );
  final hostSetupSource = await hostSetupFile.readAsString();
  final mainActivitySource = await mainActivityFile.readAsString();
  final dartProviderSource = await readFileCapabilityFileIfExists(
    dartProviderFile,
  );
  final nativeChannelSource = await readFileCapabilityFileIfExists(
    nativeChannelFile,
  );
  validateFileCapabilityOwnedFile(
    file: dartProviderFile,
    source: dartProviderSource,
    requiredMarker: 'class AppAndroidFileTransferProvider',
  );
  validateFileCapabilityOwnedFile(
    file: nativeChannelFile,
    source: nativeChannelSource,
    requiredMarker: 'class MiniProgramFileTransferChannel',
  );
  if (isAndroidFileCapabilityInstalled(
    hostSetupSource: hostSetupSource,
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
    writes[dartProviderFile.path] = androidFileTransferProviderSource;
  }
  if (nativeChannelSource == null) {
    writes[nativeChannelFile.path] = buildAndroidFileTransferChannelSource(
      packageName,
    );
  }
  final patchedHostSetup = patchFileTransferHostSetup(hostSetupSource);
  if (patchedHostSetup != hostSetupSource) {
    writes[hostSetupFile.path] = patchedHostSetup;
  }
  final patchedMainActivity = patchFileTransferMainActivity(mainActivitySource);
  if (patchedMainActivity != mainActivitySource) {
    writes[mainActivityFile.path] = patchedMainActivity;
  }
  if (writes.isEmpty) {
    throw const MiniProgramHostCapabilityException(
      'Android file transfer support is only partially configured and could '
      'not be updated safely.',
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
