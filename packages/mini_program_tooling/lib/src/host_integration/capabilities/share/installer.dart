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

const String shareCapability = 'share';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostShareCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != shareCapability || platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$shareCapability --platform android`.',
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
      'Host share installation requires a Flutter application: $rootPath',
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
      'sharing support.',
    );
  }
  final activities = await findShareMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readShareKotlinPackage(mainActivity);
  final mainSource = await mainActivity.readAsString();
  final nativeIntegration = await buildAndroidNativeIntegrationEdit(
    mainActivityFile: mainActivity,
    packageName: packageName,
    mainActivitySource: mainSource,
    registration: 'MiniProgramShareChannel.register(flutterEngine)',
  );
  final nativeChannel = nativeIntegration.paths.generatedFile(
    'share',
    'MiniProgramShareChannel.kt',
  );
  final mediaRegistry = nativeIntegration.paths.generatedFile(
    'shared',
    'MiniProgramHostMediaRegistry.kt',
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_share_provider.dart'),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final dartSource = await readShareFileIfExists(dartProvider);
  final nativeMigration = await resolveAndroidGeneratedSource(
    generatedFile: nativeChannel,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramShareChannel.kt',
    ),
    requiredMarker: 'class MiniProgramShareChannel',
    buildSource: () => buildAndroidShareChannelSource(packageName),
  );
  final registryMigration = await resolveAndroidGeneratedSource(
    generatedFile: mediaRegistry,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramHostMediaRegistry.kt',
    ),
    requiredMarker: 'object MiniProgramHostMediaRegistry',
    buildSource: () => buildAndroidHostMediaRegistrySource(packageName),
  );
  validateShareOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidShareProvider',
  );
  validateShareOwnedFile(
    file: nativeChannel,
    source: nativeMigration.source,
    requiredMarker: 'class MiniProgramShareChannel',
  );
  validateShareOwnedFile(
    file: mediaRegistry,
    source: registryMigration.source,
    requiredMarker: 'object MiniProgramHostMediaRegistry',
  );
  final installed = isAndroidShareInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeMigration.source,
    mediaRegistrySource: registryMigration.source,
  );
  final writes = <String, String>{
    if (dartSource == null) dartProvider.path: androidShareProviderSource,
    ...nativeMigration.writes,
    ...registryMigration.writes,
    ...nativeIntegration.writes,
  };
  final deletes = <String>{
    ...nativeMigration.deletes,
    ...registryMigration.deletes,
  };
  final patchedSetup = patchShareHostSetup(hostSetupSource);
  final patchedRuntimeSetup = patchShareRuntimeSetup(runtimeSetupSource);
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntimeSetup != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntimeSetup;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android system sharing is partially configured and could not be '
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
