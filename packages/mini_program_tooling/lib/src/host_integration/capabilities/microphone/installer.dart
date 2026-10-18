import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/generated_source.dart';
import '../android/integration_editor.dart';
import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import '../shared_media/android_registry_template.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String microphoneCapability = 'microphone';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostMicrophoneCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != microphoneCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$microphoneCapability --platform android`.',
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
      'Host microphone installation requires a Flutter application: $rootPath',
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
      'voice recording support.',
    );
  }
  final activities = await findMicrophoneMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readMicrophoneKotlinPackage(mainActivity);
  final mainSource = await mainActivity.readAsString();
  final nativeIntegration = await buildAndroidNativeIntegrationEdit(
    mainActivityFile: mainActivity,
    packageName: packageName,
    mainActivitySource: mainSource,
    registration: 'MiniProgramMicrophoneChannel.register(flutterEngine)',
  );
  final nativeChannel = nativeIntegration.paths.generatedFile(
    'microphone',
    'MiniProgramMicrophoneChannel.kt',
  );
  final mediaRegistry = nativeIntegration.paths.generatedFile(
    'shared',
    'MiniProgramHostMediaRegistry.kt',
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_microphone_provider.dart'),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final manifest = File(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  if (!await manifest.exists()) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml is required for voice recording.',
    );
  }
  final manifestSource = await manifest.readAsString();
  final pathsFile = File(
    p.join(
      manifest.parent.path,
      'res',
      'xml',
      'mini_program_microphone_paths.xml',
    ),
  );
  final pathsSource = await readMicrophoneFileIfExists(pathsFile);
  validateMicrophoneOwnedFile(
    file: pathsFile,
    source: pathsSource,
    requiredMarker: 'mini_program_microphone',
  );
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final dartSource = await readMicrophoneFileIfExists(dartProvider);
  final nativeMigration = await resolveAndroidGeneratedSource(
    generatedFile: nativeChannel,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramMicrophoneChannel.kt',
    ),
    requiredMarker: 'class MiniProgramMicrophoneChannel',
    toolingGeneratedMarker: 'Tooling-generated foreground recorder',
    buildSource: () => buildAndroidMicrophoneChannelSource(packageName),
  );
  final registryMigration = await resolveAndroidGeneratedSource(
    generatedFile: mediaRegistry,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramHostMediaRegistry.kt',
    ),
    requiredMarker: 'object MiniProgramHostMediaRegistry',
    buildSource: () => buildAndroidHostMediaRegistrySource(packageName),
  );
  validateMicrophoneOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidMicrophoneProvider',
  );
  validateMicrophoneOwnedFile(
    file: nativeChannel,
    source: nativeMigration.source,
    requiredMarker: 'class MiniProgramMicrophoneChannel',
  );
  validateMicrophoneOwnedFile(
    file: mediaRegistry,
    source: registryMigration.source,
    requiredMarker: 'object MiniProgramHostMediaRegistry',
  );
  final installed = isAndroidMicrophoneInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeMigration.source,
    mediaRegistrySource: registryMigration.source,
  );
  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidMicrophoneProviderSource,
    ...nativeMigration.writes,
    ...registryMigration.writes,
    ...nativeIntegration.writes,
    if (pathsSource == null) pathsFile.path: androidMicrophonePathsSource,
  };
  final deletes = <String>{
    ...nativeMigration.deletes,
    ...registryMigration.deletes,
  };
  final patchedSetup = patchMicrophoneHostSetup(hostSetupSource);
  final patchedRuntimeSetup = patchMicrophoneRuntimeSetup(runtimeSetupSource);
  final patchedManifest = patchMicrophoneAndroidManifest(
    manifestSource,
    packageName: packageName,
  );
  if (patchedManifest != manifestSource) {
    writes[manifest.path] = patchedManifest;
  }
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntimeSetup != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntimeSetup;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android microphone recording is partially configured and could not be '
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
